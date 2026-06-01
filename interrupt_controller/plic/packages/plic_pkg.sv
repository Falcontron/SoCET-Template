`ifndef PLIC_PKG_SV
`define PLIC_PKG_SV

package plic_pkg;
    typedef enum logic [1:0] {
        ACTIVE_HIGH,
        ACTIVE_LOW,
        RISING_EDGE,
        FALLING_EDGE
    } interrupt_trigger_e;
endpackage

`endif
