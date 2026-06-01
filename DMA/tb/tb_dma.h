// sv testbench: `timescale 1ns / 10ps

// #ifndef const int_H
// #define const int_H

// const int CLK_PERIOD = 10;
// const int BUS_DELAY  = 800; // ps, Based on FF propagation delay

// // Sizing related constants
// const int DATA_WIDTH      = 1;
// const int ADDR_WIDTH      = 32;
// const int DATA_WIDTH_BITS = DATA_WIDTH * 8;
// const int DATA_MAX_BIT    = DATA_WIDTH_BITS - 1;
// const int ADDR_MAX_BIT    = ADDR_WIDTH - 1;

// // Define our address mapping scheme via constants
// const int ADDR_STATUS      = 0;
// const int ADDR_STATUS_BUSY = 0;
// const int ADDR_STATUS_ERR  = 1;
// const int ADDR_RESULT      = 2;
// const int ADDR_SAMPLE      = 4;
// const int ADDR_COEF_START  = 6;  // F0
// const int ADDR_COEF_SET    = 14; // Coeff Set Confirmation

// const int IDLE = 0;
// const int NON_SEQ = 0b10;
// const int SEQ = 0b11;

// const int SAR = 0x7FFF0004; //Source Address Register
// const int DAR = 0x7FFF0008; //Destination Address Register
// const int TSR = 0x7FFF000C; //Transfer Size Register
// const int CR = 0x7FFF0010; //Control Register

// #endif /* LOCALPARAM_H */