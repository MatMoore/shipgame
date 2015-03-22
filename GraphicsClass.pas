unit GraphicsClass;
{$mode objfpc}{$H+}

INTERFACE

USES SDL, SDL_GFX, Constants, log;

type
    TRotImage = class(TObject)
    private
        image : array[0..359] of pSDL_Surface;											//array of images 0 to 359 gives the angle
        rot : boolean;																	//whether or not the image has been rotated(if false then only images[0] is filled)
    public
        constructor create(filename : string; needsrot, transparent : boolean); overload;		  //loads in the image, checks if it needs rotation, if it does then performs 359 rotations to fill the rest of the array, then checks for transparency, if so then sets transparency to the first pixel of the image
        constructor create(tempimage : pSDL_surface; needsrot, transparent : boolean); overload;  //another constructor so we can make em from surfaces
		  destructor destroy(); override;													//free memory
        function getimage(angle : integer) : pSDL_Surface;								//pull out the image at a particular angle(unless its got rot=false, in which case it just returns image[0])
end;


type
    Tgraphics = class(TObject)
    private
       images : array of TRotImage;
       textures : array of pSDL_Surface;
       screen : pSDL_SURFACE;
    public
        function addimage(filename : string; needsrot, transparent : boolean) : integer; 	//Creates a new TRoyImage and returns the ID of the image
        function addtexture(filename : string; transparent : boolean) : integer; //this just adds to the texture array
        constructor create(scr : pSDL_Surface);												//saves the location of the screen buffer for drawing to later, so i dont always have to pass that around
        procedure drawimage(id, x, y, angle : integer; center : boolean);					//draws the image id (i.e images[id]) at x,y on the screen, at the given angle. if center is true then the x,y is at the center of the image, otherwise x,y is at the top left
        procedure drawrect(x1,y1,x2,y2,r,g,b : integer);                            //draws a rectangle
        procedure drawcircle(x,y,radius,r,g,b : integer);                            //draws a rectangle
        function MakeTexturedCircle(textureid,radius : integer) : integer; //returns integer to the id of the new image (position in array)
        function circlesCollide(ano,bno,ax,ay,bx,by : integer) : boolean;
//        procedure writeText(msg : pChar; surface : pSDL_surface; x, y, red, green, blue, size : integer; center : boolean);    //this is now in a seperate font class
        destructor destroy(); override;														//free memory;
end;

implementation

constructor TRotImage.create(filename : string; needsrot, transparent : boolean);
var
   tempimage : pSDL_SURFACE;
begin
    tempimage := SDL_LOADBMP(PCHAR(filename));
    if tempimage <> nil then //make sure its loaded properly
    begin
       create(tempimage, needsrot, transparent);
    end;
end;

constructor TRotImage.create(tempimage : pSDL_surface; needsrot,transparent : boolean);
var 
i, t : integer;
tempimage2 : pSDL_SURFACE;
begin
   tempimage2 := SDL_DisplayFormat( tempimage ); //convert it to the correct format for the sdl display(32bit, rather than 24bit bitmap)
   SDL_freesurface(tempimage);    //clear up that memory
   Image[0] := tempimage2;
   if transparent then
      SDL_SetColorKey(Image[0], SDL_SRCCOLORKEY,PUint32(Image[0]^.pixels)^);		//this sets transparency to the first pixel of the image
   rot := needsrot;               //save whether we're going to rotate it or not
   if rot = true then
   begin
      t := 359;
      for i := 1 to 359 do
      begin
         image[i] := rotozoomsurface( image[0], t, 1, 1);     //rotate the image by t degrees and store for all 359 other degrees
	     if transparent then
			SDL_SetColorKey(Image[i], SDL_SRCCOLORKEY,PUint32(Image[i]^.pixels)^);	//set transparency as above
		 t := t - 1;											//for some reason sdl rotates in an anticlockwise way, so t counts down from 359 in order that the rotation goes clockwise
	  end;
   end;
end;

function TRotImage.getimage(angle : integer=0) : pSDL_Surface;
begin
    if rot = true then begin           //if this image was loaded and rotated then give the angle
        while angle > 359 do		   //bring the angle back into the range of 0<=angle<360 in case its not
            angle := angle - 360;
        while angle < 0 do
            angle := angle + 360;

        result := image[angle];			//simply return a reference to the image
    end
    else
        result := image[0];				//if no rotation then return the first image no matter what angle is requested
end;

destructor TRotImage.destroy();
var i : integer;
begin

    for i := 0 to 359 do
        SDL_FREESURFACE(image[i]);		//clear all the images

end;

function Tgraphics.addimage(filename : string; needsrot, transparent : boolean) : integer;
begin
    setlength(images, length(images)+1);											//increase length of images array by one
    images[length(images)-1] := TRotImage.create(filename, needsrot, transparent);	//create a new image in the new position of the array
    result := length(images)-1;														//return the id of that array
end;

function Tgraphics.addtexture(filename : string; transparent : boolean) : integer;
var
   tempimage : pSDL_SURFACE;
begin
   setlength(textures, length(textures)+1); //increase size of array
   tempimage := SDL_LOADBMP(PCHAR(filename)); //load file
   if tempimage <> nil then
   begin
      textures[length(textures)-1] := SDL_DisplayFormat( tempimage ); //convert it to the correct format for the sdl display(32bit, rather than 24bit bitmap)
	  SDL_freesurface(tempimage); //clear up that memory
	  if transparent then
         SDL_SetColorKey(textures[length(textures)-1], SDL_SRCCOLORKEY,PUint32(textures[length(textures)-1]^.pixels)^); //set transparency to the first pixel of the image
   end;
   result := length(textures)-1; //return id
end;

constructor Tgraphics.create(scr : pSDL_Surface);
begin
	screen := scr;																	//save this for easy drawing to later
end;

procedure Tgraphics.drawimage(id,x,y,angle : integer; center : boolean);
var temp : pSDL_Surface;
offset : SDL_Rect;
begin
    temp := images[id].getimage(angle);												//temp is just a pointer to the image, its not really needed but just saves us repeating images[id].getangle(angle) lots
    if center=true then begin
       offset.x := x - round(temp^.w / 2);											//moves the x and y up and left by half the image in order to put the picture in the center
		offset.y := y - round(temp^.h / 2);
    end else begin
		offset.x := x;																//uses the given x and y(i.e the top left of image)
		offset.y := y;
    end;

    SDL_BLITSURFACE(temp,NIL,screen,@offset);										//put the image onto the screen buffer
end;

procedure Tgraphics.drawrect(x1,y1,x2,y2,r,g,b : integer);
begin
    boxRGBA(screen,x1,y1,x2,y2,r,g,b,255);
end;

procedure Tgraphics.drawcircle(x,y,radius,r,g,b : integer);
begin
   filledCircleRGBA(screen,x,y,radius,r,g,b,255);
end;

function TGraphics.MakeTexturedCircle(textureid,radius : integer) : integer;
var
   temp1,temp2,temp3,texture : pSDL_surface;
   offset : SDL_rect;
   transparent : UInt32;
begin
   //make some SDL_surfaces
   temp1 := SDL_CreateRGBSurface(SDL_SWSURFACE, 2*radius+1, 2*radius+1, 32, $FF000000, $00FF0000, $0000FF00, $000000FF);
   temp2 := SDL_CreateRGBSurface(SDL_SWSURFACE, 2*radius+1, 2*radius+1, 32, $FF000000, $00FF0000, $0000FF00, $000000FF);
   
   //get texture
   texture := textures[textureid];
   
   //create magenta background for temp1 (this will be set to transparent later)
   boxRGBA(temp1,0,0,2*radius,2*radius,255,0,255,255);

   //add texture to temp1
   offset.x := 0;
   repeat
   begin
      offset.y := 0;
      repeat
      begin
         SDL_BlitSurface(texture, nil, temp1, @offset); //copy all of texture to temp1 at offset
         offset.y := offset.y + texture^.h;
      end
      until offset.y>2*radius;
      offset.x := offset.x + texture^.w;
   end
   until offset.x>2*radius;
   
   //create magenta background for temp2 (this will be set to transparent later)
   boxRGBA(temp2,0,0,2*radius,2*radius,255,0,255,255);
   
   //create white circle on background
   filledCircleRGBA(temp2,radius,radius,radius,255,255,255,255);
   temp3 := SDL_Displayformat(temp2);
   SDL_FREESURFACE(temp2);
   //set white to transparent
   transparent := SDL_MapRGB(temp3^.format, 255, 255, 255);
   SDL_SetColorKey(temp3, SDL_SRCCOLORKEY, transparent);
      
   //blit circle onto textured background
   SDL_BlitSurface(temp3, nil, temp1, nil);
   SDL_freesurface(temp3); //free memory
   
   //store image
   setlength(images, length(images)+1); //make room for it
   images[length(images)-1] := TRotImage.create(temp1, false, true); //Make TRotImage from it and store in array
   result:= length(images)-1; //return a reference to the image
end;

//assume surfaces are circular and see if they collide
function Tgraphics.circlesCollide(ano,bno,ax,ay,bx,by : integer) : boolean;
var
   ra,rb,d : double;
   ar,br : TRotImage;
   a,b : pSDL_surface;
begin
   ar := images[ano]; //TRotimages
   br := images[bno];
   a := ar.image[0]; //rotation doesnt matter, so just use the first one
   b := br.image[0];
   
   ra := a^.w/2; //radii
   rb := b^.w/2;
   if a^.h/2 > ra then
      ra := a^.h/2;
   if b^.h/2 > rb then
      rb := b^.h/2;
   
   d := sqrt(abs((ax-bx) * (ax-bx) + (ay-by) * (ay-by))); //calculate the seperation
   
   if d<=(ra+rb) then
      result := true
   else
      result := false;
end;


destructor Tgraphics.destroy();
var i : integer;
begin
    for i := 0 to length(images)-1 do
        freeandnil(images[i]);														//free the memory for all the images
    for i := 0 to length(textures)-1 do
      SDL_FREESURFACE(textures[i]);
end;

end.
