#ifndef SMARTBIN_H
#define SMARTBIN_H

//payload of the msg
typedef nx_struct my_msg {
	nx_uint8_t msg_type; //request or response
	nx_uint16_t msg_id;
	nx_uint16_t value;
} my_msg_t;

typedef nx_struct my_bin {
	nx_uint8_t msg_type; 
	nx_uint16_t msg_id;
	nx_uint16_t value;
} my_node;

#define REQ 1
#define RESP 2 
#define RANDOM_IN_30 29000
#define RANDOM_IN_10 9

enum{
AM_MY_MSG = 6,
};

#endif
