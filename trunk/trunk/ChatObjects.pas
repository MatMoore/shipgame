unit ChatObjects;

{$mode objfpc}{$H+}

interface

uses SDL, GraphicsClass, FontClass, InputClass, Constants, NetworkClass, log;

const
   chatsize = 5;
   ChatWidth = GameWidth - 300;
   repeatTime = 50; //wait this many ms before repeating a char
   repeatStartTime = 500; //key must be held down this long before it starts to repeat
   chatxpos = 10; //how far from left edge
   chatypos = 10; //how far from bottom edge
   ChatboxInputHeight = 15; //how high the box you type into is

type
   TChatBox = class(TObject)
   private
      images : array[0..chatsize] of pSDL_surface;
      usermsg : String; //the message the user is typing
      typewriter : TFont;
      lastchar : char; //last character typed
      lastrepeat : LongWord; //when it was typed
   public
      constructor create(f : TFont);
      procedure receiveMsg(msg : string);
      procedure updateUserMsg(input : TInput; network : TNetwork); //checks to see which keys have been typed and adds them to usermsg. if enter is pressed then generate a surface, clear usermsg before continuing
      procedure draw(screen : pSDL_surface);
   end;
   
implementation

constructor TChatBox.create(f : TFont);
begin
   typewriter := f;
end;

procedure TChatBox.receiveMsg(msg : string);
var
   i : integer;
   height : integer;
begin
   if images[chatsize-1] <> nil then
      SDL_FREESURFACE(images[chatsize-1]); //remove the oldest message (if there is one)
   for i := chatsize-2 downto 0 do
   begin
      if images[i] <> nil then
         images[i+1] := images[i] //move each one to the right
   end;
      
   //put the new one at the beginning
   height := 20; //calculate this from fontclass
   images[0] := SDL_CreateRGBSurface(SDL_SWSURFACE, ChatWidth, height, 32, $FF000000, $00FF0000, $0000FF00, $000000FF); //make new surface
   Typewriter.writetext(msg,images[0], 0, 0, false); 
end;

procedure TChatBox.updateUserMsg(input : TInput; network : TNetwork);
var
   netmsg : NetworkMessage;
begin
   //check which key has been pressed from input class  
   //add to string if
   //1. a new key has been pressed
   //2. key has been held down for repeatStartTime and the last one was typed more than repeatTime ago
   if (input.alpha or ((input.alphakeypressed) and (lastchar = input.lastchar) and ((input.keypresstime + repeatStartTime) < SDL_GetTicks) and ((lastRepeat + repeatTime) < SDL_GetTicks))) then
   begin
      lastRepeat := SDL_GetTicks;
      usermsg := usermsg + input.lastchar;
      lastchar := input.lastchar;
   end;
   
   //if backspace has been pressed delete the last character
   if (input.backspace or (input.keyback and ((input.keypresstime + repeatStartTime) < SDL_GetTicks) and ((lastRepeat + repeatTime) < SDL_GetTicks))) then
   begin
      lastRepeat := SDL_GetTicks;
      if length(usermsg) > 0 then setlength(usermsg, length(usermsg)-1);
   end;
   
   //if enter has been pressed then convert it to an image, add to array and send to other players
   if(input.keyenter and (length(usermsg) > 0)) then
   begin
      receiveMsg(usermsg);
      netmsg.command := 'c';
      netmsg.data := usermsg;
//      network.sendtcpdata(netmsg);
      usermsg := '';
   end;
end;

procedure TChatBox.draw(screen : pSDL_surface);
var
   userimg : pSDL_surface;
   offset : SDL_Rect;
   i : integer;
   x,y : integer;
   height : integer; //height of the message
begin
   x := Chatxpos;
   y := GameHeight-Chatypos;
   
   y := y-ChatboxInputHeight; //add space for the text box
   
   if length(usermsg) > 0 then
   begin
      //make an image from the player's text
      userimg := SDL_CreateRGBSurface(SDL_SWSURFACE, ChatWidth, ChatBoxInputHeight, 32, $FF000000, $00FF0000, $0000FF00, $000000FF); //make new surface
      Typewriter.writetext(usermsg,userimg, 0, 0, false);
      
      //blit the image to the screen
      offset.x := x;
      offset.y := y;
      SDL_BLITSURFACE(userimg,NIL,screen,@offset);
      
      //free memory
      SDL_FREESURFACE(userimg);
   end;
   
   //blit all the messages to the screen
   for i := 0 to length(images)-1 do
   begin
      if images[i] <> nil then
      begin
         y := y - images[i]^.h; //draw it directly above the last one
         offset.x := x;
         offset.y := y;   
         SDL_BLITSURFACE(images[i],NIL,screen,@offset);
      end;
   end;
end;
   
end.
