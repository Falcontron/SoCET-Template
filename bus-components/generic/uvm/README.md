# UVM Agent for SoCET Generic Bus Interface

This folder contains an implementation of a UVM agent for interacting with SoCET's generic `bus_protocol_if`. The agent contains both a driver and monitor, writing and reading sequence items evey clock cycle as defined by the testbench clock.

The agent assumes the existence of a virtual `bus_if` instance with the name "bus_vif" that packages a `bus_protocol_if` instance with `clk` and `n_rst` signals that should be the same clock and reset driven to the DUT. Monitored transactions are sent out via the monitor's analysis port - connect to the agent object's `.mon.bus_ap` in your environment.

The full UVM testbench in this folder uses a parameterizable scratchpad flip-flop RAM module.

## Files / Classes
* `bus_if.svh` defines the `bus_if` interface that contains the `clk`, `n_rst`, and `bus_protocol_if` instance to be connected to the DUT.
* `bus_transaction.svh` defines the `bus_transaction` class that is used by sequences to tell the driver how to drive the `bus_protocol_if` signals and is used by the monitor to capture the input and output signals on the interface and send that information to a predictor or scoreboard. It also contains an example set of constraints to be used when randomizing the signals marked `rand`.
* `bus_sequences.svh` defines multiple sequences of sequence items to be sent to the driver. Tests call a sequence's `.start(<sequencer>)` method.
* `bus_agent/bus_agsnt.svh` defines the `bus_agent` class that contains a sequencer, driver, and monitor.
* `bus_agent/bus_sequencer.svh` defines the `bus_sequencer` class that handles passing sequence items (`bus_transaction` items) to the `bus_driver`.
* `bus_agent/bus_monitor.svh` defines the `bus_monitor` class that monitors the `bus_protocol_if` input and output signals every clock cycle and writes the captured `bus_transaction` to its analysis port: `bus_ap`.
* `bus_agent/bus_driver.svh` defines the `bus_driver` class that drives the `bus_protocol_if` input signals every clock cycle that it receives a sequence item.
