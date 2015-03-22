unit log;

interface

uses sysutils;

procedure dolog(t : string);

var
LOG_FILE : Text;

implementation

procedure dolog(t : string);
var
LOG_FILE : Text;

begin
   Assign(LOG_FILE,'shipgame.log');
   append(LOG_FILE);   
   writeln(LOG_FILE, DateTimeToStr(Now) + ':	' + t);
   writeln(t);
   close(LOG_FILE)
end;

begin
   Assign(LOG_FILE,'shipgame.log');
   rewrite(LOG_FILE); //creates file if it doesn't exist
   writeln(LOG_FILE, 'Shipgame log');
   writeln(LOG_FILE, '');
   close(LOG_FILE)
end.
