INSTRUCTIONS
------------

FOLDER CONTENT:

Makefile 
It contains the compile instructions, including the mig command to automatically generate the Java class to interface with serial messages coming from the sensor, and the javac command to compile the Java program to read messages.

TestSerialAppC.nc, TestSerialC.nc, TestSerial.h
They contain the implementation of the TinyOS program that sends messages through the serial interface

TestSerial.java 
Implementation of the program to read messages from the serial port

RunSimulationScript.py
Python script to simulate the sensor node that sends messages through the serial interface. 

HOW TO USE IT:

1. compile the tinyos program for simulation using the serial port, typing
	make micaz sim-sf
2. open the serial forwarder on port 9001 typing
	java net.tinyos.sf.SerialForwarder -comm sf@localhost:9001&
3. run the java program that accepts messages from the serial port 9002
	java TestSerial -comm sf@localhost:9002
4. run the python simulation
	python RunSimulationScript.py




