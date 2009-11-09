{ other stuff the client needs to know:
the username corresponding to each id, whenever someone new joins
the server time (when they log in) }

program Server;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  SDL, SDL_NET, ShipObjects,NetworkClass, Constants;

var
   udpsock : pUDPsocket;
   tcpsock : pTCPsocket;
   accepted : pTCPsocket;
   clientset : pSDLNet_SocketSet;

   inpacket,outpacket  : pUDPpacket;
   numrecv :  integer;
   msg : Pshipdata;
   id : integer;
   sender : TIPaddress;
   me : TIPaddress;
   port : integer; //can't use me.port!!
   ships : AShipData;
   lastmsgtime : array of integer;
   usernames : array of string;
   addresses : array of TIPaddress;
   


type

TTCPSocketArray = array of PTCPSocket;
PTCPSocketArray = ^TTCPSocketArray;


procedure startstuff();
var i : integer;
begin
   //get port from command line
   if ParamCount > 0 then
   begin
      val(ParamStr(1),port); //convert to integer
      SDLNet_ResolveHost(me,nil,port); //make TIpaddress for listening on this port
   end
   else
   begin
      SDLNet_ResolveHost(me,nil,6666);
      port := 6666;
   end;
   
   //set all ships id to -1 (non existant)
   setlength(ships,maxships);
   for i := 0 to length(ships)-1 do begin
      ships[i].id := -1;
      ships[i].time := 0; //set them all to 0 so that we should recieve data straight away.
   end;
   
   setlength(addresses, maxships);
   setlength(usernames, maxships);
   setlength(lastmsgtime,maxships); //the time the last packet was received
   
   if SDL_Init(0)=-1 then
   begin
      writeln('coudlnt initialise sdl');
   end;

   if SDLNet_Init()=-1 then
   begin
      writeln('couldnt initialise sdlnet');
   end;
   
   udpsock := SDLNet_UDP_Open(port); //open a socket
   if udpsock = nil then
   begin
      writeln('couldnt open socket');
   end;
   
  
   tcpsock := SDLNet_TCP_Open(me);
   if tcpsock = nil then
      writeln('couldnt open tcp socket');

   
   clientset := SDLNet_AllocSocketSet(maxships+1+1);    //+1 to allow for the server socket.. for some reason :S (and +1 more for the udp one :))


   if SDLNet_TCP_AddSocket( clientset, tcpsock ) = -1 then
      Writeln( 'Add Server Socket Error' );
   
   if SDLNet_UDP_AddSocket( clientset, udpsock ) = -1 then
      Writeln( 'Add Server Socket Error' );

   inpacket:=SDLNet_AllocPacket(sizeof(ShipData)); //create a packet to receive data
   if inpacket = nil then
   begin
      writeln('couldnt create UDPpacket');
   end;
   
   outpacket:=SDLNet_AllocPacket(sizeof(ShipData)); //create a packet to send back
   if outpacket = nil then
   begin
      writeln('couldnt create UDPpacket');
   end;
   
   writeln('Listening...'); 
end;

//send shipdata to all the other players over udp
procedure sendship(id : integer);
var i:integer;
begin
   outpacket^.data := PUint8 (@(ships[id]));
   outpacket^.len := sizeof(ships[id]);
   for i := 0 to length(ships)-1 do
   begin
      if (i <> id) and (ships[i].id <> -1) then //also check distance later
      begin
         outpacket^.address.host := addresses[i].host; //set destination host
         outpacket^.address.port := addresses[i].port; //set destination port

        //use -1 for the channel, since the packet has an address on it :)
        if SDLNet_UDP_Send(udpsock, -1, outpacket) = 1 then
//           writeln('sent ship data to: ', i)
        else
           writeln('problem');
      end;
   end;
end;

//remove players who havent sent any messages recently
procedure removeLostPlayers();
var
   i : integer;
begin
   for i := 0 to length(lastmsgtime) - 1 do
   begin
      if (ships[i].id <> -1) and (SDL_GetTicks - lastmsgtime[i] > MAXLAG) then
      begin
         ships[i].id := -1;
         ships[i].time := 0; //set it to 0 so that we should recieve data straight away if someone else comes on.
         //also: we should attempt to send them a message saying they've been kicked off (I guess we'd have to have an array of IPaddress for this)
         //close tcp connection:
         writeln('removing udp connection reference');
      end;
   end;
end;

procedure endstuff();
var
   i : integer;
begin
   SDLNet_FreePacket(inpacket); //free memory
   SDLNet_FreePacket(outpacket); //free memory
   SDLNet_DelSocket(clientset, PSDLNet_GenericSocket (udpsock));
   SDLNet_DelSocket(clientset, PSDLNet_GenericSocket (tcpsock));
   SDLNet_UDP_Close(udpsock); //close socket
   SDLNet_TCP_Close(tcpsock);
   SDLNet_FreeSocketSet(clientset);
   SDLNet_quit();
   SDL_quit();
end;

procedure movePlayers();
begin
   numrecv := SDLNet_UDP_Recv(udpsock,inpacket); //receive packets
   if numrecv = 1 then
   begin
//      writeln('Received packet of length: ',inpacket^.len);
      msg := Pshipdata (inpacket^.data);
      sender := inpacket^.address;
      id := msg^.id;
//      writeln(id, ': ', msg^.x,',',msg^.y); //print location of ship
         
      //update data for this player
      if id < length(ships) then
         if (ships[id].time < msg^.time) OR ((msg^.time < maxlag) AND (ships[id].time > (4294967296-maxlag))) then
            begin
               ships[id].id := msg^.id;
               ships[id].x := msg^.x;
               ships[id].y := msg^.y;
               ships[id].h := msg^.h;
               ships[id].s_x := msg^.s_x;
               ships[id].s_y := msg^.s_y;
               ships[id].status := msg^.status;
               ships[id].time := msg^.time;
               lastmsgtime[id] := SDL_GetTicks;
               addresses[id].host := sender.host; //this doesn't need to be set each time, can be done at login
               addresses[id].port := sender.port;
               sendship(id); //send data to other players nearby
            end;
   end
   else
      if numrecv = -1 then
      begin
         writeln('error receiving packet');
      end;
end;

function login(client : pIPaddress; username,password : string) : integer;
var
   i : integer;
begin   
   //check the login details
   writeln('attempting login');
   result := -1; //return -1 if no space
   
   for i := 0 to length(ships) -1 do
   begin
      if ships[i].id = -1 then
      begin
         ships[i].id := i;
         usernames[i] := username;
         addresses[i].host := client^.host;
         addresses[i].port := client^.port;
         lastmsgtime[i] := SDL_GetTicks;
         result := i;
         break;
      end;
   end;
   writeln('id=',result);
end;

procedure sendall(command : char; data : string);
var 
i : integer;
senddata : NetworkMessage;
worksock : pTcpSocket;
begin
   senddata.command := command;
   senddata.data := data;
   for i := 2 to clientset^.numsockets-1 do begin
      worksock := TTCPSocketArray(clientset^.sockets)[i];
      SDLNet_TCP_Send(worksock,@senddata,sizeof(senddata));
   end;
end;


procedure receivedata(); //get data from clients
var
   client : pIPaddress;
   msg : NetworkMessage; //contains a char 'command' and string 'data'
   username : string;
   time : integer;
   recvd : integer;
   i, numready : integer;
   worksock : pTcpSocket;
begin
   //now check to see if any commands have been recieved:
   
   NumReady := SDLNet_CheckSockets( clientset, 0 );
   if NumReady > 0 then
   begin
      movePlayers(); //check udpsock for new shipdata
      
      
         //check for pending connections
      if SDLNet_SocketReady(PSDLNet_GenericSocket(tcpsock)) then        //check to see if the server socket is ready
      begin
      
         accepted := SDLNet_TCP_Accept(tcpsock); //try to accept a connection (this opens a separate socket to tcpsock)
       
         if accepted <> nil then
         begin
         
            if clientset^.numsockets < clientset^.maxsockets then begin
               SDLNet_TCP_AddSocket( clientset, accepted );
               writeln('got tcp connection. # of connections: ', clientset^.numsockets);
            end;
            
         end;
         
      end;

      
      
      //now check each tcp socket
      for i := 2 to clientset^.numsockets-1 do begin
         worksock := TTCPSocketArray(clientset^.sockets)[i];
         if (SDLNet_SocketReady(PSDLNet_GenericSocket(worksock))) then begin
            writeln('getting data');
            recvd := SDLNet_TCP_Recv(worksock,@msg,sizeof(NetworkMessage)); //receive a message
            if recvd = sizeof(NetworkMessage) then
            begin
               writeln('received data');
               case msg.command of
                  'l':                                   //l for login, username and password sent together makes more sense and is easier to deal with.
                     begin
                        //login the player and return their id, and the time
                        username := msg.data;  
                        writeln('received password');
                        client := SDLNet_TCP_GetPeerAddress(worksock); //get their ip
                        id := login(client,username,msg.data);
                        usernames[id] := username;
                        time := SDL_GetTicks;
                        SDLNet_TCP_Send(worksock,@id,sizeof(id));
                        SDLNet_TCP_Send(worksock,@time,sizeof(time));
                     end;
                  'c': sendall('c',msg.data);   //send the chat data to everyone.
               end;
               
            end else begin          //did not recv sizeof(networkmessage)  therefore its broken, disconnect the client
               writeln('client disconnected');
		         SDLNet_TCP_DelSocket(clientset, worksock);
		         SDLNet_TCP_Close(worksock);
         		// break as the number of items in the socketset have changed
         		// and we'll get an Access Violation if we continue round the loop
           		Break;

            end;
         end;
   end; //oh my that sure is a lot of end
   end;
end;

BEGIN
   startstuff();
   
   while true do
   begin
      receivedata(); //listen for messages sent over tcp (login / chat) and udp (ship data)
      removeLostPlayers();
   end;
   
   endstuff();
      
END.



