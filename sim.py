import sys;
import time;

from TOSSIM import *;

t = Tossim([]);
out = sys.stdout;

#Add debug channel
print "Activate debug message on channel SmartBinC"
t.addChannel("SmartBinC",out);
print "Activate debug message on channel init"
t.addChannel("init",out);
print "Activate debug message on channel boot"
t.addChannel("boot",out);
print "Activate debug message on channel radio"
t.addChannel("radio",out);
print "Activate debug message on channel radio_send"
t.addChannel("radio_send",out);
print "Activate debug message on channel radio_ack"
t.addChannel("radio_ack",out);
print "Activate debug message on channel radio_rec"
t.addChannel("radio_rec",out);
print "Activate debug message on channel radio_pack"
t.addChannel("radio_pack",out);
print "Activate debug message on channel role"
t.addChannel("role",out);

print "Creating node 1...";
node1 = t.getNode(1);
time1 = 0*t.ticksPerSecond(); #instant at which each node should be turned on
node1.bootAtTime(time1);
print ">>>Will boot at time",  time1/t.ticksPerSecond(), "[sec]";

print "Start simulation with TOSSIM! \n\n\n";

for i in range(0,1000):
	t.runNextEvent()
	
print "\n\n\nSimulation finished!";
