/* DHTTPClient.d v0.3.0 (06.01.2011) by Bystroushaak (bystrousak@kitakitsune.org)
 * 
 * TODO:
 *  Hledat Location v hlavičkách.
 *      Udělat fci která ignoruje location?
 *  Číst data jako byte a v případě příznivých hlaviček je teprve konvertovat na string.
 * 
 *  Přidělat fce:
 *      + nějaký sety, který jen přidaj další hlavičku
 *      + reakce na 301
 *      + unittest ParsedUrl
*/

import std.uri;
import std.conv;
import std.string;
import std.socket;
import std.socketstream;

class HTTPClientException:Exception{
    this(string msg){
        super(msg);
    }
}
class URLException:HTTPClientException{
    this(string msg){
        super(msg);
    }
}
class InvalidStateException:HTTPClientException{
    this(string msg){
        super(msg);
    }
}

private class ParsedURL {
    private string protocol, domain, path;
    private ushort port = 0;

    this(string URL){
        string[] t;
        
        // Parse protocol
        if (URL.indexOf("://") >= 0){
            t = split(URL, "://");
            
            this.protocol = t[0].tolower();
            URL = t[1];
        }else{
            throw new URLException("Can't find protocol!");
        }
        
        // Parse domain
        if (URL.indexOf("/") >= 0){
            t = split(URL, "/");
            
            this.domain = t[0];
            this.path   = "/" ~ join(t[1 .. $], "/");
        }else{
            this.domain = URL;
            this.path   = "/";
        }
        
        // Parse port
        if (this.domain.indexOf(":") >= 0){
            t = split(this.domain, ":");
            
            this.domain = t[0];
            this.port   = to!(ushort)(t[1]);
        }else{
            // Default ports
            switch(this.protocol){
                case "ftp":
                    this.port = 21;
                    break;
                case "http":
                    this.port = 80;
                    break;
                case "https":
                    this.port = 443;
                    break;
                case "ssh":
                    this.port = 22;
                    break;
                default:
                    throw new URLException("Unknown default port!");
                    break;
            }
        }
    }
    
    public string getProtocol(){
        return this.protocol;
    }
    public string getDomain(){
        return this.domain;
    }
    public string getPath(){
        return this.path;
    }
    public ushort getPort(){
        return this.port;
    }
    
    public string toString(){
        string sum = "Protocol:\t" ~ this.protocol;
        sum ~= "\nDomain\t\t" ~ this.domain;
        if (port != 0)
            sum ~= "\nPort:\t\t" ~ to!(string)(this.port);
        else
            sum ~= "\nPort:\t\t" ~ to!(string)(this.port) ~ " (unknown)";
        sum ~= "\nPath:\t\t" ~ this.path;
        
        return sum;
    }
}

public class HTTPClient{
    private const string CLRF = "\r\n";
    private const string HTTP_VERSION = "HTTP/1.1";
    private string[string] serverHeaders;
    private string[string] clientHeaders;
    private bool initiated = false;
    private bool ignore_location = false;
    
    private SocketStream initConnection(ref ParsedURL pu){
        if (pu.getProtocol() != "http"){
            throw new URLException("Bad protocol!");
        }
        
        setDefaultHeaders();
        
        TcpSocket tsock = new TcpSocket(new InternetAddress(pu.getDomain(), pu.getPort()));

        return new SocketStream(tsock);
    }
    
    private void setDefaultHeaders(){
        this.clientHeaders["User-Agent"] = "Mozilla/5.0 (X11; U; Linux i686; cs; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3";
        this.clientHeaders["Accept"] = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain";
        this.clientHeaders["Accept-Language"] = "cs,en-us;q=0.7,en;q=0.3";
        this.clientHeaders["Accept-Charset"]  = "utf-8";
        this.clientHeaders["Keep-Alive"] = "300";
        this.clientHeaders["Connection"] =  "keep-alive";
    }
    
    private void sendHeaders(ref SocketStream ss){
        // Send headers
        foreach(string key, val; this.clientHeaders){
            ss.writeString(key ~ ": " ~ val ~ CLRF);
        }
    }
    
    private string urlEncodeHeaders(string[string] headers){
        string ostr = "";
        
        foreach(string key, val; headers){
            ostr ~= std.uri.encode(key) ~ "=" ~ std.uri.encode(val) ~ "&";
        }
        
        return ostr;
    }
    
    private string[string] readHeaders(ref SocketStream ss){
        string s = " ";
        string[string] headers;
        uint ioc = 0;
        
        // Read status line
        s = cast(string) ss.readLine();
        ioc = s.indexOf(HTTP_VERSION);
        if (ioc >= 0){
            headers["StatusCode"] = s.replace(HTTP_VERSION, "").strip();
        }else{
            headers["StatusCode"] = s;
        }
        
        // Read headers
        s = " ";
        while (s.length){
            s = cast(string) ss.readLine();
            
            if (!s.length)
                break;
                
            // Parse headers
            ioc = s.indexOf(":");
            if (ioc >= 0){
                headers[s[0 .. ioc]] = s[(ioc + 1) .. $].strip();
            }else{
                headers[s] = "";
            }
        }
        
        return headers;
    }
    
    private string readString(ref SocketStream ss){
        uint len;
        string page, tmp;
        
        if (("StatusCode" in this.serverHeaders) && (this.serverHeaders["StatusCode"].startsWith("1") || this.serverHeaders["StatusCode"].startsWith("204" || this.serverHeaders["StatusCode"].startsWith("304")))){
            // Special codes with no data - defined in RFC 2616, section 4.4 
            // (http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.4)
            page = "";
        }else if ("Transfer-Encoding" in this.serverHeaders && this.serverHeaders["Transfer-Encoding"].tolower() == "chunked"){
            // http://en.wikipedia.org/wiki/Chunked_transfer_encoding
            len = 1;
            page = "";
            while (len != 0){
                // Skip blank lines
                tmp = "";
                while (tmp.length == 0){
                    tmp = cast(string) ss.readLine();
                }
                
                // It looks, that some servers sends responses not exactly RFC compatible :/ (or, I'm idiot which can't read :S)
                if (tmp.isNumeric()){
                    // Read size in hexa
                    std.c.stdio.sscanf(cast(char*) tmp, "%x", &len);

                    if (len == 0)
                        break;

                    // Read data
                    page ~= cast(string) ss.readString(to!(size_t)(len));
                }else{
                    page ~= tmp;
                }
            }
        }else if ("Content-Length" in this.serverHeaders){
            len = to!(uint)(this.serverHeaders["Content-Length"]);
            page = cast(string) ss.readString(to!(size_t)(len + 1))[1 .. $];
        }else{
            // Read until closed connection
            while (!ss.socket().isAlive())
                page ~= ss.readLine() ~ "\n";
        }
        
        return page;
    }
    
    private string readHeadersAndBody(ref SocketStream ss){
        // Read headers
        this.serverHeaders = readHeaders(ss);
        this.initiated = true;
        
        // Read string..
        string page = readString(ss);
        
        // Close connection
        ss.close();
        
        if (this.serverHeaders["StatusCode"].startsWith("4")){
            throw new URLException(this.serverHeaders["StatusCode"]);
        }
        
        return page;
    }
    
    private string parseGetURL(string URL, string[string] data){
        string ostr = URL;
        
        // Append url with ?, & and headers..
        if (!data.length){
            if (ostr.count("?")){
                if (ostr.count("&")){
                    if (ostr.endsWith("&"))
                        ostr ~= urlEncodeHeaders(data);
                    else
                        ostr ~= "&" ~ urlEncodeHeaders(data);
                }else{
                    if (ostr.count("="))
                        ostr ~= "&" ~ urlEncodeHeaders(data);
                    else
                        ostr ~= urlEncodeHeaders(data);
                }
            }else{
                ostr ~= "?" ~ urlEncodeHeaders(data);
            }
        }
        
        return ostr;
    }
    
    public string get(string URL, string[string] params = ["":""]){  
        ParsedURL pu = new ParsedURL(this.parseGetURL(URL, params));
        
        // Initialize connection
        SocketStream ss = initConnection(pu);
        
        // Write GET request TODO: přidat možnost odeslat GET data, přidat odeslání vlastních hlaviček
        ss.writeString("GET " ~ pu.getPath() ~ " " ~ HTTP_VERSION ~ CLRF);
        ss.writeString("Host: " ~ pu.getDomain() ~ CLRF);
        this.sendHeaders(ss);
        ss.writeString(CLRF);
        
        ss.flush();

        // Read everything and close connection
        return readHeadersAndBody(ss);
    }
    
    public string post(string URL, string[string] params = ["":""]){
        ParsedURL pu = new ParsedURL(URL);
        string enc_params = this.urlEncodeHeaders(params);
        
        // Initialize connection
        SocketStream ss = initConnection(pu);

        // Write GET request TODO: přidat možnost odeslat GET data, přidat odeslání vlastních hlaviček
        ss.writeString("POST " ~ pu.getPath() ~ " " ~ HTTP_VERSION ~ CLRF);
        ss.writeString("Host: " ~ pu.getDomain() ~ CLRF);
        this.sendHeaders(ss);
        ss.writeString("Content-Type: application/x-www-form-urlencoded" ~ CLRF);
        ss.writeString("Content-Length: " ~ std.conv.to!(string)(enc_params.length) ~ CLRF);
        ss.writeString(CLRF);
        
        // Write data
        ss.writeString(enc_params);
        ss.writeString(CLRF);
        
        ss.flush();

        // Read everything and close connection
        return readHeadersAndBody(ss);
    }
    
    public string getAndPost(string URL, string[string] get, string[string] post){
        return this.post(parseGetURL(URL, get), post);
    }
    
    public string[string] getResponseHeaders(){
        if (this.initiated)
            return this.serverHeaders;
        else
            throw new InvalidStateException("Not initiated yet.");
    }
    public string[string] getClientHeaders(){
        return this.clientHeaders;
    }
    public void setClientHeaders(string[string] iheaders){
        // Filter critical headers
        string[string] fheaders;
        foreach(string key, val; iheaders){
            if (key != "Content-Length" && key != "Host"){
                fheaders[key] = val;
            } 
        }
        
        this.clientHeaders = fheaders;
    }
}


debug{
    import std.file;
    import std.stdio;
    
    void main(){
        //~ string URL = "http://kitakitsune.org/";
        //~ string URL = "http://kitakitsune.org/proc/time.php"; // one simple line with date
        //~ string URL = "http://kitakitsune.org/bhole/parametry.php";
        string URL = "http://bit.ly/ebi4js"; // redirect
        //~ string URL = "http://anoncheck.security-portal.cz";
        //~ string URL = "http://anoncheck.security-portal.cz/background.gif";
        //~ string URL = "http://martiner.blogspot.com/2010/09/muj-nejdrazsi.html"; // not exactly normal response from server..
        //~ string URL = "http://janucesenka.blbne.cz/21848-komentare.html";
        
        
        
        //~ try{
        //~ writeln(cl.get(URL));
        
        //~ 
        //~ string[string] post = ["typ dat":"post", "postkey":"postval.."];
        //~ string[string] get = ["typ dat":"get", "getkey":"getval.."];
        HTTPClient cl = new HTTPClient();
        writeln(cl.get(URL));
        writeln(cl.getResponseHeaders());

        //~ std.file.write("asd.gif", cl.get(URL));
    }
}