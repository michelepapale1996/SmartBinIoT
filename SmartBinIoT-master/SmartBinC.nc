/**
 * Implementation for SmartBin application
 **/

#include "Timer.h"
#include "SmartBin.h"
#include <math.h>

module SmartBinC @safe(){
  uses interface Timer<TMilli> as Timer;
  uses interface Timer<TMilli> as TravelTime;
  uses interface Random;
  uses interface Leds;
  uses interface Boot;
  
  uses interface AMPacket; 
  uses interface Packet;
  uses interface PacketAcknowledgements;
  uses interface AMSend;
  uses interface Receive;
  
  //for turn on the radio
  uses interface SplitControl;
}
implementation{
  bool busy = FALSE;
  uint16_t msg_count = 0;
  uint8_t garbageInBin = 0;
  message_t packet;
  uint32_t time;
  uint16_t garbageToAdd;
  uint8_t coordinateX;
  uint8_t coordinateY;
  uint16_t delay;
  
 //these coordinate will replace the actual coordinates, used only in the truck
 uint16_t newCoordX;
 uint16_t newCoordY;
 //id of the bin that require truck
 uint16_t targetID;
 
  
  event void Boot.booted(){
    dbg("boot","Application booted.\n");
    
    coordinateX = call Random.rand16();
    coordinateX = coordinateX % 100;
    
    coordinateY = call Random.rand16();
    coordinateY = coordinateY % 100;
    dbg("SmartBinC", "Coordinates of the mote are: (%d, %d)\n", coordinateX, coordinateY);
    
    call SplitControl.start(); //turn on the radio
  }
  
  task void sendAlert();
  task void sendMove();
  task void sendTruckMessage();
  
  //***************** Task send request for ALERT messages ********************//
  task void sendAlert() {
	//prepare a msg
	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = ALERT;
	mess->msg_id = msg_count;
	mess->bin_id = TOS_NODE_ID;
	mess->coordX = coordinateX;
	mess->coordY = coordinateY;
	    
	dbg("radio_send", "Try to send a request to TRUCK at time %s \n", sim_time_string());
    
	//set a flag informing the receiver that the message must be acknoledge
	call PacketAcknowledgements.requestAck( &packet );
	
	//send message to TRUCK
	if(call AMSend.send(0,&packet,sizeof(my_msg_t)) == SUCCESS){
	  dbg("radio_send", "Packet passed to lower layer successfully!\n");
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
	  dbg_clear("radio_pack", "\t\t bin_id: %hhu \n", mess->bin_id);
	  dbg_clear("radio_pack", "\t\t coordX: %hhu \n", mess->coordX);
	  dbg_clear("radio_pack", "\t\t coordY: %hhu \n", mess->coordY);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");
      }
 }  
 
 //***************** Task send request ********************//
  task void sendMove() {
	//prepare a msg
	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = MOVE;
	mess->msg_id = msg_count;
	mess->bin_id = TOS_NODE_ID;
	mess->coordX = coordinateX;
	mess->coordY = coordinateY;
	    
	dbg("radio_send", "Try to send a request to all other bins at time %s \n", sim_time_string());
    
	//set a flag informing the receiver that the message must be acknoledge
	//call PacketAcknowledgements.requestAck( &packet );
	
	//send message to ALL the bins
	if(call AMSend.send(AM_BROADCAST_ADDR,&packet,sizeof(my_msg_t)) == SUCCESS){
	  dbg("radio_send", "Packet passed to lower layer successfully!\n");
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
	  dbg_clear("radio_pack", "\t\t bin_id: %hhu \n", mess->bin_id);
	  dbg_clear("radio_pack", "\t\t coordX: %hhu \n", mess->coordX);
	  dbg_clear("radio_pack", "\t\t coordY: %hhu \n", mess->coordY);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");
      }
 }  
 
   //****************** Task send response *****************//
  task void sendTruckMessage() {
	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = TRUCK;
	mess->msg_id = TOS_NODE_ID;
	  
	dbg("radio_send", "Try to send a response to BIN %d at time %s \n", targetID, sim_time_string());
	call PacketAcknowledgements.requestAck( &packet );
	if(call AMSend.send(targetID,&packet,sizeof(my_msg_t)) == SUCCESS){
	  busy = FALSE;
	  dbg_clear("radio_rec", "The truck now is Available!\n");
		
	  dbg("radio_send", "Packet passed to lower layer successfully!\n");
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");

        }
  }
  
  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
    time = call Random.rand16();
    time = time % RANDOM_IN_30;
    if(err == SUCCESS) {
	dbg("radio","Radio on!\n");
	//if it is not the truck, start timer to add garbage
	if(TOS_NODE_ID != 0){
           dbg("init", "Starting timer that expires in %d.\n", time);
	   call Timer.startOneShot( time );
    	}
    }else{
	//dbg for error
	call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err){}
  
  event void Timer.fired(){
    time = call Random.rand16();
    garbageToAdd = call Random.rand16();
    
    dbg("SmartBinC", "Timer fired - Garbage level: %d\n", garbageInBin);
   
    time = time % RANDOM_IN_30;
    garbageToAdd = garbageToAdd % RANDOM_IN_10;
    time = time + 1000;
    garbageToAdd = garbageToAdd + 1;
    
    if( garbageInBin + garbageToAdd < 85) {
        dbg("SmartBinC", "Adding garbage: %d\n", garbageToAdd);
        dbg("SmartBinC", "Normal status\n");
    	garbageInBin = garbageInBin + garbageToAdd;
    }
    
    if(garbageInBin + garbageToAdd >= 85 && garbageInBin + garbageToAdd < 100){
        dbg("SmartBinC", "Adding garbage: %d\n", garbageToAdd);
    	dbg("SmartBinC", "Critical status\n");
    	garbageInBin = garbageInBin + garbageToAdd;
    	//post sendAlert();
    }
    
    if(garbageInBin + garbageToAdd >= 100){
    	dbg("SmartBinC", "Full status\n");
    	post sendMove();
    }
    
    dbg("SmartBinC", "Starting timer that expires in %d.\n", time);
    call Timer.startOneShot( time );
  }
  
  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
    if(&packet == buf && err == SUCCESS ) {
	dbg("radio_send", "Packet sent...");
	//check if ack is received
	if ( call PacketAcknowledgements.wasAcked( buf ) ) {
	  dbg_clear("radio_ack", "and ack received");
	} else {
	  dbg_clear("radio_ack", "but ack was not received");
	  post sendAlert();
	}
	dbg_clear("radio_send", " at time %s \n", sim_time_string());
    }
    msg_count++;	
  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	my_msg_t* mess=(my_msg_t*)payload;
	delay = sqrt(pow(coordinateX - mess->coordX,2) + pow(coordinateY - mess->coordY,2));
	
	dbg("radio_rec","Message received at time %s \n", sim_time_string());
	dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
	dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
	dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
	dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
	dbg_clear("radio_pack","\t\t Payload \n" );
	dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", mess->msg_type);
	dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
	dbg_clear("radio_pack", "\t\t bin_id: %hhu \n", mess->bin_id);
	dbg_clear("radio_pack", "\t\t coordX: %hhu \n", mess->coordX);
	dbg_clear("radio_pack", "\t\t coordY: %hhu \n", mess->coordY);
	dbg_clear("radio_pack", "\ttravel time is: %d\n", delay);
	dbg_clear("radio_rec", "\n ");
	dbg_clear("radio_pack","\n");
	
	if ( mess->msg_type == ALERT ) {
		if (!busy){
			busy = TRUE;
		
			call TravelTime.startOneShot( alphaBin_Truck * delay ); //TODO * 1000
			dbg_clear("radio_rec", "\tTrack will be there in %d.\n", delay * 1000);
		
			targetID = mess->bin_id;
			newCoordX = mess->coordX;
			newCoordY = mess->coordY; 
		}else{
			dbg_clear("radio_rec", "The truck is busy -> discard the message!\n");
		}
	} 
	
	if ( mess->msg_type == TRUCK ) {
		garbageInBin = 0;
		dbg("SmartBinC", "Emptying bin...\n");
	} 

    return buf;

  }
  event void TravelTime.fired(){
  	coordinateX = newCoordX;
  	coordinateY = newCoordY;
    	dbg("SmartBinC", "Truck is arrived at coordinates: (%d, %d)\n", coordinateX, coordinateY);
  	post sendTruckMessage();
  
  }
  
}

