unit TradeObjects;

{$mode objfpc}{$H+}

interface

uses log;

const
   MAXPURCHASE = 100000; //how many items you can trade at a time

type
   items = (Food,Water,Air,Fuel); //all of the items it is possible to trade
   itemcount = array of integer;
   namearray = array[items] of string; //this is indexed by items, rather than a number
   boolarray = array of boolean;
   
   tradeclass = class(Tobject)
   protected
      tradeableitems : itemcount;
      itemnames : namearray;
   public
      Constructor create();
      procedure makeNames();
      procedure trade(tradewith : tradeclass; buyamount,sellamount : itemcount);
      procedure additems(amount : itemcount);
      procedure removeitems(amount : itemcount);
   end;
   
   //used for space stations so that they can have infinite supplies of everything
   //(i dunno how the economy is going to work but lets not worry about that now)
   magicaltradeclass = class(tradeclass)
   public
      Constructor create(instock : boolarray);
      procedure additems(amount : itemcount);
      procedure removeitems(amount : itemcount);
   end;
   
implementation

Constructor tradeclass.create();
var i : integer;
begin
   makeNames();
   setLength(tradeableitems,length(itemnames));
      
   //start with nothing
   for i:= 0 to length(tradeableitems)-1 do
      tradeableitems[i] := 0;
end;

procedure tradeclass.makeNames();
begin
   itemnames[Food] := 'Food';
   itemnames[Water] := 'Water';
   itemnames[Air] := 'Air';
   itemnames[Fuel] := 'Fuel';
end;

procedure tradeclass.trade(tradewith : tradeclass; buyamount,sellamount : itemcount);
var i : integer;
begin
   //add check here to make sure they have the items
   for i:= 0 to length(tradeableitems)-1 do
   begin
      tradeableitems[i] := tradeableitems[i] + buyamount[i]; //add items
      tradeableitems[i] := tradeableitems[i] - sellamount[i]; //remove items
   end;
   tradewith.removeitems(buyamount); //remove items from the other object
   tradewith.additems(sellamount); //add items to the other object
   //add stuff to save data to server?
end;

procedure tradeclass.additems(amount : itemcount);
var i : integer;
begin
   for i:= 0 to length(tradeableitems)-1 do
      tradeableitems[i] := tradeableitems[i] + amount[i];
end;

procedure tradeclass.removeitems(amount : itemcount);
var i : integer;
begin
   for i:= 0 to length(tradeableitems)-1 do
      tradeableitems[i] := tradeableitems[i] - amount[i];
end;

constructor magicaltradeclass.create(instock : boolarray);
var i : integer;
begin
   makeNames();
   setLength(tradeableitems,length(itemnames));
   
   for i:= 0 to length(tradeableitems)-1 do
   begin
      if(instock[i]) then
         tradeableitems[i] := MAXPURCHASE
      else
         tradeableitems[i] := 0;
   end;
end;

procedure magicaltradeclass.additems(amount : itemcount);
begin
   //do nothing?
end;

procedure magicaltradeclass.removeitems(amount : itemcount);
begin
   //do nothing?
end;

end.
