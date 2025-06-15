# JTAG
Example JTAG connection to SoC using RaspberryPi
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
