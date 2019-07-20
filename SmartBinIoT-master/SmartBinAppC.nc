/**
 * Blink is a basic application that toggles a mote's LED periodically.
 * It does so by starting a Timer that fires every second. It uses the
 * OSKI TimerMilli service to achieve this goal.
 *
 * @author tinyos-help@millennium.berkeley.edu
 **/

#include "SmartBin.h"

configuration SmartBinAppC{}
implementation{
  components MainC, SmartBinC, LedsC, RandomC;
  components new TimerMilliC() as Timer;
  components new TimerMilliC() as TruckTravelTime;
  components new TimerMilliC() as BinTravelTime;
  components new TimerMilliC() as TimerToCollect;
  components ActiveMessageC;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  
  SmartBinC -> MainC.Boot;
  SmartBinC.Random -> RandomC;
  SmartBinC.Timer -> Timer;
  SmartBinC.TruckTravelTime -> TruckTravelTime;
  SmartBinC.BinTravelTime -> BinTravelTime;
  SmartBinC.TimerToCollect -> TimerToCollect;
  SmartBinC.Leds -> LedsC;
  
  //Send and Receive interfaces
  SmartBinC.Receive -> AMReceiverC;
  SmartBinC.AMSend -> AMSenderC;
  
  //Interfaces to access package fields
  SmartBinC.AMPacket -> AMSenderC;
  SmartBinC.Packet -> AMSenderC;
  SmartBinC.PacketAcknowledgements->ActiveMessageC;
  
  //Radio Control
  SmartBinC.SplitControl -> ActiveMessageC;
}

