import std.stdio;
import dhttpclient;

/*
 * http://bit.ly/gX0v4M
 * 
 * <?PHP
 * echo "GET:\n";
 * foreach($_GET as $key => $value){
 *     echo "\t".$key."=".$value."\n";
 * }
 * echo "POST:\n";
 * foreach($_POST as $key => $value){
 *     echo "\t".$key."=".$value."\n";
 * }
 * ?>
*/
int main(string[] args){
	HTTPClient cl = new HTTPClient();
	
	writeln(cl.getAndPost("http://bit.ly/gX0v4M", ["get":"data"], ["post":"data2"]));
	
	return 0;
}