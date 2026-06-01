# DMA Module

### Setup
1. Install FuseSoC: https://fusesoc.readthedocs.io/en/stable/user/installation.html#ug-installation
2. Ensure you've configured the repository by running `./setup.sh`.
   This script will:
      install the Fusesoc digital libraries
      install the git pre-commit hook

### Simulation

Build and run Verilator simulation:
```
fusesoc --cores-root . run --target sim socet:aft:dma
```

View Verilator simulation waveform with preset signal list:
```
gtkwave build/socet_aft_dma_0.1.0/sim-verilator/dma_trace.vcd dma_wave_v1.gtkw
```



