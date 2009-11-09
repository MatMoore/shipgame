unit FontClass;
{$mode objfpc}{$H+}
interface

USES SDL, SDL_GFX, SDL_TTF, Constants, sysutils, log;


type
   CharData = record
      minx, miny, maxx, maxy, advance : integer
   end;


   TFont = class
      private
         images : array[font_low..font_high] of pSDL_Surface;
         info : array[font_low..font_high] of CharData;
         maxheight : integer;
      public
         constructor create(fontname : pChar; r, g, b, size : integer);
         destructor destroy(); override;
         procedure writetext(text : string; surface : pSDL_Surface; x, y : integer; center : boolean = false);
         function getwidth(text : string) : integer;                                                              //returns the pixel width of a string if it was printed
         procedure writetextwrap(text : string; surface : pSDL_Surface; x, y, width : integer; center : boolean = false);           //not implemented yet
   end;

implementation

constructor TFont.create(fontname : pChar; r, g, b, size : integer);
var 
   i : integer;
   font : pTTF_font;
   textColor : pSDL_color;
   height : integer;
begin
   
   new(textColor);
   textColor^.r := r;
   textColor^.g := g;
   textColor^.b := b;
   font := TTF_OpenFont(fontname, size);
   maxheight := 0;
   for i := font_low to font_high do begin
      images[i] := TTF_RenderGlyph_Solid( font, i, textColor^ );                                            //RenderGlyph_Solid should render it solidly with a transparent background
      TTF_GlyphMetrics(font, i, info[i].minx, info[i].maxx, info[i].miny, info[i].maxy, info[i].advance);   //store the data
      height := info[i].maxy - info[i].miny;
      if height > maxheight then maxheight := height;       //we could use TTF_FontHeight here to get the maxheight, however, since we are not necessarily using all the characters, it makes sense to get the ACTUAL max height like this
   end;
   
   TTF_CloseFont(font);
end;

destructor TFont.destroy();
var i : integer;
begin
   for i := font_low to font_high do
      SDL_FREESURFACE(images[i]);            //free up all the surfaces used
end;

function TFont.getwidth(text : string) : integer;
var i,a : integer;
begin
   result := 0;
   for i := 1 to length(text) do begin  //loop through each letter
      a := ord(text[i]);   //get the ascii value of the current letter
      result := result + info[a].advance;
   end;
end;
        
        
procedure TFont.writetext(text : string; surface : pSDL_Surface; x, y : integer; center : boolean = false); 
var 
i, current_x, current_y, a, width : integer;
offset : SDL_rect;
begin
   current_x := x;
   current_y := y;
   width := 0;
   
   if center then begin
   
      width := getwidth(text);
      
      current_x := current_x + round((surface^.w-current_x) / 2)-round(width / 2);
   end;
   
   for i := 1 to length(text) do begin  //loop through each letter
      a := ord(text[i]);   //get the ascii value of the current letter
      offset.x := current_x;
      offset.y := current_y+maxheight - (info[a].maxy);     //calculate the x,y position for that letter
      SDL_BLITSURFACE(images[a],NIL,surface,@offset); //blit onto surface
      current_x := current_x + info[a].advance;
   end;
end;

procedure TFont.writetextwrap(text : string; surface : pSDL_Surface; x, y, width : integer; center : boolean = false); 
var 
i, lastspace : integer;
line, line2 : string;
begin
   line := '';
   lastspace := -1;
   for i := 1 to length(text) do begin
      line := line + text[i];                   //add the character to linel
      if text[i] = ' ' then lastspace := length(line);      //always store the position of the last space in line, so that we can easily go back to it
      if getwidth(line) > width then begin     //if the current line is wider than we want

         if lastspace <> -1 then begin                         //there is a space in it, so we want to wrap at that space
            line2 := rightstr(line, length(line)-lastspace);   // copy the last bit of word (everything after the last space) into line2;
            line := leftstr(line, lastspace-1);                //delete everything before the lastspace
         end else begin                                             //no space - wrap in middle of word (copy the last letter into line2)
            line2 := rightstr(line, 1);
            line := leftstr(line, length(line)-1);          
         end;
         writetext(line, surface, x, y, center);
         line := line2;                                  //move whatever was lopped off line back into the start of line
         line2 := '';                                    
         lastspace := -1;                             
         y := y + maxheight;                           //go down a line       
      end;

   end;
end;

end.
