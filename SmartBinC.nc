/**
 * Implementation for SmartBin application
 **/

#include "Timer.h"
#include "SmartBin.h"
#include <math.h>

module SmartBinC @safe(){
  uses interface Timer<TMilli> as Timer;
  uses interface Timer<TMilli> as TruckTravelTime;
  uses interface Timer<TMilli> as BinTravelTime;
  uses interface Timer<TMilli> as TimerToCollect;
  uses interface Timer<TMilli> as AlertTimer;
  uses interface Random;
  uses interface Boot;
  
  uses interface AMPacket; 
  uses interface Packet;
  uses interface PacketAcknowledgements;
  uses interface AMSend;
  uses interface AMSend as AMSerialSend;
  uses interface Receive;
  
  uses interface Packet as SerialPacket;
  //for turn on the radio
  uses interface SplitControl;
  uses interface SplitControl as SerialSplitControl;
}
implementation {
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
 //id of the bin that requires truck or id for the response in a move - moveResp handshake
 uint16_t targetID;
 //variables used for full status mode to select the closest bin
 uint16_t closestBin;
 uint16_t smallerDistance;
 uint16_t trashInExcess;
 
  event void Boot.booted(){
    dbg("boot","Application booted.\n");
    
    coordinateX = call Random.rand16();
    coordinateX = coordinateX % MAX_COORDINATE_X;
    
    coordinateY = call Random.rand16();
    coordinateY = coordinateY % MAX_COORDINATE_Y;
    dbg("boot", "Coordinates of the mote are: (%d, %d)\n", coordinateX, coordinateY);
    
    call SplitControl.start(); //turn on the radio
    call SerialSplitControl.start();
  }
  
  //***************** SplitControl interface ********************//
  event void SerialSplitControl.startDone(error_t err){}
  event void SerialSplitControl.stopDone(error_t err){}
  
  event void SplitControl.startDone(error_t err){
    time = call Random.rand16();
    time = time % RANDOM_IN_30;
    if(err == SUCCESS) {
	dbg("radio","Radio on!\n");
	//if it is not the truck, start timer to add garbage
	if(TOS_NODE_ID != 0){
           //dbg("radio", "Starting timer that expires in %d.\n", time);
	   call Timer.startOneShot( time );
    	}
    }else{
	//dbg for error
	call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err){}
  
  task void sendAlert();
  task void sendMove();
  task void sendTruckMessage();
  task void sendTrashMove();
  task void sendMoveResponse();
  void sendSerialPacket(uint8_t _packetType, uint16_t _bin_id, uint16_t _coordX, uint16_t _coordY, uint16_t _trashInExcess);
  
  //************************ sending packets *********************//
  void sendSerialPacket(uint8_t _packetType, uint16_t _bin_id, uint16_t _coordX, uint16_t _coordY, uint16_t _trashInExcess){

	my_msg_t* cm = (my_msg_t*)call SerialPacket.getPayload(&packet, sizeof(my_msg_t));
      if (cm == NULL) {return;}
      if (call SerialPacket.maxPayloadLength() < sizeof(my_msg_t)) {
	return;
      }

      cm->msg_type = _packetType;
      cm->bin_id = _bin_id;
      cm->coordX = _coordX;
      cm->coordY = _coordY;
      cm->trashInExcess = _trashInExcess;
      if (call AMSerialSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
		dbg("role","Serial Packet sent...\n");
      }
  }	
  
  task void sendAlert() {
	//prepare a msg
	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = ALERT;
	mess->bin_id = TOS_NODE_ID;
	mess->coordX = coordinateX;
	mess->coordY = coordinateY;
	    
	dbg("radio_send", "time: %s - sendAlert() - Try to send a request to TRUCK\n", sim_time_string());
	
	sendSerialPacket(ALERT, TOS_NODE_ID, coordinateX, coordinateY, trashInExcess);
	
	//send message to TRUCK
	if( !busy && call AMSend.send(0,&packet,sizeof(my_msg_t)) == SUCCESS){
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_pack", "\t\t bin_id: %hhu \n", mess->bin_id);
	  dbg_clear("radio_pack", "\t\t coordX: %hhu \n", mess->coordX);
	  dbg_clear("radio_pack", "\t\t coordY: %hhu \n", mess->coordY);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");
	  busy = TRUE;
    	}else{
		dbg("radio_send", "time: %s - sendAlert() - Cannot send because of concurrent sending of another message\n", sim_time_string());    	
    	}
 }  
 
  task void sendMove() {
	//prepare a msg
	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = MOVE;
	mess->bin_id = TOS_NODE_ID;
	mess->coordX = coordinateX;
	mess->coordY = coordinateY;
	    
	dbg("radio_send", "time: %s - sendMove() - Try to send a request to all other BINS\n", sim_time_string());
	
	sendSerialPacket(MOVE, TOS_NODE_ID, coordinateX, coordinateY, trashInExcess);
	//send message to ALL the bins
	if( !busy && call AMSend.send(AM_BROADCAST_ADDR,&packet,sizeof(my_msg_t)) == SUCCESS){
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_pack", "\t\t bin_id: %hhu \n", mess->bin_id);
	  dbg_clear("radio_pack", "\t\t coordX: %hhu \n", mess->coordX);
	  dbg_clear("radio_pack", "\t\t coordY: %hhu \n", mess->coordY);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");
	  
	  busy = TRUE;
    	} else {
		dbg("radio_send", "time: %s - sendAlert() - Cannot send because of concurrent sending of another message\n", sim_time_string());    	
    	}
 }  
 
 task void sendTruckMessage() {
	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = TRUCK;
	  
	sendSerialPacket(TRUCK, TOS_NODE_ID, coordinateX, coordinateY, trashInExcess);
	  
	dbg("radio_send", "time: %s - sendTruckMessage() - Try to send a response to BIN %d\n", sim_time_string(), targetID);
	call PacketAcknowledgements.requestAck( &packet );
	if(call AMSend.send(targetID,&packet,sizeof(my_msg_t)) == SUCCESS){
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");
    }
  }
  
  task void sendMoveResponse() {
  	//prepare a msg
	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = RESP_MOVE;
	mess->bin_id = TOS_NODE_ID;
	mess->coordX = coordinateX;
	mess->coordY = coordinateY;
	    
	dbg("radio_send", "time: %s - sendMoveResponse() - Try to send a response to BIN %d\n", sim_time_string(), targetID);
	
	sendSerialPacket(RESP_MOVE, TOS_NODE_ID, coordinateX, coordinateY, trashInExcess);
	
	//send message to ALL the bins
	if(!busy && call AMSend.send(targetID, &packet,sizeof(my_msg_t)) == SUCCESS){
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_pack", "\t\t bin_id: %hhu \n", mess->bin_id);
	  dbg_clear("radio_pack", "\t\t coordX: %hhu \n", mess->coordX);
	  dbg_clear("radio_pack", "\t\t coordY: %hhu \n", mess->coordY);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");
	  
	  busy = TRUE;
    	} else {
		dbg("radio_send", "time: %s - sendAlert() - Cannot send because of concurrent sending of another message\n", sim_time_string());    	
    	}
  }
  
  task void sendTrashMove() {
  	//prepare a msg
	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = TRASH_MOVE;
	mess->trashInExcess = trashInExcess;
	    
	dbg("radio_send", "time: %s - sendTrashMove() - Move trash of %d to %d \n", sim_time_string(), trashInExcess, closestBin);
    
	//set a flag informing the receiver that the message must be acknoledge
	call PacketAcknowledgements.requestAck( &packet );
	
	sendSerialPacket(TRASH_MOVE, TOS_NODE_ID, coordinateX, coordinateY, trashInExcess);
	
	if(!busy && call AMSend.send(closestBin, &packet,sizeof(my_msg_t)) == SUCCESS){
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_pack", "\t\t trashInExcess: %hhu \n", mess->trashInExcess);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");
	  
	  busy = TRUE;
    	} else {
		dbg("radio_send", "time: %s - sendAlert() - Cannot send because of concurrent sending of another message\n", sim_time_string());    	
    	}
  }
  
  //********************* AMSend interface ****************//
  event void AMSerialSend.sendDone(message_t* buf,error_t err) {
  }
  event void AMSend.sendDone(message_t* buf,error_t err) {
    my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	
    if(&packet == buf && TOS_NODE_ID != 0) busy = FALSE;
	
    if(&packet == buf && err == SUCCESS ){
	dbg("radio_send", "Packet of type %d sent...", mess->msg_type);
	
	//check if ack is received
	if ( call PacketAcknowledgements.wasAcked( buf ) ) {
		if ( mess->msg_type == TRUCK ) {
			dbg_clear("radio_ack", "and ack received");
			busy = FALSE;
		}
	
		if ( mess->msg_type == TRASH_MOVE ) {
			dbg_clear("radio_ack", "and ack received");
			//post sendTrashMove()
			trashInExcess = 0;
			closestBin = 0;
	  		smallerDistance = 0;
		}
	} else {
		if ( mess->msg_type == MOVE ) {
	 		//for 2 seconds accept responses of available bins
	  		call TimerToCollect.startOneShot(2000);
	  	}
	
	  	if ( mess->msg_type == TRUCK ) {
	  		dbg_clear("radio_ack", "but ack was not received");
			post sendTruckMessage();
	 	}
	
	  	if ( mess->msg_type == TRASH_MOVE ) {
	  		dbg_clear("radio_ack", "but ack was not received");
			post sendTrashMove();
	  	}
	}
	dbg_clear("radio_send", " at time %s \n", sim_time_string());
    }	
  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	my_msg_t* mess=(my_msg_t*)payload;
	
	if ( mess->msg_type == ALERT ) {
		dbg("radio_rec","Message received at time %s \n", sim_time_string());
		dbg("radio_pack","ALERT message >>> Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
		dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
		dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
		dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", mess->msg_type);
		dbg_clear("radio_pack", "\t\t bin_id: %hhu \n", mess->bin_id);
		dbg_clear("radio_pack", "\t\t coordX: %hhu \n", mess->coordX);
		dbg_clear("radio_pack", "\t\t coordY: %hhu \n", mess->coordY);
		dbg_clear("radio_pack","\n");
		if (!busy){
			busy = TRUE;
			delay = sqrt(pow(coordinateX - mess->coordX,2) + pow(coordinateY - mess->coordY,2));
			call TruckTravelTime.startOneShot( alphaBin_Truck * delay * 1000);
			dbg("radio_rec", "The truck will be there in %d s.\n", alphaBin_Truck * delay );
		
			targetID = mess->bin_id;
			newCoordX = mess->coordX;
			newCoordY = mess->coordY; 
		}else{
			dbg("radio_rec", "The truck is busy -> discard the message!\n");
		}
	} 
	
	if ( mess->msg_type == TRUCK ) {
		dbg("radio_rec","Message received at time %s \n", sim_time_string());
		dbg("radio_pack","TRUCK message>>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
		dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
		dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
		dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", mess->msg_type);
		dbg_clear("radio_rec", "\n ");
		dbg_clear("radio_pack","\n");
		
		garbageInBin = 0;
		dbg("SmartBinC", "Emptying bin...\n");
		call AlertTimer.stop();
	} 
	
	//if the bin has received a move message 
	if ( mess->msg_type == MOVE && TOS_NODE_ID != 0 ) {
		dbg("radio_rec","Message received at time %s \n", sim_time_string());
		dbg("radio_pack","MOVE message >>> Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
		dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
		dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
		dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", mess->msg_type);
		dbg_clear("radio_pack", "\t\t bin_id: %hhu \n", mess->bin_id);
		dbg_clear("radio_pack", "\t\t coordX: %hhu \n", mess->coordX);
		dbg_clear("radio_pack", "\t\t coordY: %hhu \n", mess->coordY);
		dbg_clear("radio_rec", "\n ");
		dbg_clear("radio_pack","\n");
		
		if( garbageInBin < 85) {
			delay = sqrt(pow(coordinateX - mess->coordX,2) + pow(coordinateY - mess->coordY,2));
			targetID = mess->bin_id;
			call BinTravelTime.startOneShot( aplhaBin_Bin * delay * 1000);
			dbg("radio_rec", "Bin response will be there in %f s.\n", delay * aplhaBin_Bin); 
    		} else {
    			dbg("radio_rec", "Bin in critical status -> discard the message\n"); 
    		}
  	}
  	
  	if ( mess->msg_type == RESP_MOVE ) {
		dbg("radio_rec","Message received at time %s \n", sim_time_string());
		dbg("radio_pack","RESP_MOVE message >>> Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
		dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
		dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
		dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", mess->msg_type);
		dbg_clear("radio_pack", "\t\t bin_id: %hhu \n", mess->bin_id);
		dbg_clear("radio_pack", "\t\t coordX: %hhu \n", mess->coordX);
		dbg_clear("radio_pack", "\t\t coordY: %hhu \n", mess->coordY);
		dbg_clear("radio_rec", "\n ");
		dbg_clear("radio_pack","\n");
		
		if(call TimerToCollect.isRunning()){
			targetID = mess->bin_id;
			if(closestBin == 0 && smallerDistance == 0){
				closestBin = mess->bin_id;
				smallerDistance = sqrt(pow(coordinateX - mess->coordX,2) + pow(coordinateY - mess->coordY,2));
				dbg("SmartBinC", "Arrived first response. New closestBin: %d, new smallerDistance: %d\n", closestBin, smallerDistance);
			}else{
				if(smallerDistance > sqrt(pow(coordinateX - mess->coordX,2) + pow(coordinateY - mess->coordY,2 ))) {
					closestBin = mess->bin_id;
					smallerDistance = sqrt(pow(coordinateX - mess->coordX,2) + pow(coordinateY - mess->coordY,2));
					dbg("SmartBinC", "Arrived another response of a bin closer to me. New closestBin: %d, new smallerDistance: %d\n", closestBin, smallerDistance);
				} else {
					dbg("SmartBinC", "Arrived response. closestBin: %d, smallerDistance: %d and nothing changed\n", closestBin, smallerDistance);
				}
			}
		} else {
			dbg("SmartBinC", "Received packet but TimerToCollect is over!\n");
		}
	} 
	
	if ( mess->msg_type == TRASH_MOVE ) {
		dbg("radio_rec","Message received at time %s \n", sim_time_string());
		dbg("radio_pack","TRASH_MOVE message >>> Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
		dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
		dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
		dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", mess->msg_type);
		dbg_clear("radio_pack", "\t\t trashInExcess: %hhu \n", mess->trashInExcess);
		dbg_clear("radio_rec", "\n ");
		dbg_clear("radio_pack","\n");
		
		if(garbageInBin + mess->trashInExcess >= 100){
			garbageInBin = 100;
			trashInExcess = trashInExcess + garbageInBin + mess->trashInExcess - 100;
			dbg("radio_rec","Arrived trash - Uploaded garbage in bin: %d, trash in excess: %d \n", garbageInBin, trashInExcess);
		} else {
			garbageInBin = garbageInBin + mess->trashInExcess;
			dbg("radio_rec","Arrived trash - Uploaded garbage in bin: %d\n", garbageInBin);
		}
	} 
	
  	return buf;
  }
  
  //------------------------------------------------------------TIMERS-------------------------------------------------------------
  
  event void TruckTravelTime.fired(){
  	coordinateX = newCoordX;
  	coordinateY = newCoordY;
    	dbg("SmartBinC", "TruckTravelTime fired -> Truck is arrived at coordinates: (%d, %d)\n", coordinateX, coordinateY);
  	post sendTruckMessage();
  }
  
  event void BinTravelTime.fired(){
  	dbg("SmartBinC", "BinTravelTime fired\n");
  	post sendMoveResponse();
  }
  
  event void Timer.fired(){
    time = call Random.rand16();
    garbageToAdd = call Random.rand16();
   
    time = time % RANDOM_IN_30;
    garbageToAdd = garbageToAdd % RANDOM_IN_10;
    time = time + 1000;
    garbageToAdd = garbageToAdd + 1;
    
    if( garbageInBin + garbageToAdd < 85) {
        //dbg("SmartBinC", "Adding garbage: %d\n", garbageToAdd);
    	garbageInBin = garbageInBin + garbageToAdd;
    	dbg("SmartBinC", "time: %s - Adding garbage: %d, Excess already present: %d, Garbage level: %d -> Normal status\tNext time: %d\n", sim_time_string(), garbageToAdd, trashInExcess, garbageInBin, time);
    }
    
    else if(garbageInBin + garbageToAdd >= 85 && garbageInBin + garbageToAdd < 100){
        //dbg("SmartBinC", "Adding garbage: %d\n", garbageToAdd);
    	garbageInBin = garbageInBin + garbageToAdd;
    	dbg("SmartBinC", "time: %s - Adding garbage: %d, Excess already present: %d, Garbage level: %d -> Critical status\tNext time: %d\n", sim_time_string(), garbageToAdd, trashInExcess, garbageInBin, time);
    	
    	if(!(call AlertTimer.isRunning())) call AlertTimer.startPeriodic(5000);
    }
    
    else if(garbageInBin + garbageToAdd >= 100){
    	trashInExcess = trashInExcess + garbageInBin + garbageToAdd - 100;
    	garbageInBin = 100;
    	dbg("SmartBinC", "time: %s - Adding garbage: %d, Excess already present: %d, Garbage level: %d-> Full status\tNext time: %d\n", sim_time_string(), garbageToAdd, trashInExcess, garbageInBin, time);
    
    	post sendMove();
    }
    
    //dbg("SmartBinC", "Starting timer that expires in %d.\n", time);
    call Timer.startOneShot( time );
  }
  
  event void TimerToCollect.fired(){
 	dbg("SmartBinC", "TimerToCollect is over!\n");
  	if(closestBin == 0 && smallerDistance == 0){
  		dbgerror("SmartBinC", "It has not been found an available bin near to me\n");
  		trashInExcess = 0;
  	} else {
  		post sendTrashMove();
  	}
  }
  
  event void AlertTimer.fired(){
  	post sendAlert();
  }
  
}
