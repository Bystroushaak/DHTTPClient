/**
 * User agent change example
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.0.1
 * Date:    20.01.2012
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
*/
import dhttpclient;



int main(string [] args){
	// You can change user agent two ways:
	
	// Create your own headers
	string[string] my_headers = dhttpclient.FFHeaders; // there are more headers than just User-Agent and you have to copy it
	my_headers["User-Agent"] = "My own spider!";
	
	// For all clients:
	dhttpclient.DefaultHeaders = my_headers;
	
	// For one instance:
	HTTPClient cl = new HTTPClient();
	cl.setClientHeaders(my_headers);
	
	return 0;
}
