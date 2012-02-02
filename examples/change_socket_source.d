/**
 * Change socket source example
 *
 * You can change socket source, which allows you implement SSL tunneling and etc..
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 1.0.0
 * Date:    02.02.2012
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
*/
import std.stdio;
import std.string : strip;
import std.socket, std.socketstream; // Neede for StdioWritingSocket

import dhttpclient;


// This class have almost same functionality as TcpSocket, but it writelns all 
// outgoing data to terminal.
class StdioWritingSocket : TcpSocket{
	this(AddressFamily family){
		super(family);
	}
	
	this(InternetAddress ia){
		super(ia);
	}
	
	// Write and send data
	override ptrdiff_t send(const(void)[] buf){
		writeln((cast(string) (cast(ubyte[]) buf)).strip());
		return super.send(buf);
	}
}


int main(string[] args){
	HTTPClient cl = new HTTPClient();
	
	// Here goes magic - replace TcpSocket with StdioWritingSocket, which will be used for all connections from now.
	cl.setTcpSocketCreator(function(string domain, ushort port){
		return new StdioWritingSocket(new InternetAddress(domain, port));
	});
	
	cl.get("http://kitakitsune.org");
	
	return 0;
}
