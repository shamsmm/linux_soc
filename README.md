# RISC-V SoC (Synthesis on Gowin FPGA)
## What is this repository and it's structure
### What?
This is the repo containing JTAG transport layer, top module for the FPGA I use, GPIO for the processor using FPGA IP-cores and submodules to all other parts

### Structure

## Features
### Completed
- Hazard-free pipelined RISC-V (5 stages with data forwarding)
- Synthesisable System Verilog (more readable)
- Simple Bus Interface (easy to add more peripherals)
- JTAG Debug Transport
- CLIT interrupts
### In-progress
- JTAG Debug Module
- Interrupts from PLIC
### To-Do
- M extension (RISC-V spec.)
- AMO extension (RISC-V spec.)
- Branch prediction
- UART
- MMU

## JTAG Example
Example JTAG connection to SoC using RaspberryPi Zero as poor man's JTAG debugger

```shell
sudo openocd -f pi_jtag.cfg
```

```text
Open On-Chip Debugger 0.12.0+dev-01998-g744955e5b (2025-05-15-21:44)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
Info : BCM2835 GPIO JTAG/SWD bitbang driver
Info : clock speed 997 kHz
Info : JTAG tap: mychip.tap tap/device found: 0x1beef001 (mfg: 0x000 (<invalid>), part: 0xbeef, ver: 0x1)
```

## GCC Helpful Commands
1. See compiled/assembled code using non-pseudoinstruction (in `objdump`)
    ```
    --disassembler-options=no-aliases
    ```

```
riscv64-unknown-elf-objdump --disassembler-options=no-aliases -D test.elf
```

## OpenOCD Hlpful COmmands
```
jtag arp_init
irscan auto0.tap 0x11
drscan auto0.tap 41 0x04200000002
```

## Misc
ChatGPT wasted 4 days of my life because it couldn't concatenate numbers.
```
iverilog -o sim concat.v && vvp sim
```

## Important
DTM has a version
DM has a version
both independently so OpenOCD may break if not correct in hardware

## Milestones

OpenOCD successfully examining my core

```text
debug_level: 1
Warn : [riscv.cpu] We won't be able to execute fence instructions on this target. Memory may not always appear consistent. (progbufsize=0, impebreak=0)
[riscv.cpu] Target successfully examined.
```