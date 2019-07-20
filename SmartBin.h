#ifndef SMARTBIN_H
#define SMARTBIN_H

//payload of the msg
typedef nx_struct my_msg {
	nx_uint8_t msg_type; //request or response
	nx_uint16_t bin_id;
	nx_uint16_t coordX;
	nx_uint16_t coordY;
	nx_uint16_t trashInEccess;
} my_msg_t;

#define ALERT 1
#define TRUCK 2
#define MOVE 3
#define RESP_MOVE 4
#define TRASH_MOVE 5
#define RANDOM_IN_30 29000
#define RANDOM_IN_10 9
#define aplhaBin_Bin 0.05
#define alphaBin_Truck 1
#define MAX_COORDINATE_X 30
#define MAX_COORDINATE_Y 30

enum{
AM_MY_MSG = 6,
};

#endif