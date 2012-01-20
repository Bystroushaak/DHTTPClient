/**
 * Binary download example
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.0.1
 * Date:    20.01.2012
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
*/
import std.stdio;
import dhttpclient;


int main(string[] args){
	HTTPClient cl = new HTTPClient();
	
	// binary files are easy, you just have to cast them to ubyte[]
	std.file.write("logo3w.png", cast(ubyte[]) cl.get("http://www.google.cz/images/srpr/logo3w.png"));
	
	// mimetype of downloaded file
	writeln(cl.getResponseHeaders()["Content-Type"]);
	
	return 0;
}
