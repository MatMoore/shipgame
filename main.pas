program main;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, sysutils, SDL, SDL_Net, SDL_TTF, GraphicsClass, WorldObjects, ShipObjects, InputClass, MainGame, Constants, NetworkClass, log;


VAR
	screen:pSDL_SURFACE;
	graphics:TGraphics;
	gameControl : TGameController;
    networkControl : TNetwork;
	oldtime : Integer;
	inputdata : TInput;
   gamestate : integer=2;
   timepassed : double;
   ServerTime : integer;
   TimeOffset : integer;
   server : TIPaddress; //get this from menu
   playerid : integer; //get this after logging in



procedure initall();
var
   port : integer;
   time : integer;
begin
   //read command line arguments: ipaddress, port, username, password
   if ParamCount <> 4 then
   begin
      writeln('usage (for now): main serveraddress port(use 6666) username password (enter anything)');
      halt;
   end;

   SDL_INIT(SDL_INIT_VIDEO);
   SDL_EnableUNICODE(1); //allows us to get character codes for keyboard events (for chat)
   TTF_INIT();
   screen:=SDL_SETVIDEOMODE(GameWidth,GameHeight,32,SDL_SWSURFACE);
   IF screen=NIL THEN HALT;
   OldTime := SDL_GetTicks;
   InputData := TInput.create;
   graphics := TGraphics.create(screen);
      
   val(ParamStr(2),port); //convert to integer
   if SDLNet_ResolveHost(server,pchar(ParamStr(1)),port) = -1 then
   begin
      writeln('Cannot resolve ip address');
      gamestate := Gamestate_Quit;
   end;
   
   NetworkControl := TNetwork.create(server);
   playerid := NetworkControl.login(ParamStr(3),ParamStr(4),time);
   dolog('Player id = '+inttostr(playerid));
   gameControl := TGameController.create(graphics, screen, inputdata,NetworkControl, ParamStr(3));
   TimeOffset := time - SDL_GetTicks;
end;


procedure deinit();
begin
		freeandnil(gamecontrol);
        freeandnil(graphics);
        SDL_FREESURFACE(screen);
        SDL_QUIT;
end;



BEGIN
    initall;							//initialise all the objects
	
    while gamestate <> Gamestate_Quit do begin                 //main game loop
		
        timepassed := (SDL_GetTicks - OldTime) / 1000;   //this block gets the number of milliseconds since last loop, which is used to calculate the amount of movement for everything
        OldTime := SDL_GetTicks;						//later on, anything which performs movement or any function with respect to timeget passed timepassed which gives the time in seconds since the last frame

        ServerTime := SDL_GetTicks+TimeOffset;

		if gamestate = gameState_main then		
          gamestate := gameControl.run(timepassed,ServerTime, playerid);		//main game run.

        SDL_FLIP(screen);												//flip... now display everything we've drawn since the last flip
        SDL_Delay(1);				
		
    end;

    deinit;			//free up all the memory we've used
END.



