/* TODO:
 *  Vyhodit URL exception pokud neobsahuje protokol.
 * 
*/

// odstranit

import std.stdio;

// //--

import std.socket;
import std.socketstream;
import std.socket;
import std.string;

const auto CLRF = "\r\n";
const auto HTTP_VERSION = "HTTP/1.1";

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
            this.port   = std.conv.to!(ushort)(t[1]);
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
            sum ~= "\nPort:\t\t" ~ std.conv.to!(string)(this.port);
        else
            sum ~= "\nPort:\t\t" ~ std.conv.to!(string)(this.port) ~ " (unknown)";
        sum ~= "\nPath:\t\t" ~ this.path;
        
        return sum;
    }
}

private SocketStream initConnection(ParsedURL pu){
    if (pu.getProtocol() != "http"){
        ; // TODO: raise exception
    }
        
    TcpSocket tsock = new TcpSocket(new InternetAddress(pu.getDomain(), pu.getPort()));

    return new SocketStream(tsock);
}

//~ public getPage(){
    //~ 
//~ }

void main(){
    string URL = "http://kitakitsune.org/proc/time.php";
    ParsedURL pu = new ParsedURL(URL);
    
    SocketStream ss = initConnection(pu);
    
    write(">> ", "GET " ~ pu.getPath() ~ " " ~ HTTP_VERSION ~ CLRF);
    write(">> ", "Host: " ~ pu.getDomain() ~ CLRF);
    ss.writeString("GET " ~ pu.getPath() ~ " " ~ HTTP_VERSION ~ CLRF);
    ss.writeString("Host: " ~ pu.getDomain() ~ CLRF);
    ss.writeString(CLRF);

    writeln(ss.readLine());
    
    string s = " ";
    uint len;
    while (s.length){
        s = cast(string) ss.readLine();
        writeln(s);
        
        if (s.tolower().startsWith("content-length")){
            len = std.conv.to!(uint)(s.split(":")[1].strip());
        }
    }
    
    string page = cast(string) ss.readString(std.conv.to!(size_t)(len + 1));
    
    writeln(page);

    ss.close();
}
