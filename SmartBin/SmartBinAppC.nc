/**
 * Blink is a basic application that toggles a mote's LED periodically.
 * It does so by starting a Timer that fires every second. It uses the
 * OSKI TimerMilli service to achieve this goal.
 *
 * @author tinyos-help@millennium.berkeley.edu
 **/

//configuration wires components to the interface used in the module
//in altre parole, le interfacce contengono delle funzioni e dobbiamo dire dove si trova 
//il body delle funzioni

//ad esempio, ogni qual volta chiamiamo (tramite call) un comando dell'interfaccia led,
//andiamo ad eseguire una funzione che è definita in LedsC
configuration SmartBinAppC
{
}
implementation
{
  components MainC, SmartBinC, LedsC, RandomC;
  components new TimerMilliC() as Timer;

  //tramite -> noi colleghiamo la nostra interfaccia al componente di sistema
  SmartBinC -> MainC.Boot;
  SmartBinC.Random -> RandomC;
  SmartBinC.Timer -> Timer;
  SmartBinC.Leds -> LedsC;
}

