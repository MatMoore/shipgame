unit ShipObjects;

{$mode objfpc}{$H+}

interface

uses math, WorldObjects, GraphicsClass, Constants, TradeObjects, log;

type
   shipdata = Record
    id : integer;
    x : integer;
    y : integer;
    h : Word;
    s_x : single;
    s_y : single;
    status : byte;
    time : LongWord;
  end;
  
   Pshipdata = ^shipdata;
   Ashipdata = array of shipdata;
  
  //upgradable ship parts:
  
  weapon = Record
     name : String; //what its called on the upgrade menu
     shoottime : double; //time in seconds it takes to 'reload' after firing the weapon
     number : integer; //number of bullets fired at once
     bulletspeed : double;
     bulletmomentum : double;
     energy : double; //fuel consumed each time you fire
  end;
  
  shield = Record
     name : String;
     damagereduction : integer; //percentage of damage done to your ship (default 100) 
  end;
  
  thrusters = Record
     name : String;
     strength : integer; //force per unit of fuel
     burnrate : double; //rate of fuel consumption
     nitroburnrate : double;
  end;
  
  radar = Record
     name : String;
     scale : integer;
     showships : boolean;
     showsize : boolean;
     showstealthed : boolean;
  end;
  
  solarpanel = Record
     name : String;
     coverage : integer; //perecentages
     efficiency : integer;
  end;
  
  computer = Record
     name : String;
     map : boolean;
     highlightbounty : boolean;
     autopilot : boolean;
  end;        
  
  transmitter = Record
     name : String;
     distance : integer; //how far messages travel
  end;
  
  shipdesign = Record
     weapon1 : weapon;
     weapon2 : weapon;
     shield1 : shield;
     fwdthruster : thrusters;
     backthruster : thrusters;
     panels1 : solarpanel;
     computer1 : computer;
     radar1 : radar;
     transmitter1 : transmitter;
     stealth : boolean;
  end;
  
  TShip = class(TObject)
  protected
    pos_x, pos_y : double;
    headingangle : double;
    speed_x, speed_y : double;
    graphicnum : integer;
    parts : shipdesign;
    cargo : tradeclass;
  public
    constructor create(p_x, p_y, h_ang, sp_x, sp_y : double; graphic : integer);                          //set constants
    procedure move(time : double); virtual;      //moves based on current track and speed
    procedure draw(camx, camy : double; graphics : TGraphics); virtual;       //determine if it needs drawing and if so then draw it in correct position(don't need this yet either)
    function get_x() : double;      //return x and y pos
    function get_y() : double;
    function get_s_x() : double;      //return x and y speed
    function get_s_y() : double;
    function get_heading() : Word;		//return heading as a word(smaller than an integer)
    function getGraphic : integer; //return the graphicnum
  end;

type
  TPlayerShip = class(TShip)
  protected
    burners : integer;
    rot_dir : integer;
    rot_speed : integer;
    fuel : double;
    maxfuel : integer;
	mass : integer;
    area : double; //how much surface area there is (determines how much light you can get with solar panels)
    volume : double; //how much space there is to store stuff
	thrusterstrength : integer;
  public
    constructor create(gnum : integer);                        //create - set constants
    procedure move(time : double); override;    //make changes
    procedure burnon(power : integer);         //turn on the burners at x power
    procedure rotate(rot_d : integer);         //-1 for left, 0 for none, +1 for right - all other values become 0
    procedure draw(graphics : TGraphics);     //player ship always gets drawn in center so we can save a bit of calculation
    procedure drawfuelbar(x, y : integer; graphics : TGraphics);
    procedure checkplanets(universe : TUniverse; time : double);
    function getRadarScale() : integer;
    procedure getdata(var data : shipdata);
end;

type
  TEnemyShip = class(TShip)
  protected
    username : string;
    id : integer; 		//unique player id
    time : LongWord;
  public
  constructor create(pid : integer; x, y : double; sx, sy, h : double; t : LongWord );
  procedure setvals(x, y : double; sx, sy, h : double; t : LongWord );			//set all the details about the ship
  function getid() : integer;
  function lastupdate() : LongWord;
  function getusername() : string;
end;

AEnemyShip = array of TEnemyShip;

implementation

Constructor TShip.create(p_x, p_y, h_ang, sp_x, sp_y : double; graphic : integer);
begin
	pos_x := p_x;
	pos_y := p_y;
	headingangle := h_ang;
	speed_x := sp_x;
	speed_y := sp_y;
	graphicnum := graphic;
end;

Procedure Tship.move(time : double);
begin
	pos_x := pos_x+speed_x*time;    //Update the X position based on the speed * time
	pos_y := pos_y+speed_y*time;	//same again for Y
	if pos_x > 2100000000 then pos_x := 2100000000;
	if pos_x < -2100000000 then pos_x := -2100000000;
	if pos_y > 2100000000 then pos_y := 2100000000;
	if pos_y < -2100000000 then pos_y := -2100000000;	
end;

Constructor TPlayerShip.create(gnum : integer);
begin
   inherited create(0,0,0,0,0,gnum);	//call the inherited create mthod(Tship.Create), setting position speed and heading to 0, and passing in the graphics number
	
   burners := 0;						//set everytihng to default values for now, later these should be editable because we'll have different ships.
   rot_dir := 0;
   rot_speed := 40;
   fuel := 50;
   maxfuel := 50;
   mass := 100;
   volume := 1000;
   area := 50;
   
   with parts.fwdthruster do
   begin
      name := 'test';
      strength := 10000;
      burnrate := 1;
      nitroburnrate := 2;
   end;
   
   with parts.panels1 do
   begin
      name := 'test';
      coverage := 100;
      efficiency := 100;
   end;
    
   parts.radar1.scale := 10000;
   //thrusterstrength := 10000; //10000 works
end;

Constructor TEnemyShip.create(pid : integer; x, y : double; sx, sy, h : double; t : LongWord);
begin
	id := pid;			//id is the online identifier of the player - every player has a unique one which will be given by the server
	pos_x := x;			//set the values as passed in
	pos_y := y;
	speed_x := sx;
	speed_y := sy;
	headingangle := h;
	time := t;
end;

Procedure TEnemyShip.setvals(x, y : double; sx, sy, h : double; t : LongWord);
begin
	pos_x := x;			//set the new values
	pos_y := y;
	speed_x := sx;
	speed_y := sy;
	headingangle := h;
	time := t;
end;

Function TEnemyShip.getid() : integer;
begin
	result := id;		//return id
end;

Function TEnemyShip.lastupdate() : LongWord;
begin
   result := time;
end;

Function TenemyShip.getusername() : string;
begin
	result := username;	//return username(
end;

Procedure TPlayerShip.move(time : double);
begin
	if rot_dir = 1 then headingangle := headingangle + rot_speed*time;		//if rotation is on then do the rotation WRT time
	if rot_dir = -1 then headingangle := headingangle - rot_speed*time;		//ditto
	
	while headingangle >= 360 do 											//return the heading angle within 0<=angle<360
		headingangle := headingangle - 360;
	while headingangle < 0 do 
		headingangle := headingangle + 360;
	
	if (burners > 0) and (fuel > 0) then begin
		speed_x := speed_x + sin(pi/180 * headingangle)*burners*(parts.fwdthruster.strength/(mass+fuel))*time;		//change the x and y speed based on the angle you are heading and WRT time
		speed_y := speed_y + cos(pi/180 * headingangle)*burners*(parts.fwdthruster.strength/(mass+fuel))*time;
		fuel := fuel - parts.fwdthruster.burnrate * burners * time;										//now reduce the fuel
	end;
	
	inherited move(time);													//call Tship.Move
end;

function TPlayerShip.getRadarScale() : integer;
begin
   result := parts.radar1.scale;
end;

Procedure TPlayerShip.burnon(power : integer);
begin
	burners := power;			//simply set the value that was passed in
end;

Procedure TPlayerShip.rotate(rot_d : integer);
begin
	rot_dir := rot_d;			//set rotation
end;

Procedure TPlayerShip.draw(graphics : TGraphics);
begin
    graphics.drawimage(graphicnum,GameWidth div 2,GameHeight div 2,round(headingangle), true);		//draw the image in center of screen( hard coded :/ )
end;

Procedure TPlayerShip.checkplanets(universe : TUniverse; time : double); //do stuff based on current positions of planets/stars
var
   d_s_x, d_s_y, lightflux : double;
   newfuel : integer;
begin
   universe.interact(pos_x, pos_y, d_s_x, d_s_y, lightflux); //this calculated d_s_x,d_s_y (acceleration due to gravity) and lightflux (light per unit area per unit time from stars)
   newfuel := round(lightflux * time * parts.panels1.coverage / 100 * parts.panels1.efficiency / 100 * area/2);
   if fuel+newfuel > maxfuel then
      fuel := maxfuel
   else
      fuel := fuel+newfuel;
   speed_x := speed_x + d_s_x * time;										//modify speed by acceleration WRT time
   speed_y := speed_y + d_s_y * time;
end;

procedure TShip.draw(camx, camy : double; graphics : TGraphics);
begin
	if (pos_x < camx + 1000) AND (pos_x > camx - 1000) AND (pos_y < camy + 1000) AND (pos_y > camy - 1000) then			//if its likely to be on the screen
		graphics.drawimage(graphicnum,round(pos_x-camx + gamewidth/2),round(camy - pos_y + gameheight/2),round(headingangle), true);		//draw it
end;

Procedure TPlayerShip.drawfuelbar(x, y : integer; graphics : TGraphics);
var
z : integer;
begin
z := 255 - round(255 * fuel / maxfuel);
graphics.drawrect(x,y+z,x+5,y+256,255,0,0);
//  im_list.Items[2].Draw(im_list.DXDraw.Surface,x,y,z)
end;

procedure TPlayerShip.getdata(var data : shipdata);
begin
   data.x := round(pos_x); //just send position for now
   data.y := round(pos_y);
   data.s_x := speed_x;
   data.s_y := speed_y;
   data.h := round(headingangle);
end;

Function TShip.get_x : double;			
begin
	result := pos_x;		//return x position
end;

Function TShip.get_y : double;
begin
	result := pos_y;		//return y position
end;

Function TShip.get_s_x : double;
begin
	result := speed_x;		//return x speed
end;

Function TShip.get_s_y : double;
begin	
	result := speed_y;		//return y speed
end;

Function TShip.get_heading : Word;
begin
	result := round(headingangle);	//return the heading as an int
end;

Function TShip.getGraphic : Integer;
begin
	result := graphicnum;
end;

end.
