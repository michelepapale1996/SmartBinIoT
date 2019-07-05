/**
 * Implementation for SmartBin application
 **/

#include "Timer.h"
#include "SmartBin.h"

module SmartBinC @safe(){
  uses interface Timer<TMilli> as Timer;
  uses interface Random;
  uses interface Leds;
  uses interface Boot;
}
implementation{
  uint8_t garbageInBin = 0;
  
  event void Boot.booted(){
    uint32_t time = call Random.rand16();
    time = time % RANDOM_IN_30;
  
    dbg("boot","Application booted.\n");
    dbg("init", "Starting timer that expires in %d.\n", time);
    call Timer.startOneShot( time );
  }
  
  event void Timer.fired(){
    uint16_t time = call Random.rand16();
    uint16_t garbageToAdd = call Random.rand16();
    
    //dbg("SmartBinC", "Timer fired @ %s.\n", sim_time_string());
    dbg("SmartBinC", "Timer fired\n");
    dbg("SmartBinC", "Garbage level: %d\n", garbageInBin);
   
    time = time % RANDOM_IN_30;
    garbageToAdd = garbageToAdd % RANDOM_IN_10;
    time = time + 1000;
    garbageToAdd = garbageToAdd + 1;
    dbg("SmartBinC", "Adding garbage: %d\n", garbageToAdd);
    
    if( garbageInBin + garbageToAdd < 85) {
    dbg("SmartBinC", "Normal status\n");
    	garbageInBin = garbageInBin + garbageToAdd;
    }
    
    if(garbageInBin + garbageToAdd >= 85 && garbageInBin + garbageToAdd < 100){
    	dbg("SmartBinC", "Critical status\n");
    	garbageInBin = garbageInBin + garbageToAdd;
    }
    
    if(garbageInBin + garbageToAdd >= 100){
    	dbg("SmartBinC", "Full status\n");
    }
    
    dbg("SmartBinC", "Starting timer that expires in %d.\n", time);
    call Timer.startOneShot( time );
  }
}

