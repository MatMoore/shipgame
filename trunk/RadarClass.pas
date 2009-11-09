unit RadarClass;
{$mode objfpc}{$H+}
interface

uses ShipObjects, WorldObjects, GraphicsClass, Constants, log;

type
  TRadar = class(TObject)
  public
	procedure DrawRadar(player : TPlayerShip; World : TUniverse; Graphics : TGraphics; Enemies : AEnemyShip; x,y,radius : integer);
end;

implementation

procedure TRadar.DrawRadar(player : TPlayerShip; World : TUniverse; Graphics : TGraphics; Enemies : AEnemyShip; x,y,radius : integer);
var 
i, hs, xloc, yloc, scale : integer;
p : TPlanet;
begin
   scale := player.getRadarScale;
	
	graphics.drawcircle(x,y,radius+1,255,0,0);     //outline
	graphics.drawcircle(x,y,radius,0,0,0);          //inner circle
	
	//draw planets onto radar
	for i := 0 to World.numplanets-1 do begin
	   p := world.getplanet(i);
	   if p.getdistance(player.get_x,player.get_y) < scale then begin
	      xloc := 0-round((player.get_x - p.getx) / (scale/radius)) + x;
  	      yloc := round((player.get_y - p.gety) / (scale/radius)) + y;
  	      if p.getradius < 500 then hs := 1 else hs := 2;
  	      graphics.drawcircle(xloc,yloc,hs,255,255,255);
	   end;
	end;
    

   //draw suns onto radar
   for i := 0 to World.numsuns-1 do begin
	   p := world.getsun(i);
	   if p.getdistance(player.get_x,player.get_y) < scale then begin
	      xloc := 0-round((player.get_x - p.getx) / (scale/radius)) + x;
  	      yloc := round((player.get_y - p.gety) / (scale/radius)) + y;
  	      if p.getradius < 500 then hs := 1 else hs := 2;
  	      graphics.drawcircle(xloc,yloc,hs,255,255,255);
	   end;
	end;
	
	//draw enemy ships onto radar
   for i := 0 to length(Enemies)-1 do
      if sqrt(((player.get_x - Enemies[i].get_x)*(player.get_x - Enemies[i].get_x)) + ((player.get_y - Enemies[i].get_y)*(player.get_y - Enemies[i].get_y))) < scale then begin
	      xloc := 0-round((player.get_x - Enemies[i].get_x) / (scale/radius)) + x;
	      yloc := round((player.get_y - Enemies[i].get_y) / (scale/radius)) + y;
      	graphics.drawcircle(xloc,yloc,1,255,0,0);      
      end;
      
	graphics.drawcircle(x,y,1,255,255,0);     //draw yellow player in center
end;

end.
