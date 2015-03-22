unit MainGame;
{$mode objfpc}{$H+}
interface

uses SDL, SDL_Net, GraphicsClass, WorldObjects, ShipObjects, InputClass, Constants, RadarClass, FontClass, NetworkClass, ChatObjects, math, log;

type
  TGameController = class(TObject)
  private
    username : string;
    Player : TPlayerShip;
    EnemyShips : AEnemyShip;        
    Universe : TUniverse;
    bg1,bg2,bg3 : integer;
    graphics : TGraphics;       //these are retrieved in create function - dont free these three
    screen : pSDL_Surface;
    Radar : TRadar;
    inputdata : TInput;
    LargeFont, SmallFont : TFont;
    NetworkThingy : TNetwork;
    NetSendAccumulator : double;
    ChatBox : TChatBox;
  public
    constructor create(graphics1 : TGraphics; screen1 : pSDL_Surface; inputData1 : TInput; network : TNetwork; user : string); //store references to some useful stuff so we can use the graphics and screen and stuff
    destructor destroy(); override;
    function run(timepassed : double; ServerTime : LongWord; playerid : integer) : integer; //returns new state
    function checkkeys() : integer;
    procedure draw();
    function getshippos(id : integer) : integer;
  end;

implementation

constructor TGameController.create(graphics1 : TGraphics; screen1 : pSDL_Surface; inputData1 : TInput; network : TNetwork; user : string);
var
   temp,temp2,temp3,temp4,temp5 : integer;
   p1,p2,p3 : TPlanet;
begin
    inputdata := inputData1;
    NetworkThingy := network;
    screen := screen1;
    username := user;
    graphics := graphics1;
    Player := TPlayerShip.create(graphics.addimage('./Data/ShipImages/0.bmp',true, true));              //create the player ship
    Universe := Tuniverse.Create('./Data/Maps/examples/solarsystem2.xml', graphics1);                                               //create the universe
    dolog('Created universe.');
    radar := TRadar.Create;
    dolog('Loading fonts...');
    LargeFont := TFont.create(BITSTREAM,255,255,255,Large_font_size);
    SmallFont := TFont.create(BITSTREAM,255,255,255,Small_font_size);
    ChatBox := TChatBox.create(SmallFont);
    dolog('Loading background images...');
    bg1 := graphics.addimage('./Data/backgroundimages/stars1.bmp', false, true);             //add the stars image
    bg2 := graphics.addimage('./Data/backgroundimages/stars2.bmp', false, true);             //add the stars image
    bg3 := graphics.addimage('./Data/backgroundimages/stars3.bmp', false, false);             //add the stars image
end;

function TGameController.checkkeys() : integer;
begin   
   InputData.updatekeys();
    
    if inputdata.keyleft then
        player.rotate(-1)                           //player.rotate doesnt rotate the ship immediately, it just sets a variable so that when we perform the move later
    else if inputdata.keyright then                         //we can rotate the ship with respect to time
        player.rotate(1)
    else player.rotate(0);

    if inputdata.keyup then
        player.burnon(1)                            //same thing with the burners - it just sets a variable.. the speed will be adjusted WRT time later in the player.move method
    else
        player.burnon(0);

    if inputdata.quit then
        result := Gamestate_Quit
    else
        result := Gamestate_main;
end;

procedure TGameController.draw();
var
offset_x, offset_y, loopx, loopy, i : integer;
begin


    //draw furthest back stars
    offset_x := ceil(player.get_x/4) mod 256;
    if offset_x < 0 then offset_x := offset_x + 256;
    offset_y := 256 - ceil(player.get_y/4) mod 256;
    if offset_y < 0 then offset_y := offset_y + 256;
    for loopy := 0 to ceil(GameHeight/256)+1 do
        for loopx := 0 to ceil(GameWidth/256)+1 do
            graphics.drawimage(bg3,loopx*256 - offset_x, loopy*256 - offset_y,0, false);
            
    //draw middle stars        
    offset_x := ceil(player.get_x/2) mod 256;
        if offset_x < 0 then offset_x := offset_x + 256;
    offset_y := 256 - ceil(player.get_y/2) mod 256;
        if offset_y < 0 then offset_y := offset_y + 256;
    for loopy := 0 to ceil(GameHeight/256)+1 do
        for loopx := 0 to ceil(GameWidth/256)+1 do
            graphics.drawimage(bg2,loopx*256 - offset_x, loopy*256 - offset_y,0, false);
    
    //draw front stars        
    offset_x := ceil(player.get_x) mod 256;
        if offset_x < 0 then offset_x := offset_x + 256;
    offset_y := 256 - ceil(player.get_y) mod 256;
        if offset_y < 0 then offset_y := offset_y + 256;
    for loopy := 0 to ceil(GameHeight/256)+1 do
        for loopx := 0 to ceil(GameWidth/256)+1 do
            graphics.drawimage(bg1,loopx*256 - offset_x, loopy*256 - offset_y,0, false);


    universe.drawobjects(player.get_x, player.get_y,graphics);      //make the universe draw the objects(pass in the player location so that we know which objects to draw and where on the screen)

    if length(EnemyShips) > 0 then                                  //length(enemyships) wont be more than 0 until we start working  on the networking.. but this goes through them and draws each of them.
        for i := 0 to length(EnemyShips)-1 do begin
            EnemyShips[i].draw(player.get_x, player.get_y,graphics);
        end;
    radar.DrawRadar(player,Universe,graphics,EnemyShips, GameWidth-105, GameHeight-105, 100);
    
    player.draw(graphics);                                          //draw the player in center of screen       
    player.drawfuelbar(5,5,graphics);                               //draw the fuel bar(not working yet)
    
    ChatBox.draw(screen); //draw the chat box
    
    if universe.checkcollision(graphics, round(player.get_x), round(player.get_y), player.getgraphic) then
    begin
       LargeFont.writeText('Crash', screen, 0,0, true);
       //insert code to make ship explode here
    end;
end;

//get the position of ship with id=id in the array of enemy ships. return -1 if not found
function TGameController.getshippos(id : integer) : integer;
var i : integer;
begin
   result := -1;
   for i := 0 to length(EnemyShips) -1 do
   begin
      if EnemyShips[i].getid = id then
      begin
         result := i;
         break;
      end;
   end;
end;
  
function TGameController.run(timepassed : double; ServerTime : LongWord; playerid : integer) : integer;
var
   i,pos : integer;
   data : ShipData;
   ships : AShipData;
   dt : double;
   t : double;
   msg : NetworkMessage;
begin
    if checkkeys() = Gamestate_Quit then begin
        dolog('Returning player to Earth.');
        result := Gamestate_Quit;
        exit;
    end;
    t := servertime / 1000; //convert to seconds
    universe.moveplanets(t);
    player.checkplanets(universe,timepassed);    //adjusts speed of player based on nearest planet
    player.move(timepassed);                     //performs the main movement for the player
    
    if length(EnemyShips) > 0 then                                  //length(enemyships) wont be more than 0 until we start working  on the networking.. but this goes through them and draws each of them.
       for i := 0 to length(EnemyShips)-1 do
    begin
          enemyships[i].move(timepassed);
          //check to see the last time we got data from them
        end;
    
    //Send Network Code
    NetSendAccumulator := NetSendAccumulator + timepassed;
    if NetSendAccumulator > 0.02 then begin         //max 50 times per second.. lower this for smoother sending
       NetSendAccumulator := 0;
       player.getdata(data); //get stuff to send to server
       data.id := playerid;
       data.time := ServerTime;
       NetworkThingy.sendship(data); //send to server
    end;

    
    //get ships back from server and update their values
    setlength(ships,0);
    NetworkThingy.receiveships(ships);
    
    if NetworkThingy.receivetcpdata(msg) then begin
       case msg.command of
         'c': Chatbox.receiveMsg(msg.data); //add message from other player to chatbox
       end;
    end;
    
    ChatBox.updateUserMsg(inputdata, NetworkThingy); //listen for user-entered chatbox messages
    
    for i := 0 to length(ships)-1 do
    begin
       pos := getshippos(ships[i].id);
       if pos = -1 then
       begin
          //the ship isn't in the array so make a new one
          setlength(EnemyShips,length(EnemyShips)+1);
          pos := length(EnemyShips)-1;
          EnemyShips[pos] := TEnemyShip.create(ships[i].id, ships[i].x, ships[i].y, ships[i].s_x, ships[i].s_y, ships[i].h, ships[i].time);
       end
       else
       begin
          //dolog(ships[i].idcode);
          //update existing ship if new time is greater than old time
          if (ships[i].time > EnemyShips[pos].lastupdate) OR ((ships[i].time < maxlag) AND (EnemyShips[pos].lastupdate > (4294967296-maxlag))) then //allow it if theyre within a second of the max/min values
          begin
             dt := (ServerTime - ships[i].time)/1000;
             ships[i].x := round(ships[i].x + ships[i].s_x * dt);
             ships[i].y := round(ships[i].y + ships[i].s_y * dt);
             EnemyShips[pos].setvals(ships[i].x,ships[i].y,ships[i].s_x,ships[i].s_y,ships[i].h, ships[i].time);
          end;
       end;
    end;
    
    draw();

    result := gamestate_main;   //keep state as game
end;

destructor TGameController.destroy();
var i : integer;
begin
    freeandnil(player);
    freeandnil(LargeFont);
    freeandnil(SmallFont);
    if length(EnemyShips) > 0 then                                  //length(enemyships) wont be more than 0 until we start working  on the networking.. but this goes through them and draws each of them.
        for i := 0 to length(EnemyShips)-1 do
            freeandnil(EnemyShips[i]);
    freeandnil(universe);
    freeandnil(inputdata);
    freeandnil(NetworkThingy);
end;

end.
