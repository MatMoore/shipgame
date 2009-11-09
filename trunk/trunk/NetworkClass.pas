unit NetworkClass;

{$mode objfpc}{$H+}

interface

uses ShipObjects,SDL,SDL_Net, log;

const
   timeout = 5000;

type
   NetworkMessage = record
      command : char;
      data : Shortstring;
   end;
   
   TNetwork = class(Tobject)
private
   lastid : byte;
   udpsock : pUDPsocket;
   tcpsock : pTCPsocket;
   server : TIPaddress;
   socketset : PSDLNet_SocketSet;

public
   constructor create(s : TIPaddress);
   destructor destroy(); override;
   function sendship(data : ShipData) : boolean;
   procedure receiveships(var ships : AShipData);
   function receivetcpdata(var recv : NetworkMessage) : boolean;
   procedure sendtcpdata(msg : NetworkMessage);
   function login(username,password : string; var time : integer) : integer;
end;

implementation

function TNetwork.sendship(data : ShipData) : boolean;
var
   packet : pUDPpacket;
begin
   result := false;
   packet:=SDLNet_AllocPacket(sizeof(data)); //create a packet to hold enough data
   if packet = nil then
   begin
      dolog('couldnt create UDPpacket');
   end
   else
   begin
      lastid := lastid + 1;
      packet^.data := PUint8 (@data);
      packet^.address.host := server.host; //set destination host/port. alternatively, the address could be bound to a channel
      packet^.address.port := server.port;
      packet^.len := sizeof(data);

      //use -1 for the channel, since the packet has an address on it :)
      if SDLNet_UDP_Send(udpsock, -1, packet) = 1 then
         result := true; //it got sent, hooray
   end;
   
   //SDLNet_FreePacket(packet); //free memory (this makes it crash?)
end;

procedure TNetwork.receiveships(var ships : AShipData);
var
   packet : pUDPpacket;
   numrecv : integer;
   ship : ShipData;
begin
   repeat
      begin
         packet:=SDLNet_AllocPacket(sizeof(ShipData)); //create a packet to send back
         if packet = nil then
         begin
            dolog('couldnt create UDPpacket');
         end;

         numrecv := SDLNet_UDP_Recv(udpsock,packet);
         if numrecv = 1 then
         begin
            ship := (PShipData (packet^.data))^;
            setlength(ships,length(ships)+1);
            ships[length(ships)-1] := ship;
         end
         else
            if numrecv = -1 then
               dolog('error receiving packet');
      end;
   until numrecv = 0;
end;

function TNetwork.receivetcpdata(var recv : networkmessage) : boolean;
var
   numrecv : integer;
begin
result := false;
   if SDLNet_CheckSockets( socketset, 0 ) > 0 then begin
      if SDLNet_SocketReady( PSDLNet_GenericSocket( tcpsock ) ) then begin
         numrecv := SDLNet_TCP_Recv(tcpsock,@recv,sizeof(recv));   
         if numrecv = -1 then begin
            dolog('Disconnected by server');
            halt;
         end;
         if numrecv = sizeof(recv) then result := true else result := false;
      end else result := false;
   end;
   
end;

procedure TNetwork.sendtcpdata(msg : networkmessage);
begin
   if tcpsock <> nil then
      SDLNet_TCP_Send(tcpsock, @msg, sizeof(msg));
end;

function TNetwork.login(username,password : string; var time : integer) : integer;
var
   msg : NetworkMessage;
   id : integer;
   numrecv : integer;
   starttime: integer;
begin;
   result := -1;
   
   tcpsock := SDLNet_TCP_Open(server);
   if tcpsock = nil then
      dolog('Could not connect to server')
   else
   begin   
      SDLNet_TCP_AddSocket(SocketSet, tcpsock);
      //send username and password
      msg.command := 'l';                                      //l for log in :)
      msg.data := username+'/'+password;
      SDLNet_TCP_Send(tcpsock,@msg,sizeof(msg));
      dolog('sent login');

      //receive id
      starttime := SDL_GetTicks;
      numrecv := SDLNet_TCP_Recv(tcpsock,@id,sizeof(integer));   
      if numrecv = -1 then begin 
         dolog('disconnected by server'); 
         halt;
      end;
      starttime := SDL_GetTicks;
      numrecv := SDLNet_TCP_Recv(tcpsock,@time,sizeof(integer));   
      if numrecv = -1 then begin 
         dolog('disconnected by server'); 
         halt;
      end;   
      result := id;
    end;
end;

constructor TNetwork.create(s : TIPaddress);
begin
   server := s;

   if SDL_Init(0)=-1 then
   begin
      dolog('coudlnt initialise sdl');
   end;

   if SDLNet_Init()=-1 then
   begin
      dolog('couldnt initialise sdlnet');
   end;
   
   udpsock := SDLNet_UDP_Open(0); //open a socket on any old port
   if udpsock = nil then
   begin
      dolog('couldnt open socket');
   end;
   lastid := random(255); //randomise the initialising lastid so it doesnt always start at 0.
   
   SocketSet := SDLNet_AllocSocketSet(1);
   
end;

destructor TNetwork.destroy();
begin
   SDLNet_TCP_Close(tcpsock);
   SDLNet_UDP_Close(udpsock); //close socket
   SDLNet_quit();
   SDL_quit();
end;

end.
