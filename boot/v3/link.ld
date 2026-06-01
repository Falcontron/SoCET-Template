MEMORY
{
    ROM(rx) : ORIGIN = 0x400, LENGTH = 1K
    RAM(rw) : ORIGIN = 0x8400, LENGTH = 8K
}

ENTRY(boot);

SECTIONS
{
    .text :
    {
        *(.text.boot)
        *(.text .text.*)
    } > ROM

    .preinit_array :
    {
        PROVIDE(__preinit_array_start = .);
        KEEP(*(SORT_BY_INIT_PRIORITY(.preinit_array)));
        PROVIDE(__preinit_array_end = .);
    } > ROM

    .init_array :
    {
        PROVIDE(__init_array_start = .);
        KEEP(*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
        KEEP(*(.init_array .ctors));
        PROVIDE(__init_array_end = .);
    } > ROM

    .fini_array :
    {
        PROVIDE(__fini_array_start = .);
        KEEP(*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)));
        KEEP(*(.fini_array .dtors));
        PROVIDE(__fini_array_end = .);
    } > ROM

    .rodata :
    {
        *(.rodata .rodata.*)
    } > ROM

    
    .data :
    {
        *(.data .data.*)
        *(.sdata .sdata.*)
        *(.eh_frame .eh_frame.*)
    } > RAM AT>ROM
    
    PROVIDE(_edata = .);

    PROVIDE(__bss_start = .);
    .bss : 
    {
        *(.sbss .sbss.*)
        *(.bss .bss.*)
    } > RAM
    PROVIDE(__bss_end = .);
    PROVIDE(_end = .);
    PROVIDE(__global_pointer$ = .);
    PROVIDE(__stack_top = ORIGIN(RAM) + LENGTH(RAM));
}
