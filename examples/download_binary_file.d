import std.stdio;
import dhttpclient;


int main(string[] args){
	HTTPClient cl = new HTTPClient();
	
	// binary files are easy, you just have to cast them to ubyte[]
	std.file.write("logo3w.png", cast(ubyte[]) cl.get("http://www.google.cz/images/srpr/logo3w.png"));
	
	return 0;
}
