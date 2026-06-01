# Opt Pipe
An optional pipeline delay

## I/O
| Port Name | Direction | Type | Description |
|:---------:|:---------:|:----:|:-----------|
| `CLK` | `input` | `logic` | Clock |
| `nRST` | `input` | `logic` | Active-low asynchronous reset |
| `ready` | `input` | `logic` | Ready handshake signal |
| `in` | `input` | `logic [WIDTH-1:0]` | Input value to delay |
| `done` | `output` | `logic` | Delayed ready signal |
| `out` | `output` | `logic [WIDTH-1:0]` | Delayed input signal |

## Function
Puts a value from `in` on `out` after `NUM_STAGES` cycles. If `NUM_STAGES ==
0`, then it directly connects `in` and `out`. The `ready` and `done` handshake
signals operate similarly.

## Parameters
| Parameter     | Type | Description | Default Value | Valid Range |
|:---------------:|:------:|:-------------|:---------------:|:-------------:|
| `WIDTH` | `int` | Number of bits of input signal | NA | >= 1 |
| `NUM_STAGES` | `int` | Number of cycles to delay signal | NA | >= 0 |
