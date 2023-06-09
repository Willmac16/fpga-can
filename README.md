# fpga-can

A CAN 2.0B Controller for FPGAs written in Verilog

Small enough that it'll fit on an ICE 40 (~700 LUTs for a minimal transceiver).

## Progress

### Minimum Viable Project (an error passive node)

* [x] Sample Sync Machine (Connects directly to rx & tx lines and handles resyncing)
  * [x] Written
  * [x] Test Benched
* [x] Rx Pipeline (Bit Unstuffer)
  * [x] Written
  * [x] Test Benched
* [x] Tx Pipeline (Bit Stuffer)
  * [x] Written
  * [x] Test Benched
* [x] CRC Machine (Same for Receiver and Sender)
  * [x] Written
  * [x] Rewritten
  * [x] Test Benched
* [x] Send Machine (Gets told what to send and when to send it)
  * [x] Written
  * [x] Test Benched
* [x] Message Reciever (Takes in the rx pipeline and keeps track of the buses current state)
  * [x] Written
  * [x] Integrated with all the changes I made since I wrote it
  * [x] Test Benched
  * [ ] Add all the error counting triggers
* [x] Message Sender (Takes in a msg id and up to 8 bytes and constructs & sends a CAN frame)
  * [x] Written
  * [x] Test Benched
* [ ] Tested and Ready to go on actual hardware
  * [x] Zero Warnings Synthesis
  * [x] Passes Test Benches with Changes
  * [x] Hardware implementation confirmed by logic analyzer
* [ ] Configurable Msg Latch
  * [ ] Written
* [ ] Configurable Msg FIFO
  * [ ] Written
  * [ ] Test Benched

### More Features I want to finish (to meet the whole spec)

* [ ] Error Counting Machine
  * [ ] Written
  * [ ] Test Benched

## Usage

Test benches can be run with `iverilog -o tb tb.v can.v; vvp tb -lxt2` and viewed with gtkwave.

Source Code should be easy to add into an existing verilog project **once its done**.
