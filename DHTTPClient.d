/* DHTTPClient.d v0.5.0 (11.01.2011) by Bystroushaak (bystrousak@kitakitsune.org)
 * 
*/

import std.uri;
import std.conv;
import std.string;
import std.socket;
import std.socketstream;

private enum RequestType {NONEYET, GET, POST, GETANDPOST};

public enum string[string] FFHeaders =  [
    "User-Agent"      : "Mozilla/5.0 (Windows; U; Windows NT 5.1; cs; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.13",
    "Accept"          : "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain",
    "Accept-Language" : "cs,en-us;q=0.7,en;q=0.3",
    "Accept-Charset"  : "utf-8",
    "Keep-Alive"      : "300",
    "Connection"      : "keep-alive"
];

public enum string[string] LFFHeaders =  [
    "User-Agent"      : "Mozilla/5.0 (X11; U; Linux i686; cs; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.13",
    "Accept"          : "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain",
    "Accept-Language" : "cs,en-us;q=0.7,en;q=0.3",
    "Accept-Charset"  : "utf-8",
    "Keep-Alive"      : "300",
    "Connection"      : "keep-alive"
];

public enum string[string] IEHeaders =  [
    "User-Agent"      : "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)",
    "Accept"          : "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain",
    "Accept-Language" : "cs,en-us;q=0.7,en;q=0.3",
    "Accept-Charset"  : "utf-8",
    "Keep-Alive"      : "300",
    "Connection"      : "keep-alive"
];

public enum string[string] DefaultHeaders = FFHeaders;



public class HTTPClientException:Exception{
    this(string msg){
        super(msg);
    }
}
public class URLException:HTTPClientException{
    this(string msg){
        super(msg);
    }
}
public class InvalidStateException:HTTPClientException{
    this(string msg){
        super(msg);
    }
}
public class StatusCodeException:HTTPClientException{
    private uint status_code;
    this(string msg, uint status_code){
        super(msg);
        this.status_code = status_code;
    }
    
    uint getStatusCode(){
        return this.status_code;
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
        }else if (URL.indexOf("?") >= 0){
            t = split(URL, "?");
            
            this.domain = t[0];
            this.path   = "?" ~ join(t[1 .. $], "?");
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

unittest{
    ParsedURL pu = new ParsedURL("http://kitakitsune.org/");
    
    assert(pu.getPort() == 80);
    assert(pu.getPath() == "/");
    assert(pu.getProtocol() == "http");
    assert(pu.getDomain() == "kitakitsune.org");
    
    pu = new ParsedURL("http://kitakitsune.org?asd");
    assert(pu.getDomain() == "kitakitsune.org");
    assert(pu.getPath() == "?asd");
    
    pu = new ParsedURL("http://kitakitsune.org:2011?asd");
    assert(pu.getDomain() == "kitakitsune.org");
    assert(pu.getPort() == 2011);
    assert(pu.getPath() == "?asd");
}



public class HTTPClient{
    private const string CLRF = "\r\n";
    private const string HTTP_VERSION = "HTTP/1.1";
    private string[string] serverHeaders;
    private string[string] clientHeaders;
    private bool initiated = false;

    // This is for exceptions handling
    private bool ignore_redirect = false;
    private uint max_recursion = 8;
    private uint recursion;
    private RequestType request_type = RequestType.NONEYET;
    
    // 301 Redirection handling
    private string[string] get_params, post_params;
    
    this(){
        this.clientHeaders = cast(string[string]) DefaultHeaders;
    }
    
    private SocketStream initConnection(ref ParsedURL pu){
        if (pu.getProtocol() != "http"){
            throw new URLException("Bad protocol!");
        }
        
        TcpSocket tsock;
        
        try{
            tsock = new TcpSocket(new InternetAddress(pu.getDomain(), pu.getPort()));
        }catch(std.socket.AddressException e){
            throw new URLException(e.toString());
        }
        
        return new SocketStream(tsock);
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
        if (data.length){
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
    
    private string handleExceptions(string data){
        // Exceptions handling
        if ("StatusCode" in this.serverHeaders && !this.serverHeaders["StatusCode"].startsWith("200")){
            // React on 301 StatusCode (redirection)
            if (this.serverHeaders["StatusCode"].startsWith("301")){
                // Check if redirection is allowed
                if (! this.ignore_redirect){
                    // Be carefull how many redirections was allready did
                    if (this.recursion++ <= this.max_recursion){
                        final switch(this.request_type){
                            case RequestType.GET:
                                return this.get(this.serverHeaders["Location"], this.get_params);
                            case RequestType.POST:
                                return this.post(this.serverHeaders["Location"], this.post_params);
                            case RequestType.GETANDPOST:
                                return this.getAndPost(this.serverHeaders["Location"], this.get_params, this.post_params);
                            case RequestType.NONEYET:
                                throw new HTTPClientException("This is pretty strange exception - code flow _NEVER_ shoud be here!"); 
                                break;
                        }
                    }else{
                        this.recursion = 0;
                        throw new HTTPClientException("Error - too many (" ~ std.conv.to!(string)(this.max_recursion) ~ ") redirections.");
                    }
                }else{ // If redirection isn't allowed, return page with redirection headers
                    this.recursion = 0;
                    return data;
                }
            }else{ // Every other StatusCode throwing exception
                throw new StatusCodeException(this.serverHeaders["StatusCode"], to!(uint)(this.serverHeaders["StatusCode"][0 .. 3]));
            }
        }else{ // StatusCode 200 - Ok
            this.recursion = 0;
            return data;
        }   
    }
    
    public string get(string URL, string[string] params = ["":""]){
        // Save status for case of redirection
        this.request_type = RequestType.GET;
        this.get_params = params;
        
        // Parse URL
        ParsedURL pu = new ParsedURL(this.parseGetURL(URL, params));
        
        // Initialize connection
        SocketStream ss = initConnection(pu);
        
        // Write GET request
        ss.writeString("GET " ~ pu.getPath() ~ " " ~ HTTP_VERSION ~ CLRF);
        ss.writeString("Host: " ~ pu.getDomain() ~ CLRF);
        this.sendHeaders(ss);
        ss.writeString(CLRF);
        
        ss.flush();
        
        // Read everything and close connection, handle exceptions
        return handleExceptions(readHeadersAndBody(ss));
    }
    
    public string post(string URL, string[string] params = ["":""]){
        // Save status for case of redirection
        if (this.request_type != RequestType.GETANDPOST){
            this.request_type = RequestType.POST;
            this.post_params = params;
        }
        
        // Parse URL
        ParsedURL pu = new ParsedURL(URL);
        
        // Encode params
        string enc_params = this.urlEncodeHeaders(params);
        
        // Initialize connection
        SocketStream ss = initConnection(pu);

        // Write GET request
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

        // Read everything and close connection, handle exceptions
        return handleExceptions(readHeadersAndBody(ss));
    }
    
    public string getAndPost(string URL, string[string] get, string[string] post){
        // Save status for case of redirection
        this.request_type = RequestType.GETANDPOST;
        this.get_params = get;
        this.post_params = post;
        
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
    
    public bool getIgnoreRedirect(){
        return this.ignore_redirect;
    }
    public void setIgnoreRedirect(bool ir){
        this.ignore_redirect = ir;
    }
    
    public uint getMaxRecursion(){
        return this.max_recursion;
    }
    public void setMaxRecursion(uint mr){
        this.max_recursion = mr;
    }
}


debug{
    import std.file;
    import std.stdio;
    
    void main(){
//         string URL = "http://kitakitsune.org/";
//         string URL = "http://kitakitsune.org/proc/time.php"; // one simple line with date
//         string URL = "http://kitakitsune.org/bhole/parametry.php";
//         string URL = "http://bit.ly/gX0v4M"; // redirect
//         string URL = "http://anoncheck.security-portal.cz";
//         string URL = "http://anoncheck.security-portal.cz/background.gif";
//         string URL = "http://martiner.blogspot.com/2010/09/muj-nejdrazsi.html"; // not exactly normal response from server..
//         string URL = "http://janucesenka.blbne.cz/21848-komentare.html";
        
        string[string] post = ["typ dat":"post", "postkey":"postval.."];
        string[string] get = ["typ dat":"get", "getkey":"getval.."];
        HTTPClient cl = new HTTPClient();
//         writeln(cl.get(URL, get));
//         writeln(cl.post(URL, post));
        cl.setIgnoreRedirect(true);
        writeln(cl.getClientHeaders());
//         writeln(cl.getAndPost("http://kitakitsune.org/xa", get, post));
//         writeln(cl.getResponseHeaders());

//         std.file.write("asd.gif", cl.get(URL));
    }
}