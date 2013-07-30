/**
 * Simple socket wrapper, which allows download data and send GET/POST requests.
 *
 * Sources;
 * 
 *     - http://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol
 * 
 *     - http://en.wikipedia.org/wiki/List_of_HTTP_status_codes
 * 
 *     - http://en.wikipedia.org/wiki/Chunked_transfer_encoding
 * 
 *     - http://www.faqs.org/rfcs/rfc2616.html
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 1.7.5
 * Date:    30.07.2013
 * 
 * Copyright: This work is licensed under a CC BY (http://creativecommons.org/licenses/by/3.0/). 
 * 
 * This means that you can do whatever you want, but you have to add authors name. 
 * If you dont like this licence, send me email and I can release module under different conditions.
 * 
*/
module dhttpclient;


//==============================================================================
//= Imports ====================================================================
//==============================================================================
import std.uri;
import std.conv;
import std.array;
import std.string;
import std.socket;
import std.socketstream;



//==============================================================================
//= Global variables ===========================================================
//==============================================================================

/// This enum is used in DHTTPClient class for storing information about request when redirecting.
private enum RequestType {NONEYET, GET, POST, GETANDPOST};

/// Headers from firefox 3.6.13 on windows
public enum string[string] FFHeaders =  [
	"User-Agent"      : "Mozilla/5.0 (Windows; U; Windows NT 5.1; cs; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.13",
	"Accept"          : "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain",
	"Accept-Language" : "cs,en-us;q=0.7,en;q=0.3",
	"Accept-Charset"  : "utf-8",
	"Keep-Alive"      : "300",
	"Connection"      : "keep-alive"
];

/// Headers from firefox 3.6.13 on Linux
public enum string[string] LFFHeaders =  [
	"User-Agent"      : "Mozilla/5.0 (X11; U; Linux i686; cs; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.13",
	"Accept"          : "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain",
	"Accept-Language" : "cs,en-us;q=0.7,en;q=0.3",
	"Accept-Charset"  : "utf-8",
	"Keep-Alive"      : "300",
	"Connection"      : "keep-alive"
];

/// Headers from Internet Explorer 7.0 on Windows NT 6.0
public enum string[string] IEHeaders =  [
	"User-Agent"      : "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)",
	"Accept"          : "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain",
	"Accept-Language" : "cs,en-us;q=0.7,en;q=0.3",
	"Accept-Charset"  : "utf-8",
	"Keep-Alive"      : "300",
	"Connection"      : "keep-alive"
];

/**
 * Headers which will be used with new instances of DHTTPClient.
 * 
 * If you want different headers for all your future instances of DHTTPClient, just do something like
 * -----------------------
 * dhttpclient.DefaultHeaders = dhttpclient.IEHeaders;
 * -----------------------
 * 
 * Standardvalue is FFHeaders.
 * 
 * See_also:
     * FFHeaders
*/
public string[string] DefaultHeaders;



// Module constructor. Used for setting default headers.
static this(){
	DefaultHeaders = FFHeaders;
}



//==============================================================================
//= Exceptions =================================================================
//==============================================================================
/**
 * General exception for all exceptions throwed from this module.
 * 
 * If you want catch all subexceptions (URLException, InvalidStateException, StatusCodeException), use this exception. 
 * 
 * ------------
 * try{
 *     DHTTPClient d = new DHTTPClient();
 *     ...
 * }catch(HTTPClientException){
 *     // this catch all exceptions which are throwed from DHTTPClient
 * }
 * ------------
*/
public class HTTPClientException:Exception{
	this(string msg){
	    super(msg);
	}
}

/// This exception is throwed when isn't possible parse or download given page, or is used unknown protocol, etc..
public class URLException:HTTPClientException{
	this(string msg){
	    super(msg);
	}
}

///
public class InvalidStateException:HTTPClientException{
	this(string msg){
	    super(msg);
	}
}

/**
 * This exception is thrown, when server return StatusCode different than 200 (Ok), or 301 (Redirection).
 * 
 * Exception contains informations about StatusCode and data returned by server.
*/
public class StatusCodeException:HTTPClientException{
	private uint status_code;
	private string data;
	
	this(string msg){
		super(msg);
	}

	this(string msg, uint status_code, string data){
		super(msg);
		this.status_code = status_code;
		this.data = data;
	}

	/// Returns given StatusCode
	uint getStatusCode(){
		return this.status_code;
	}

	/// Returns data downloaded from server
	string getData(){
		return this.data;
	}
}



//==============================================================================
//= Classes ====================================================================
//==============================================================================
/**
 * Class for parsing url.
*/
public class ParsedURL {
	private string protocol, domain, path, url;
	private ushort port = 0;

	this(string URL){
		string[] t;
		this.url = URL;

		// Parse protocol
		if (URL.indexOf("://") >= 0){
			t = split(URL, "://");

			this.protocol = t[0].toLower();
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
			this.path   = "/?" ~ join(t[1 .. $], "?");
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
	
	public void setPath(string path){
		this.url = this.url.replace(this.path, path);
		this.path = path;
	}

	override public string toString(){
		return this.url;
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
	assert(pu.getPath() == "/?asd");

	pu = new ParsedURL("http://kitakitsune.org:2011?asd");
	assert(pu.getDomain() == "kitakitsune.org");
	assert(pu.getPort() == 2011);
	assert(pu.getPath() == "/?asd");
}


/**
 * Class which allows download data and send GET and POST requests.
*/ 
public class HTTPClient{
	private const string CLRF             = "\r\n";
	private const string OLD_HTTP_VERSION = "HTTP/1.0";
	private const string HTTP_VERSION     = "HTTP/1.1";
	private string[string] serverHeaders; // In this variable are after each request stored headers from server.
	private string[string] clientHeaders; // Headers which send client to the server.
	private bool initiated = false;       // This variable is set to true after first request.

	// StatusCode 301 (Redirection) handling
	private bool ignore_redirect = false; // If true, redirects are ignored.
	
	// Maximal recursion in one request (if server return redirection to another server, ant he to another, it should cause DoS..)
	private uint max_recursion = 8;
	private uint recursion;                                 // Variable where is stored how many redirection was done
	private string[string] get_params, post_params;         // In these variables are stored parameters when client is redirected to another server
	private RequestType request_type = RequestType.NONEYET; // Which method call in case of redirection..
	
	private bool https_allowed = false;

	private TcpSocket function(string domain, ushort port) getTcpSocket;

	this(){
		this.clientHeaders = cast(string[string]) DefaultHeaders;

		// Set default TcpSocket creator
		this.getTcpSocket = function(string domain, ushort port){
			return new TcpSocket(new InternetAddress(domain, port));
		};
	}

	/**
	 * Initialize connection to server.
	 *
	 * See_also: ParsedURL
	*/
	private SocketStream initConnection(ref ParsedURL pu){
		if (! (pu.getProtocol() == "http" || (https_allowed && pu.getProtocol() == "https"))) // support only http/https
			throw new URLException("Bad protocol; " ~ pu.getProtocol() ~ " is not allowed!\n"
									"If you don't know, why this exception was thrown, there is pretty big chance, that you were redirected to another page.\n" 
									"You can set redirection off with setIgnoreRedirect(true), or allow https with httpsAllowed() API (but https is uninmplemented, "
									"so you need to use your own ssl socket - check setTcpSocketCreator() :X).");

		TcpSocket tsock;

		try
			tsock = this.getTcpSocket(pu.getDomain(), pu.getPort());
		catch(std.socket.AddressException e)
			throw new URLException(e.toString());

		return new SocketStream(tsock);
	}

	/**
	 * Set TCP Socket creator. Normally, with each request is created new TcpSocket object.
	 * Sometimes is useful have option to set own (for example https support, proxy ..).
	 *
	 * Argument fn is pointer to function, which returns TcpSocket and accepts two parameters
	 * domain and port (classic TcpSocket parameters).
	 *
	 * Default is function(string domain, ushort port){
			return new TcpSocket(new InternetAddress(domain, port));
		};
	 *
	 * See_also: TcpSocket
	*/ 
	public void setTcpSocketCreator(TcpSocket function(string domain, ushort port) fn){
		this.getTcpSocket = fn;
	}

	/// Send client headers to server.
	private void sendHeaders(ref SocketStream ss){
		// Send headers
		foreach(string key, val; this.clientHeaders)
			ss.writeString(key ~ ": " ~ val ~ CLRF);
	}

	/// Urlencode all given parameters.
	private string urlEncodeParams(string[string] headers){
		string ostr = "";

		foreach(string key, val; headers)
			ostr ~= std.uri.encodeComponent(key) ~ "=" ~ std.uri.encodeComponent(val) ~ "&";

		return ostr;
	}

	/// Read all headers from server.
	private string[string] readHeaders(ref SocketStream ss){
		string s = " ";
		string[string] headers;
		uint ioc = 0;

		// Read status line
		s = cast(string) ss.readLine();
		if (s.length <= 0)
			return headers;
		else if (s.indexOf(HTTP_VERSION) >= 0)
			headers["StatusCode"] = s.replace(cast(string) HTTP_VERSION, "").strip();
		else if (s.indexOf(OLD_HTTP_VERSION))  // HTTP/1.0 support
			headers["StatusCode"] = s.replace(cast(string) OLD_HTTP_VERSION, "").strip();
		else
			headers["StatusCode"] = s;

		// Read headers
		s = " ";
		while (s.length > 0){
			s = cast(string) ss.readLine();

			if (s.length == 0)
				break;

			// Parse headers
			ioc = cast(uint) s.indexOf(":");
			if (ioc > 0)
				headers[s[0 .. ioc]] = s[(ioc + 1) .. $].strip();
			else
				break;
		}
		
		return headers;
	}

	protected bool isHex(string s){
		foreach(c; s){
			if (! ((c >= '0' && c <= '9') || 
			       (c >= 'A' && c <= 'F') ||
			       (c >= 'a' && c <= 'f')))
				return false;
		}
		
		return true;
	}

	/// Read data from string and return them as string (which can be converted into anything else).
	private string readString(ref SocketStream ss){
		uint len;
		string page, tmp;
		
		// I am too lazy write this.serverHeaders["StatusCode"]; again, again and again..
		string status_code;
		if ("StatusCode" in this.serverHeaders)
			status_code = this.serverHeaders["StatusCode"];
		
		// Special codes with no data - defined in RFC 2616, section 4.4
		// (http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.4)
		if (status_code != "" && (status_code.startsWith("1") || status_code.startsWith("204") || status_code.startsWith("304"))){
			page = "";
		}else if ("Transfer-Encoding" in this.serverHeaders && this.serverHeaders["Transfer-Encoding"].toLower() == "chunked"){
			// http://en.wikipedia.org/wiki/Chunked_transfer_encoding
			len = 1;
			page = "";
			while (len != 0){
				// Skip blank lines
				tmp = "";
				while (tmp.length == 0)
					tmp = cast(string) ss.readLine();

				len = std.conv.parse!int(tmp, 16);

				if (len == 0)
					break;

				// Read data
				page ~= (cast(string) ss.readString(to!(size_t)(len + 1)))[1 .. $];
			}
		}else if ("Content-Length" in this.serverHeaders){
			len = to!(uint)(this.serverHeaders["Content-Length"]);
			page = cast(string) ss.readString(to!(size_t)(len + 1))[1 .. $];
		}else{
			const uint BUFF_SIZE = 1024;
			ubyte[BUFF_SIZE] buff;
			
			// Read until closed connection
			while (ss.socket().isAlive()){
				// readBlock is better than readString, because readString throws away '\n', so you dont know
				// if you've received just '\n', or nothing
				size_t size = ss.readBlock(&buff, BUFF_SIZE);
				
				// this actually ends while, ss.socket().isAlive() is sadly not so much useful
				if (size <= 0)
					break;
				
				page ~= cast(string) buff[0 .. size];
			}
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

		uint num_status_code = 0;
		string status_code = this.serverHeaders["StatusCode"];
		
		if (status_code.startsWith("4")){
			// Get StatusCode as int
			if (status_code.indexOf(" ") > 0)
				num_status_code = std.conv.to!int(status_code[0 .. status_code.indexOf(" ")]);
			
			throw new StatusCodeException(status_code, num_status_code, page);
		}

		return page;
	}
	
	/// Mix url with parameters for get request.
	private string parseGetURL(string URL, string[string] data){
		string ostr = URL;

		// Append url with ?, & and headers..
		if (data.length){
			if (ostr.count("?")){
				if (ostr.count("&")){
					if (ostr.endsWith("&"))
						ostr ~= urlEncodeParams(data);
					else
						ostr ~= "&" ~ urlEncodeParams(data);
				}else{
					if (ostr.count("="))
						ostr ~= "&" ~ urlEncodeParams(data);
					else
						ostr ~= urlEncodeParams(data);
				}
			}else
				ostr ~= "?" ~ urlEncodeParams(data);
		}

		return ostr;
	}
	
	private string handleExceptions(string data, ParsedURL pu){
		// it was little bit annoying write this.serverHeaders["StatusCode"] again, again and again
		string status_code;
		if ("StatusCode" in this.serverHeaders)
			status_code = this.serverHeaders["StatusCode"];
		
		// Exceptions handling
		if (status_code != "" && !status_code.startsWith("200") && !(status_code.indexOf("200 OK") > 0)){
			// React to 301 StatusCode (redirection)
			if (status_code.startsWith("301") || status_code.startsWith("302")){
				// Check if redirection is allowed
				if (! this.ignore_redirect){
					// Be careful how many redirections was allready done
					if (this.recursion++ <= this.max_recursion){
						// Redirection to different path at same server
						if (this.serverHeaders["Location"].indexOf("://") < 0){
							pu.setPath(this.serverHeaders["Location"]);
							this.serverHeaders["Location"] = pu.toString();
						}
						
						final switch(this.request_type){
							case RequestType.GET:
								return this.get(this.serverHeaders["Location"], this.get_params);
							case RequestType.POST:
								return this.post(this.serverHeaders["Location"], this.post_params);
							case RequestType.GETANDPOST:
								return this.getAndPost(this.serverHeaders["Location"], this.get_params, this.post_params);
							case RequestType.NONEYET:
								throw new HTTPClientException("This is pretty strange exception - code flow _NEVER_ shoud be here!");
						}
					}else{
						this.recursion = 0;
						throw new URLException("Error - too many (" ~ std.conv.to!(string)(this.max_recursion) ~ ") redirections.");
					}
				}else{ // If redirection isn't allowed, return page with redirection headers
					this.recursion = 0;
					return data;
				}
			}else{ // Every other StatusCode throwing exception
				if ("StatusCode" in this.serverHeaders){
					uint tmp_status_code; 
					
					// Try parse numeric status code, if fails, use whole string
					try
						tmp_status_code =  to!(uint)(status_code[0 .. 3]);
					catch(Exception)
						throw new StatusCodeException(status_code);
					
					throw new StatusCodeException(status_code, tmp_status_code, data);
				}else
					throw new StatusCodeException("Can't find status code - connection lost?");
			}
		}else{ // StatusCode 200 - Ok
			this.recursion = 0;
			return data;
		}
		
		throw new HTTPClientException("This is pretty strange exception - code flow _NEVER_ shoud be here (last line in handleExceptions())!");
	}

	 /**
	 * Downloads given URL.
	 *
	 * If there are some parameters, send them as GET data.
	 *
	 * Example:
	 * ------------
	 * HTTPClient cl = new HTTPClient();
	 * cl.get("http://google.com");
	 * ------------
	 * or
	 * ------------
	 * cl.get("http://google.com", ["query":"dhttpclient"]);
	 * ------------
	 *
	 * After each request it is possible to get server headers with getResponseHeaders().
	 *
	 * Returns:
	 *     Data from server.
	 *
	 * Throws:
	 *     URLException, if isn't set ignore_redirect and when server redirect to server which redirect .. more than is set by setMaxRecursion().
	 *
	 *     HTTPClientException when things goes bad.
	 *
	 *     StatusCodeException if server returns headers with code different from 200 (Ok), or 301 (Redirect).
	 *
	 * See_also:
	 *     getResponseHeaders()
	*/
	public string get(string URL, string[string] params = null){
		// Save status for case of redirection
		this.request_type = RequestType.GET;
		this.get_params = params;

		// Parse URL
		ParsedURL pu = new ParsedURL(this.parseGetURL(URL, params));

		// Initialize connection
		SocketStream ss = initConnection(pu);

		// Write GET request
		ss.writeString("GET " ~ pu.getPath() ~ " " ~ HTTP_VERSION ~ CLRF);
		
		if (pu.getPort() == 80)
			ss.writeString("Host: " ~ pu.getDomain() ~ CLRF);
		else
			ss.writeString("Host: " ~ pu.getDomain() ~ ":" ~ to!string(pu.getPort()) ~ " " ~ CLRF);
		
		this.sendHeaders(ss);
		ss.writeString(CLRF);

		ss.flush();

		// Read everything and close connection, handle exceptions
		return handleExceptions(readHeadersAndBody(ss), pu);
	}

	/**
	 * Send POST data to server and return given data.
	 *
	 * Example:
	 * -----
	 * HTTPClient cl = new HTTPClient();
	 * cl.post("http://some.server/script.php", ["TYPE":"POST"]);
	 * -----
	 *
	 * After each request is possible get server header with getResponseHeaders().
	 *
	 * Returns:
	 *     Data from server.
	 *
	 * Throws:
	 *     URLException, if isn't set ignore_redirect and when server redirect to server which redirect .. more than is set by setMaxRecursion().
	 *
	 *     HTTPClientException when things goes bad.
	 *
	 *     StatusCodeException if server returns headers with code different from 200 (Ok), or 301 (Redirect).
	 *
	 * See_also:
	 *     getResponseHeaders()
	 */
	public string post(string URL, string[string] params){
		// Save status for case of redirection
		if (this.request_type != RequestType.GETANDPOST){
			this.request_type = RequestType.POST;
			this.post_params = params;
		}

		// Parse URL
		ParsedURL pu = new ParsedURL(URL);

		// Encode params
		string enc_params = this.urlEncodeParams(params);

		// Initialize connection
		SocketStream ss = initConnection(pu);

		// Write POST request
		ss.writeString("POST " ~ pu.getPath() ~ " " ~ HTTP_VERSION ~ CLRF);
		
		if (pu.getPort() == 80)
			ss.writeString("Host: " ~ pu.getDomain() ~ CLRF);
		else
			ss.writeString("Host: " ~ pu.getDomain() ~ ":" ~ to!string(pu.getPort()) ~ " " ~ CLRF);
		
		this.sendHeaders(ss);
		ss.writeString("Content-Type: application/x-www-form-urlencoded" ~ CLRF);
		ss.writeString("Content-Length: " ~ std.conv.to!(string)(enc_params.length) ~ CLRF);
		ss.writeString(CLRF);

		// Write data
		ss.writeString(enc_params);
		ss.writeString(CLRF);

		ss.flush();

		// Read everything and close connection, handle exceptions
		return handleExceptions(readHeadersAndBody(ss), pu);
	}

	/**
	 * Send GET and POST data in one request.
	 *
	 * Returns:
	 *     Data from server.
	 *
	 * Throws:
	 *     URLException, if isn't set ignore_redirect and when server redirect to server which redirect .. more than is set by setMaxRecursion().
	 *
	 *     HTTPClientException when things goes bad.
	 *
	 *     StatusCodeException if server returns headers with code different from 200 (Ok), or 301 (Redirect).
	 *
	 * See_also:
	 *     HTTPClient.get()
	 *
	 *     HTTPClient.post()
	 *
	 *     getResponseHeaders()
	*/
	public string getAndPost(string URL, string[string] get, string[string] post){
		// Save status for case of redirection
		this.request_type = RequestType.GETANDPOST;
		this.get_params = get;
		this.post_params = post;

		return this.post(parseGetURL(URL, get), post);
	}

	/**
	 * Return server headers from request.
	 *
	 * Throws:
	 *     InvalidStateException if request wasn't send yet.
	*/
	public string[string] getResponseHeaders(){
		if (this.initiated)
			return this.serverHeaders;
		else
			throw new InvalidStateException("Not initiated yet.");
	}

	/**
	 * Return headers which client sends each request.
	*/
	public string[string] getClientHeaders(){
		return this.clientHeaders;
	}
	/**
	 * Set headers which will client send each request.
	 *
	 * Headers can´t contain Content-Length and Host headers.
	*/
	public void setClientHeaders(string[string] iheaders){
		// Filter critical headers
		string[string] fheaders;
		foreach(string key, val; iheaders)
			if (key != "Content-Length" && key != "Host")
				fheaders[key] = val;

		this.clientHeaders = fheaders;
	}

	///
	public bool getIgnoreRedirect(){
		return this.ignore_redirect;
	}
	/**
	 * If is set (true), client ignore StatusCode 301 and doesn't redirect.
	 *
	 * This could be useful, because some pages return's interesting content which you can't normally see :)
	*/
	public void setIgnoreRedirect(bool ir){
	    this.ignore_redirect = ir;
	}
	
	/// Default false.
	public void httpsAllowed(bool state){
		this.https_allowed = state;
	}
	public bool httpsAllowed(){
		return https_allowed;
	}

	///
	public uint getMaxRecursion(){
		return this.max_recursion;
	}
	/**
	 * Set max. redirect in one request.
	 *
	 * Default is 8.
	*/
	public void setMaxRecursion(uint mr){
		this.max_recursion = mr;
	}
}
