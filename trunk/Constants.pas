unit constants;
{$mode objfpc}{$H+}
interface

const
   GameWidth = 800;
   GameHeight = 600;
   
   Gamestate_Quit = -1;
   Gamestate_Connect = 0;
   Gamestate_Menu = 1;
   Gamestate_Main = 2;

   BITSTREAM = './fonts/VeraMono.ttf';
   font_low = 32;       //these describe which set of characters in the ascii(and extended ascii) set to use 32 = space, 126 = tilde
   font_high = 126;
   Large_font_size = 28;
   Small_font_size = 10;
   
//network stuff

   maxships = 10;
   maxlag = 1000;
   
      
implementation

end.
