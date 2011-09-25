import std.stdio;
import dhttpclient;


int main(string[] args){
	HTTPClient cl = new HTTPClient();
	
	writeln(cl.get("http://kitakitsune.org"));
	std.file.write("kitakitsune.index.html", cl.get("http://kitakitsune.org"));
	
	return 0;
}