/**
 * Blink is a basic application that toggles a mote's LED periodically.
 * It does so by starting a Timer that fires every second. It uses the
 * OSKI TimerMilli service to achieve this goal.
 *
 * @author tinyos-help@millennium.berkeley.edu
 **/

configuration SmartBinAppC{
}
implementation
{
  components MainC, SmartBinC, LedsC, RandomC;
  components new TimerMilliC() as Timer;

  SmartBinC -> MainC.Boot;
  SmartBinC.Random -> RandomC;
  SmartBinC.Timer -> Timer;
  SmartBinC.Leds -> LedsC;
}

