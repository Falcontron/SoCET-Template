# AFTx07 Memory Map

### NOTE: Memory Map is still subject to change! Specifically, peripheral counts/locations!

| Range | Bus | Peripheral |
--------|-----|------------|
| 0x0 - 0xFF | AHB | Boot ROM |
| 0x100 - 0x1FF | AHB | Boot RAM |
| 0x200 - 0x83FF | - | Reserved |
| 0x8400 - 0x183FF | AHB | Off-chip SRAM |
| 0x18400 - 0x7FFFFFFFF | - | Reserved |
| 0x80000000 - 0x80000FFF | APB | GPIO0 |
| 0x80001000 - 0x80001FFF | APB | PWM0 |
| 0x80002000 - 0x80002FFF | APB | Timer0 |
| 0x80003000 - 0x80003FFF | APB | Reserved |
| 0x80004000 - 0x80004FFF | APB | SPI0 |
| 0x80005000 - 0x80005FFF | APB | I/O Mux |
| 0x80006000 - 0x8FFFFFFF | - | Reserved |
| 0x90000000 - 0x90000FFF | AHB | CLINT |
| 0x90001000 - 0x90001FFF | AHB | DMA |
| 0x90002000 - 0x9FFFFFFF | - | Reserved |
| 0xA0000000 - 0xA0000FFF | AHB | PLIC |
| 0xA0001000 - 0xFFFFFFFF | - | Reserved |
