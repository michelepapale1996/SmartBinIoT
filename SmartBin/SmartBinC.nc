/**
 * Implementation for SmartBin application
 **/

#include "Timer.h"

module SmartBinC @safe(){
  uses interface Timer<TMilli> as Timer;
  uses interface Random;
  uses interface Leds;
  uses interface Boot;
}
implementation{
  uint8_t counter = 0;
  
  event void Boot.booted(){
    //call used to activate commands
    uint32_t time = call Random.rand16();
    time = time % 30;
    dbg("BlinkC", "Starting timer that expires in %s.\n", time);
    call Timer.startOneShot( time );
  }
  
  event void Timer.fired(){
    uint16_t time = call Random.rand16();
    time = time % 30;
  
    dbg("BlinkC", "Timer fired @ %s.\n", sim_time_string());
    call Leds.led2Toggle();
    
    dbg("BlinkC", "Starting timer that expires in %s.\n", time);
    call Timer.startOneShot( time );
  }
}

