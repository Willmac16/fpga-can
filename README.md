# fpga-can
A CAN 2.0B Controller for FPGAs written in Verilog

## Progress
### Minimum Viable Project (an error passive node)
- [x] Sample Sync Machine (Connects directly to rx & tx lines and handles resyncing)
  * [x] Written
  * [x] Test Benched
- [x] Rx Pipeline (Bit Unstuffer)
  * [x] Written
  * [x] Test Benched
- [ ] Tx Pipeline (Bit Stuffer)
  * [ ] Written
  * [ ] Test Benched
- [ ] CRC Machine (Shared between reciever and sender; updates one bit at a time)
  * [x] Written
  * [ ] Rewritten
  * [ ] Test Benched
- [ ] Send Machine (Gets told what to send and when to send it)
  * [ ] Written
  * [ ] Test Benched
- [ ] Message Reciever (Takes in the rx pipeline and keeps track of the buses current state)
  * [x] Written
  * [ ] Integrated with all the changes I made since I wrote it
  * [ ] Test Benched
- [ ] Message Sender (Takes in a msg id and up to 8 bytes and constructs & sends a CAN frame)
  * [ ] Written
  * [ ] Test Benched
  

### More Features I want to finish (to meet the whole spec)
- [ ] Error Counting Machine
  * [ ] Written
  * [ ] Test Benched

## Usage
Test benches can be run with `iverilog -o tb tb.v can.v; vvp tb -lxt2` and viewed with gtkwave.

Source Code should be easy to add into an existing verilog project **once its done**.
