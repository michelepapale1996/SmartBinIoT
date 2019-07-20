COMPONENT=SmartBinAppC
BUILD_EXTRA_DEPS += TestSerial.class
CLEAN_EXTRA = *.class SerialMsg.java

CFLAGS += -I$(TOSDIR)/lib/T2Hack

TestSerial.class: $(wildcard *.java) SerialMsg.java
	javac -target 1.4 -source 1.4 *.java

SerialMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=SerialMsg SmartBin.h my_msg -o $@


include $(MAKERULES)

