unit InputClass;
{$mode objfpc}{$H+}
interface

uses SDL, log;

type
  TInput = class(TObject)
  public
     keyup, keydown, keyleft, keyright, keyenter, keyback : boolean; //are these keys held down
     alpha : boolean; //was an alphanumeric key pressed this time
     backspace : boolean; // was backspace key pressed this time
     alphakeypressed : boolean; //is there an alphanumeric key HELD DOWN
     lastchar : char; //the last character that was pressed
     keypresstime : LongWord; //time the last key was pressed
//     chattext : string;
    quit : boolean;
	procedure updatekeys();
  end;

implementation
  
procedure Tinput.updatekeys();
var 
event:TSDL_EVENT;
begin
   quit := false;
   alpha := false;
   backspace := false;

   while SDL_PollEvent(@event) = 1 do          //check events(key down, mouse move etc)
   begin
       case event.type_ of
          SDL_KEYDOWN:
             begin
                keypresstime := SDL_GetTicks;
                case event.key.keysym.sym of			//ok key pressed - find out which key
                   SDLK_LEFT: keyleft := true;
                   SDLK_RIGHT: keyright := true;
                   SDLK_UP: keyup := true;
                   SDLK_DOWN: keydown := true;
                   SDLK_a..SDLK_z, SDLK_0..SDLK_9:
                      if (event.key.keysym.unicode and $ff80) = 0 then //if highest 9bits are 0 then it can be mapped to ascii
                      begin
                         lastchar := char (event.key.keysym.unicode and $7f);
                         alpha := true;
                         alphakeypressed := true;
                      end;
                   SDLK_space:
                      begin
                         lastchar := ' ';
                         alpha := true;
                         alphakeypressed := true;
                      end;
                   SDLK_backspace:
                      begin
                         keyback := true;
                         backspace := true;
                      end;
                   SDLK_RETURN: keyenter := true;
                end;
             end;

          SDL_KEYUP:
             begin
                case event.key.keysym.sym of			//key let up - find out which key
                   SDLK_LEFT: keyleft := false;
                   SDLK_RIGHT: keyright := false;
                   SDLK_UP: keyup := false;
                   SDLK_DOWN: keydown := false;
                   SDLK_backspace: keyback := false;
                   SDLK_RETURN : keyenter := false;
                   SDLK_a..SDLK_z, SDLK_0..SDLK_9 : alphakeypressed := false;
                   SDLK_space : alphakeypressed := false;
                end;
             end;

          SDL_QUITEV: quit := true; //(x in corner is clicked)
      end;
   end;
end;
end.
