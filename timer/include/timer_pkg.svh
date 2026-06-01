package timer_pkg;
    typedef enum logic {DISABLED, ENABLED} enable_t;
    typedef enum logic [1:0] {RISING, FALLING, RESERVED, BOTH} polarity_t;
    typedef enum logic [1:0] {OUTPUT, TI1_IN, TI2_IN} direction_t;
    typedef enum logic [2:0] {FROZEN, MATCH_HI, MATCH_LO, TOGGLE, FORCE_LO, FORCE_HI, PWM1, PWM2} outmode_t;

endpackage