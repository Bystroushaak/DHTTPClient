/* TODO:
 *  Vyhodit URL exception pokud neobsahuje protokol.
 *  Hledat Location v hlavičkách.
 *      Udělat fci která ignoruje location?
*/

// odstranit

import std.stdio;

// //--

import std.socket;
import std.socketstream;
import std.socket;
import std.string;
import std.conv;

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
            // TODO: raise URL exception
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
                    this.port = 0; // or raise exception?
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
    
    private SocketStream initConnection(ref ParsedURL pu){
        if (pu.getProtocol() != "http"){
            ; // TODO: raise exception
        }
            
        TcpSocket tsock = new TcpSocket(new InternetAddress(pu.getDomain(), pu.getPort()));

        return new SocketStream(tsock);
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
        
        // Read headers.
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
    
    public string getPage(string URL){
        uint len;
        string page, tmp;
        ParsedURL pu = new ParsedURL(URL);
        
        // Initialize connection
        SocketStream ss = initConnection(pu);
        
        // Write GET request
        ss.writeString("GET " ~ pu.getPath() ~ " " ~ HTTP_VERSION ~ CLRF);
        ss.writeString("Host: " ~ pu.getDomain() ~ CLRF);
        ss.writeString(CLRF);

        // Read headers
        string[string] headers = readHeaders(ss);
        
        if (("StatusCode" in headers) && (headers["StatusCode"].startsWith("1") || headers["StatusCode"].startsWith("204" || headers["StatusCode"].startsWith("304")))){
            // Special codes with no data - defined in RFC 2616, section 4.4 
            // (http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.4)
            page = "";
        }else if ("Transfer-Encoding" in headers && headers["Transfer-Encoding"].tolower() == "chunked"){
            // http://en.wikipedia.org/wiki/Chunked_transfer_encoding
            len = 1;
            page = "";
            while (len != 0){
                // blank lines skip
                tmp = "";
                while (tmp.length == 0){
                    tmp = cast(string) ss.readLine();
                }
                
                // read size in hexa
                std.c.stdio.sscanf(cast(char*) tmp, "%x", &len);
                
                if (len == 0)
                    break;
                
                // read data
                page ~= ss.readString(to!(size_t)(len));
            }
        }else if ("Content-Length" in headers){
            len = to!(uint)(headers["Content-Length"]);
            page = cast(string) ss.readString(to!(size_t)(len + 1));
            // TODO: raise shit happen (nebo ukonceny pomoci close() ?)
        }else{
            // Read until closed connection
            while (!ss.socket().isAlive())
                page ~= ss.readLine() ~ "\n";
        }
        
        // close connection
        ss.close();
        
        return page;
    }
}



void main(){
    //~ string URL = "http://kitakitsune.org/";
    //~ string URL = "http://kitakitsune.org/proc/time.php"; // one simple line with date
    //~ string URL = "http://bit.ly/ebi4js"; // redirect
    string URL = "http://anoncheck.security-portal.cz";
    
    HTTPClient cl = new HTTPClient();
    
    writeln(cl.getPage(URL));
    //~ cl.getPage(URL);
}
