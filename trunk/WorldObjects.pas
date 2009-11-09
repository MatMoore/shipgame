unit WorldObjects;
{$mode objfpc}{$H+}
interface

uses math, GraphicsClass, Constants, DOM, sysutils, XMLRead, log;

type
   cartesian = record
      x : real;
      y: real;
   end;
   polar = record
      r : real;
      theta: real;
   end;
   
   //planet, universe classes - each can contain planets
   //planets in universe are fixed wheras the others will orbit the planet that holds them   
   TPlanet = class(TObject)
   private
      Radius, graphicnum, dir, Gravity : integer;
      parent : TPlanet;
      fixed : boolean; //must be false if there is no parent
      pos_x, pos_y, SMA, ecc, angle : double; //x,y positions are determined by the parent object before the planet is drawn. these are relative to universe
                                          //a,e describe the orbit: a=semimajor axis b=eccentricity
                                          //angle is the angle of the semimajor axis wrt horizontal.
                                          //i.e. zero value makes a horizontal ellipse
   public
      constructor create(posx, posy: double; rad, gnum, grav : integer);
      procedure addParent(p : TPlanet; e : real; direction : integer);
      procedure orbitCentre(p : TPlanet; e : real; direction : integer); //for binary systems
      function getdistance(posx, posy : double) : double;
      function getgrav() : integer;
      procedure interact(shipx, shipy : double; var delta_speed_x, delta_speed_y, lightflux : double);
      function getx() : double;
      function gety() : double;
      procedure setx(x : double);
      procedure sety(y : double);
      function getSMA : real;
      function getECC : real;
      function getgnum() : integer;
      function getradius() : integer;
      function isFixed() : boolean;
      procedure moveplanet(time : double);
      function meananomaly(time,T : real) : real;
      function period(m,a : real) : real;
      function eccentricanomaly(MA,e : real) : real;
      function trueanomaly(e,EA : real) : real;
      function distance(a,e,theta : real) : real;
      function pol2cart(p : polar) : cartesian;
      function getGraphic : Integer;
      function getParent : TPlanet;
   end;
   
   TSun = class(TPlanet)
   private
      brightness : double;
      temperature : integer;
   public
      constructor create(posx, posy, bright: double; rad, gnum, grav, temp : integer);
      procedure interact(shipx, shipy : double; var delta_speed_x, delta_speed_y, lightflux : double);
   end;
      
   TUniverse = class(TObject)
   public
      constructor create(filename: String; photoAlbum : TGraphics);
      function makePlanet(node,map : TDOMNode; photoAlbum : TGraphics) : TPlanet;
      function makePlanet(node,map : TDOMNode; photoAlbum : TGraphics; sun: TPlanet; ecc : real; dir : string) : TPlanet;
      function getplanet(num : integer) : TPlanet;
      function numplanets() : integer;
      function getsun(num : integer) : TSun;
      function numsuns() : integer;
      function addplanet(posx, posy : double; rad, gnum, grav : integer) : TPlanet;
      function addsun(posx, posy, bright : double; rad, gnum, grav, temp : integer) : TPlanet;
      function interact(posx, posy : double; var delta_speed_x, delta_speed_y, lightflux : double) : boolean; //determine which of the planets is closest to the posx/posy. Returns 1 if something found within 100000
      procedure drawobjects(camx, camy : double; graphics : TGraphics);
      procedure moveplanets(time : double);
      function checkcollision(graphics:TGraphics; x,y,ship : integer) : boolean;
   private
      planets : array of TPlanet;
      suns : array of TSun; //I think these need to be seperate from planets cause otherwise they get converted to planets and the new interact function doesnt work :(
      width : integer;
      height: integer;
      
      //these should both be the same length but it isn't checked anywhere at all!
      filenames : array of String; //stores the filenames for the images which have been added already
      images : array of integer; //stores the ids for images which have been added
   end;

implementation

//things which need to be fixed:
//right now it creates the planets in a recursive way which wont work for binary systems
//need to add suns/space stations as well but theres not much point atm cause the map editor doesn't have features for them yet

constructor TUniverse.create(filename: String; photoAlbum : TGraphics); //parse the xml file and produce the map
var
   document : TXMLDocument;
   node,orbitNode : TDOMNode;
   namedNodeMap : TDOMNamedNodeMap;
   i: integer;
   id: integer;
begin
   ReadXMLFile(document, filename);
   
   //how big should it be?
   //let us now see
   //by checking the attributes
   //very carefully
   namedNodeMap := document.documentElement.attributes;
   with namedNodeMap do
   begin
      try
         width:= StrToInt(GetNamedItem('width').nodeValue);
         height:= StrToInt(GetNamedItem('height').nodeValue);
      except
         dolog('Error: Map file does not specify width and height.');
      end;
      free;
   end;
   
   //now for planets and stuff
   //we should have enough
   //if we add all of these
   //but it will be tough
   node := document.documentElement.firstChild;
   while assigned(node) do
   begin
      orbitNode := node.findNode('orbit');
      if not assigned(orbitNode) then //if its not orbiting anything
      begin
         dolog('Adding a fixed planet...');
         makePlanet(node,document.documentElement,photoAlbum);
      end;
      node := node.nextSibling;
   end;
end;

function TUniverse.makePlanet(node,map : TDOMNode; photoAlbum : TGraphics) : TPlanet;
var
   a : TDOMNamedNodeMap;
   imageNode,orbitNode,node2,sun : TDomNode;
   x,y,r,m,id,i,imageid, resizedImage : integer;
   objectType : string;
   filename,style : string;
   planet2 : TPlanet;
   ecc : real;
   dir : string;

begin
   try
      begin
         //get attributes
         a := node.attributes;
         with a do
         begin
            id := StrToInt(GetNamedItem('id').nodeValue);
            x := StrToInt(GetNamedItem('x').nodeValue);
            y := StrToInt(GetNamedItem('y').nodeValue);
            r := StrToInt(GetNamedItem('radius').nodeValue);
            m := StrToInt(GetNamedItem('mass').nodeValue);
            objectType := GetNamedItem('type').nodeValue;
            free;
         end;
         
         //get image
         imageNode := node.findNode('image');
         style := imageNode.attributes.GetNamedItem('style').nodeValue;
         filename := imageNode.firstChild.nodeValue;
         
         if ansiCompareText(style,'stretched') = 0 then
         begin
            resizedImage := photoAlbum.addimage(filename, false, true);
            dolog('Added planet image '+inttostr(resizedImage));
         end
         else
         begin
            //check for existing texture with that filename
            imageid := -1;
            for i := 0 to length(filenames)-1 do
            begin
               if ansiCompareText(filenames[i],filename) = 0 then
               begin
                  imageid := images[i];
                  dolog('Using existing texture.');
                  break;
               end;
            end;
            
            //if no existing image, create a new one
            if imageid = -1 then
            begin
               dolog('Loading new texture...');
               imageid := photoAlbum.addTexture(filename, true);//add image
               setlength(filenames, length(filenames)+1); //increase size of array
               setlength(images, length(images)+1);
               filenames[length(filenames)-1] := filename;
               images[length(images)-1] := imageid;
            end;
            
            //use the texture to create an image of the right size
            dolog('Creating planet image from texture...');
            resizedImage := photoAlbum.MakeTexturedCircle(imageid,r);
         end;
      
         //add planet *always make it a planet for now*
         if (ansiCompareText(objectType, 'planet') = 0) or true then
            result := addplanet(x, y, r, resizedImage, m);
         //else add sun/space station etc
         dolog('Added planet.');
         
         //find planets which orbit this one
         node2 := map.firstChild;
         while assigned(node2) do
         begin
            orbitNode := node2.findNode('orbit');
            if assigned(orbitNode) then
            begin
               sun := orbitNode.attributes.GetNamedItem('object');
               if assigned(sun) then
               begin
                  if strToInt(sun.nodeValue) = id then
                  begin
                     dolog('Adding a planet which orbits this one...');
                     ecc := strToFloat(orbitNode.attributes.GetNamedItem('eccentricity').nodeValue);
                     dir := orbitNode.attributes.GetNamedItem('direction').nodeValue;
                     planet2 := makePlanet(node2,map,photoAlbum,result,ecc,dir); //make that planet (and all its moons)
                  end;
               end;
            end;
            node2 := node2.nextSibling;
         end;
      end;
   except
      dolog('Error: Problem reading planet data from map file.');
   end;
end;

function TUniverse.makePlanet(node,map: TDOMNode; photoAlbum : TGraphics; sun: TPlanet; ecc : real; dir : string) : TPlanet;
var
   planet : TPlanet;
begin
   planet := makePlanet(node,map,photoAlbum);
   //set up orbit
   //need to check for binary planets
   if ansiCompareText(dir,'clockwise') = 0 then
      planet.addParent(sun, ecc, -1)
   else
      planet.addParent(sun, ecc, 1);
 
end;       

function TUniverse.getplanet(num : integer) : TPlanet;
begin
if (num < length(planets)) and (num > -1) then result := planets[num] else result := nil;
end;

function TUniverse.numplanets() : integer;
begin
   result := length(planets);
end;

function TUniverse.getsun(num : integer) : TSun;
begin
if (num < length(suns)) and (num > -1) then result := suns[num] else result := nil;
end;

function TUniverse.numsuns() : integer;
begin
   result := length(suns);
end;

function TUniverse.checkcollision(graphics:TGraphics; x,y,ship : integer) : boolean;
var
   i : integer;
begin
   result := false;
   for i:=0 to length(planets)-1 do
   begin
      if graphics.circlesCollide(ship,planets[i].getgraphic,x,y,round(planets[i].getx),round(planets[i].gety)) then
      begin
         result := true;
         break;
      end;
   end;
   
   for i:=0 to length(suns)-1 do
   begin
      if graphics.circlesCollide(ship,suns[i].getgraphic,x,y,round(suns[i].getx),round(suns[i].gety)) then
      begin
         result := true;
         break;
      end;
   end;
end;
                                    
function TUniverse.addplanet(posx, posy : double; rad, gnum, grav : integer) : TPlanet;
var
   i : integer;
begin
   setlength(planets, length(planets)+1);
   i := length(planets)-1;
   planets[i] := TPlanet.create(posx,posy,rad,gnum,grav);
   result := planets[i]; //return a pointer to the planet
end;

function TUniverse.addsun(posx, posy, bright : double; rad, gnum, grav, temp : integer) : TPlanet;
var
   i : integer;
begin
   setlength(suns, length(suns)+1);
   i := length(suns)-1;
   suns[i] := TSun.create(posx,posy,bright,rad,gnum,grav,temp);
   result := suns[i]; //return a pointer to the planet
end;

function TUniverse.interact(posx, posy : double; var delta_speed_x, delta_speed_y, lightflux : double) : boolean;			//delta_speed_x & y are passed by reference, this means they can be changed and their changes will stay
var
i : integer;
begin
   delta_speed_x := 0;
   delta_speed_y := 0;
   lightflux := 0;
   if length(planets) > 0 then
   begin
      result := true;
	  for i := 0 to length(planets)-1 do
      begin
         planets[i].interact(posx,posy,delta_speed_x,delta_speed_y,lightflux);
      end;
      for i := 0 to length(suns)-1 do
      begin
         suns[i].interact(posx,posy,delta_speed_x,delta_speed_y,lightflux);
      end;
   end
   else
      result := false;
end;

procedure TUniverse.drawobjects(camx, camy : double; graphics : Tgraphics);
var i : integer;
begin
	if length(planets) > 0 then
       for i := 0 to length(planets)-1 do			//for each planet
       begin
			//is it (roughly) within the camera view?
			if (planets[i].getx < camx + 1000+planets[i].getRadius) AND (planets[i].getx > camx - 1000 - planets[i].getRadius) AND (planets[i].gety < camy + 1000 + planets[i].getRadius) AND (planets[i].gety > camy - 1000 - planets[i].getRadius) then
               graphics.drawimage(planets[i].getgnum,round(planets[i].getx-camx + GameWidth/2), round(camy - planets[i].gety + GameHeight/2),0, true); //draw the image
       end;
    
       for i := 0 to length(suns)-1 do			//for each planet
       begin
			//is it (roughly) within the camera view?
			if (suns[i].getx < camx + 1000+suns[i].getRadius) AND (suns[i].getx > camx - 1000 - suns[i].getRadius) AND (suns[i].gety < camy + 1000 + suns[i].getRadius) AND (suns[i].gety > camy - 1000 - suns[i].getRadius) then
               graphics.drawimage(suns[i].getgnum,round(suns[i].getx-camx + GameWidth/2), round(camy - suns[i].gety + GameHeight/2),0, true); //draw the image
       end;
end;

procedure TUniverse.moveplanets(time:double); //calls the moveplanet function for each planet (except for stuff that doesnt move)
var
   i:integer;
begin
   if length(planets) > 0 then
      for i := 0 to length(planets)-1 do
         if not planets[i].isFixed then
            planets[i].moveplanet(time);
   
   if length(suns) > 0 then
      for i := 0 to length(suns)-1 do
         if not suns[i].isFixed then
            suns[i].moveplanet(time);
end;

constructor TPlanet.create(posx, posy:double; rad, gnum, grav : integer);
begin
	Radius := rad;			//save radius
	graphicnum := gnum;		//save the graphics number - this is the id that you get back when you create a new image in the graphics class
	gravity := grav;		//gravity constant
	pos_x := posx;			//x position
	pos_y := posy;			//y position
    fixed := true;
end;

function TPlanet.isFixed : boolean;
begin
   result := fixed;
end;

procedure TPlanet.addParent(p : TPlanet; e : real; direction : integer);
var
   comx,comy : real;
begin
   parent := p;
   ecc := e;
   fixed := false;
   dir := direction; //1 = anticlockwise, -1 = clockwise
   //take posx,posy as coordinates of aphelion (farthest point in orbit)
   SMA :=  p.getdistance(pos_x,pos_y);                                              //changed to use the already defined getdistance function
   angle := arctan2((pos_y-p.gety)*(pos_y-p.gety),(pos_x-p.getx)*(pos_x-p.getx));   //changed this to use arctan2, because it encompasses the surrounding logic
   if pos_x<comx then angle += PI;
end;

procedure TPlanet.orbitCentre(p : TPlanet; e : real; direction : integer);
var
   comx,comy : real;
begin
   parent := p;
   ecc := e;
   fixed := false;
   dir := direction; //1 = anticlockwise, -1 = clockwise
   
   //calculate everything based on centre of mass
   //this needs cleaning up a bit, you have to call this for each planet atm
   //also this will only work if the binary planets aren't themselves orbiting something else
   comx := (p.getgrav*p.getx+Gravity*pos_x) / (p.getgrav+Gravity);
   comy := (p.getgrav*p.gety+Gravity*pos_y) / (p.getgrav+Gravity);
   SMA := getdistance(comx,comy);
   angle := arctan2((pos_y-comy)*(pos_y-comy),(pos_x-comx)*(pos_x-comx));   //changed this to use arctan2, because it encompasses the surrounding logic
                                                                               //if pos_x<comx then angle += PI; //TEMPORARY. the angle doesnt seem to be right - its 0 when it should be pi?
   if pos_x<comx then angle += pi; //something is probably wrong here. angle goes from 0 to 2pi, not -pi to pi
end;


function TPlanet.getdistance(posx, posy : double) : double;
begin
	result := sqrt(abs(posx-pos_x)*abs(posx-pos_x) + abs(posy-pos_y)*abs(posy-pos_y));			//returns the distance(via pythagorus) between the center of the planet and (posx,posy)
end;

function TPlanet.getgrav : integer;
begin
	result := gravity;					//return the basic gravity constant of the planet
end;

procedure TPlanet.interact(shipx, shipy : double; var delta_speed_x, delta_speed_y, lightflux : double); //delta_speed_x/y are passed by reference
begin
   //determine acceleration from the planet
   //total accn = unit vector * grav / r^2 = r_vector * grav / r^3
   delta_speed_x := delta_speed_x - (shipx - pos_x) * gravity/(getdistance(shipx,shipy)*getdistance(shipx,shipy)*getdistance(shipx,shipy));			//determine the accelleration in x
   delta_speed_y := delta_speed_y - (shipy - pos_y) * gravity/(getdistance(shipx,shipy)*getdistance(shipx,shipy)*getdistance(shipx,shipy));			//determine the accelleration in y
end;

function TPlanet.getx : double;
begin
	result := pos_x;					//return the x position							
end;

function TPlanet.gety : double;
begin
	result := pos_y;					//return the y position
end;

procedure TPlanet.setx(x : double);
begin
   pos_x := x;
end;

procedure TPlanet.sety(y: double);
begin
   pos_y := y;
end;

function TPlanet.getgnum : integer;
begin
	result := graphicnum;				//when you create it you should pass in a graphicsnumber.. this relates to which image in the graphics class it is
end;

function TPlanet.getradius : integer;
begin
	result := radius;					//return the radius of it(for calculating whether youve hit it or not)
end;

function TPlanet.getSMA : real;
begin
   result := SMA;
end;

function TPlanet.getEcc : real;
begin
   result:= ECC;
end;

function TPlanet.getParent : TPlanet;
begin
   result:=parent;
end;

//functions to calculate the position of a planet as a function of time.
//the planets orbits should obey Keplers 3 laws:
//1. the orbit of the planet follows an ellipse with the sun at one of the focii
//2. a line connecting the two will sweep out equal areas in equal times
//3. T^2 is proportional to a^3
//(for more info, see http://en.wikipedia.org/wiki/Keplers_laws)
function TPlanet.period(m,a : real) : real;
begin
   //   result := 2*pi*a*sqrt(a)/sqrt(m+parent.getgrav);          //m is set to parent.getgrav in the calling function - i think this is wrong
   if getgrav+parent.getgrav > 0 then
      result := 2*pi*a*sqrt(a)/sqrt(getgrav+parent.getgrav)     //it might be wrong, let me know, if its right then we can get rid of the m in the function def... also could the a's be replaced with AMS?
   else result := 0.0001; //CRAZY THINGS HAPPEN
end;

function TPlanet.meananomaly(time,T : real) : real;
begin
   result := dir*2*pi*time/T;
end;

function TPlanet.eccentricanomaly(MA,e : real) : real;
begin
   if e=0 then result := MA
   else
      result := MA + (e-1/8*e*e*e)*sin(MA) + 1/2*e*e*sin(2*MA) + 3/8*e*e*e*sin(3*MA); //this is an approximate solution of keplers equation: MA=EA-esinEA
end;
   
function TPlanet.trueanomaly(e,EA : real) : real;
begin
      result := 2*arctan(sqrt((1+e)/(1-e))*tan(EA/2));
end;

function TPlanet.distance(a,e,theta : real) : real;
begin
   result := a*(1-e*e) / (1+e*cos(theta));
end;

function TPlanet.pol2cart(p : polar) : cartesian;
var
   temp : cartesian;
begin
   temp.x := p.r*cos(p.theta+angle+pi); //theta is defined as the angle between the current position and the point of closest approach.
                                        //adding pi gives the angle from the farthest point in the orbit,
                                        //angle is the angle between the farthest point and "horizontal"
   temp.y := p.r*sin(p.theta+angle+pi);
   result:=temp;
end;

procedure TPlanet.moveplanet(time : double);
var
   T,MA,EA,m,comx,comy : real;
   pol : polar;
   cart: cartesian;
begin
   m := parent.getgrav;

   //calculate mean anomaly
   T := period(m,SMA); //period of orbit in seconds
   MA := meananomaly(time,T);
   //dolog(T);   
   //calculate eccentric anomaly
   EA := eccentricanomaly(MA,ECC);
   
   //calculate true anomaly, theta
   pol.theta := trueanomaly(ECC,EA);
   
   //calculate heliocentric distance, r
   pol.r := distance(SMA,ECC,pol.theta);
   
   //convert to cartesian coordinates
   cart := pol2cart(pol); //this is relative to the planet
   
   //if we have a binary system, get them to orbit the centre of mass 
   if parent.getParent = Self then
   begin
      //      dolog('binary system');
      if m+gravity > 0 then
      begin        
         comx := (m*parent.getx+Gravity*pos_x) / (m+Gravity);
         comy := (m*parent.gety+Gravity*pos_y) / (m+Gravity);
         pos_x := cart.x + comx;
         pos_y := cart.y + comy;
      end
      else
         dolog('binary planets must have mass');
   end
   else
   begin
      pos_x := cart.x + parent.getx; //relative to the universe
      pos_y := cart.y + parent.gety;
   end;
end;


function TPlanet.getGraphic : Integer;
begin
	result := graphicnum;
end;

constructor TSun.create(posx, posy, bright: double; rad, gnum, grav, temp : integer);
begin
   inherited create(posx, posy, rad, gnum, grav);
   brightness := bright;
   temperature := temp;
end;

procedure TSun.interact(shipx, shipy : double; var delta_speed_x, delta_speed_y, lightflux : double); //delta_speed_x/y are passed by reference
begin
   //determine acceleration from the sun
   //total accn = unit vector * grav / r^2 = r_vector * grav / r^3
   delta_speed_x := delta_speed_x - (shipx - pos_x) * gravity/(getdistance(shipx,shipy)*getdistance(shipx,shipy)*getdistance(shipx,shipy));			//determine the accelleration in x
   delta_speed_y := delta_speed_y - (shipy - pos_y) * gravity/(getdistance(shipx,shipy)*getdistance(shipx,shipy)*getdistance(shipx,shipy));			//determine the accelleration in y
   //determine 'light flux'
   lightflux := lightflux + brightness/(2*pi*getdistance(shipx,shipy)); //light is spread out on a circle with edge at ship position
end;

end.
