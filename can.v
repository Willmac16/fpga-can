// module top (
//     input rst,
//     input rx_raw,
//     input tx_raw,
//     input clk
// );
//     reg [6:0] RJW = 5;
//     wire bus_idle;

//     sync_sample_machine ssm (
//         .rx_raw(rx_raw),
//         .clk(clk),
//         .RJW(RJW),
//         .bus_idle(bus_idle),
//         .rx(rx)
//     );
// endmodule

module sync_sample_machine(
    input rx_raw,
    input clk,
    input [6:0] RJW,
    input bus_idle,
    output reg rx,
    output reg sync_tick,
    output reg updated_sample
);

    reg [8:0] current_quantum = 0;
    reg [6:0] prop_seg = 19;
    reg [6:0] phase_seg_one = 40;
    reg [6:0] phase_seg_two = 40;


    reg [8:0] cycle_length;

    always @(prop_seg, phase_seg_one, phase_seg_two)
        cycle_length <= prop_seg + phase_seg_one + phase_seg_two + 1;

    // Synchronization
    always @(rx_raw) begin
        if (bus_idle)
            current_quantum <= 0; // Hard Sync
        else begin
            if (current_quantum < RJW)
                current_quantum <= 0; // Resync Smaller than Jump width
            else if (cycle_length - current_quantum < RJW)
                current_quantum <= 0; // Resync Smaller than Jump width
            else if (current_quantum > 1 + prop_seg + phase_seg_one)
                phase_seg_one <= phase_seg_two - RJW; // Positive Phase error correction
            else
                phase_seg_two <= phase_seg_two + RJW; // Negative Phase error correction
        end
    end

    // Sampling
    always @(posedge clk) begin
        if (current_quantum >= cycle_length) begin
            current_quantum <= 0;
            sync_tick <= 1;
        end else begin
            current_quantum <= current_quantum + 1;
            sync_tick <= 0;
        end

        if (current_quantum == 1 + prop_seg + phase_seg_one) begin
            rx <= rx_raw;
            updated_sample <= 0;

        end else
            updated_sample <= 1; // Wait a tick to flag the sample update
    end
endmodule

module rx_pipeline(
    input rx,
    input updated_sample,
    input stuff_bypass,
    output reg updated_bit,
    output reg next_bit,
    output reg stuff_error
);
    reg [5:0] stuff_history;
    reg [5:0] history_valid;


    always @(posedge stuff_bypass) begin
        stuff_history <= 0;
        history_valid <= 0;
        stuff_error <= 0;
        updated_bit <= 0;
    end


    // bit [5] in history gets returned or latest bit
    always @(posedge updated_sample) begin
        if (stuff_bypass) begin
            next_bit <= rx;
            updated_bit <= 1;
        end else begin
            // These Shifts need to be blocking so the later logic works
            stuff_history = {rx, stuff_history[5:1]};
            history_valid = {1'b1, history_valid[5:1]};

            if (history_valid == 6'b111111) begin
                if (stuff_history == 6'b111111)
                    stuff_error <= 1;
                else if (stuff_history == 6'b000000)
                    stuff_error <= 1;
                else begin
                    if (stuff_history[4:0] == 5'b11111 || stuff_history[4:0] == 5'b00000) begin
                        // Next bit is stuffed: dont return anything
                    end else begin
                        // Next bit isn't stuffed: return the bit
                        next_bit <= stuff_history[5];
                        updated_bit <= 1;
                    end
                end
            end else begin
                // We don't know enough yet to unstuff
                next_bit <= stuff_history[5];
                updated_bit <= 1;
            end
        end
    end

    always @(negedge updated_sample) begin
        updated_bit <= 0;
    end
endmodule

module tx_pipeline(
    input next_bit,
    input updated_sample,
    input stuff_bypass,
    input running_start,
    output reg tx,
    output reg bit_advance
);
    reg [4:0] stuff_history;
    reg [4:0] history_valid;

    always @(posedge running_start) begin
        stuff_history <= 5'b10000;
        history_valid <= 5'b10000;
        bit_advance <= 1;
    end


    always @(posedge stuff_bypass) begin
        stuff_history <= 0;
        history_valid <= 0;
        bit_advance <= 0;
    end


    // bit [4] in history gets returned or latest bit
    // This fires when the next bit gets read by the ssm machine
    // so the send machine is ready @ sync
    always @(posedge updated_sample) begin
        if (stuff_bypass) begin
            tx <= next_bit;
            bit_advance <= 1;
        end else begin
            history_valid <= {1'b1, history_valid[4:1]};

            // Until we have five bits of history, the next bit is just returned
            if (history_valid != 5'b11111) begin
                stuff_history <= {next_bit, stuff_history[4:1]};
                tx <= next_bit;
                bit_advance <= 1;
            end else begin
                // With full history, we need to deal with stuffing
                // If all the bits are the same, we need to stuff the next bit and not ask for a new one
                if ((stuff_history == 5'b00000) || (stuff_history == 5'b11111)) begin
                    tx <= !stuff_history[4];
                    stuff_history <= {!stuff_history[4], stuff_history[4:1]};
                    bit_advance <= 0;
                end else begin
                    // Otherwise return the next bit and add it to history
                    tx <= next_bit;
                    stuff_history <= {next_bit, stuff_history[4:1]};
                    bit_advance <= 1;
                end
            end
        end
    end

    always @(negedge updated_sample) begin
        bit_advance <= 0;
    end
endmodule


// module bit_error_machine(
//     input rx,
//     input tx,
//     input sample_update,
//     output reg agrement
// );
//     always @(posedge sample_update)
//         agrement = rx ^ tx;
// endmodule

// module send_machine(
//     input out_bit,
//     input send_tick,
//     input bit_error,
//     output reg tx_wire
// );
//     always @(posedge send_tick) begin
//         if (!bit_error)
//             tx_wire = out_bit;
//         else
//             tx_wire = 0;
//     end
// endmodule

// module error_machine(
//     input FORM_ERROR,
//     input OVERLOAD,
//     input NEVER_BEEN_ACKED,
//     input transmitting,
//     output reg error_passive,
//     output reg bus_off
// );
//     reg [9:0] transmit_error_count = 0;
//     reg [9:0] recieve_error_count = 0;

//     // always @(posedge FORM_ERROR) begin

//     // end

//     // TODO: Implement Error Counts
// endmodule

// State Machine Updated once per bit
module message_reciever(
    input updated_sample,
    input rx,
    input stuff_error,
    output reg [28:0] msg_id,
    output reg rtr,
    output reg extended,
    output reg [63:0] msg,
    output reg [3:0] msg_bytes,
    output reg bus_idle,
    output reg stuff_bypass,
    output reg FORM_ERROR,
    output reg OVERLOAD_ERROR,
    output reg fire_an_ack,
    output reg msg_fresh,
    output reg running_start,
    output reg transmission_error
);
    reg [14:0] crc_recieved;
    wire [14:0] crc_computed;
    reg update_crc, clear_crc;
    reg [5:0] state = 0;

    reg [3:0] DLC;
    reg [5:0] bit_counter;

    reg throw_after_ack;

    reg [4:0] id_bit;
    reg [3:0] crc_bit;

    crc_step_machine crcer (.next_bit(rx), .update_crc(update_crc), .clear_crc(clear_crc), .crc(crc_computed));

    always @(posedge stuff_error)
        state <= 31;

    always @(posedge updated_sample) begin
        case (state)
            0: begin // Idle / SOF
                if (rx) begin
                    state <= 1;
                    bus_idle <= 0;
                    msg_id <= 0;
                    id_bit <= 28;
                    extended <= 28;
                    stuff_bypass <= 0;
                    FORM_ERROR <= 0;
                    throw_after_ack <= 0;
                    msg_fresh <= 0;
                    clear_crc = 1;
                    update_crc <= 1;
                    running_start <= 0;
                    transmission_error <= 0;
                end
            end
            1: begin // Base ID
                clear_crc <= 0;

                update_crc <= 1;

                msg_id[id_bit] <= rx;
                id_bit <= id_bit - 1;

                if (id_bit == 18 || id_bit == 0)
                    state <= 2;
            end
            2: begin // RTR / SRR
                update_crc <= 1;

                rtr <= rx;

                state <= extended ? 4 : 3; // R1 or IDE
            end
            3: begin // IDE
                update_crc <= 1;

                extended <= !rx;
                state <= rx ? 5 : 1; // R0 or Finish ID
            end
            4, // R1
            5: begin // R0
                update_crc <= 1;

                state <= state + 1;
            end
            6, // DLC 3
            7, // DLC 2
            8: begin // DLC 1
                update_crc <= 1;

                DLC[9 - state] <= rx;
                state <= state + 1;
            end
            9: begin // DLC 0
                update_crc <= 1;

                DLC[0] = rx;
                DLC &= (DLC[3] ? 4'b1000 : 4'b0111); // Cap at 8 bytes
                msg_bytes <= DLC;
                state <= (DLC == 0) ? 11 : 10; // CRC or Data

                if (DLC != 0) begin
                    bit_counter[5:3] <= DLC - 1;
                    bit_counter[2:0] <= 3'b111;
                end

                crc_bit <= 14;
            end
            10: begin // Data
                update_crc <= 1;
                bit_counter <= bit_counter - 1;

                msg[bit_counter] <= rx;

                state <= bit_counter == 0 ? 11 : 10;
            end
            11: begin // CRC
                crc_recieved[crc_bit] <= rx;
                crc_bit <= crc_bit - 1;
                if (crc_bit == 0) begin
                    state <= 12;
                    stuff_bypass <= 1; // Disable stuffing now that the CRC is done
                end
            end
            12: begin // CRC Delim
                state <= rx ? 31 : 13;

                FORM_ERROR <= rx;
                // Arm the ACK
                fire_an_ack <= crc_recieved == crc_computed;
                throw_after_ack <= crc_recieved != crc_computed;
            end
            13: begin // ACK Slot
                fire_an_ack <= 0;

                state <= rx ? 14 : 31;

                FORM_ERROR <= !rx;
            end
            14: begin // ACK Delim
                state <= (rx | throw_after_ack) ? 31 : 15;

                FORM_ERROR <= rx | throw_after_ack;
            end
            15, // EOF 1
            16, // EOF 2
            17, // EOF 3
            18, // EOF 4
            19, // EOF 5
            20: // EOF 6
            begin
                state <= rx ? 31: state + 1;

                FORM_ERROR <= rx;

                msg_fresh <= !rx & state == 20; // Only set msg_fresh if we are in the last EOF
            end
            21: // EOF 7
            begin
                // Tell our transmitter there is an issue
                transmission_error <= 1;
                state <= 22;
            end

            22, // Intermission 1
            23: // Intermission 2
            begin
                state <= rx ? 30: state + 1;

                OVERLOAD_ERROR <= rx;
            end
            24: begin // Intermission 3
                // Crystal Oscillator Tollerancing Change from 2.0 spec
                if (rx) begin
                    state <= 1;
                    bus_idle <= 0;
                    msg_id <= 0;
                    id_bit <= 28;
                    extended <= 28;
                    stuff_bypass <= 0; // Really need to make sure bit stuffing alarm works
                    FORM_ERROR <= 0;
                    OVERLOAD_ERROR <= 0;
                    throw_after_ack <= 0;
                    msg_fresh <= 0;
                    clear_crc = 1;
                    update_crc <= 1;

                    running_start <= 1; // Fire up the sender machine on the first bit of arb
                    transmission_error <= 0;
                end else
                    state <= 0;
            end
            30, // Overload Packet
            31: begin // Form Error
                state <= rx ? 31 : 32;
            end
            32, // Error Delim 2
            33, // Error Delim 3
            34, // Error Delim 4
            35, // Error Delim 5
            36, // Error Delim 6
            37: // Error Delim 7
            begin
                state <= rx ? 31 : state + 1;
            end
            38: // Error Delim 8
            begin
                state <= rx ? 31 : 22;

                // If rx is low it clears whichever type of error was high
                FORM_ERROR &= rx;
                OVERLOAD_ERROR &= rx;
            end
        endcase
    end

    always @(negedge updated_sample)
        update_crc <= 0;
endmodule

module message_sender(
    input bit_advance,
    input [28:0] msg_id,
    input extended,
    input rtr,
    input restart,
    input [3:0] num_bytes,
    input [63:0] msg,
    input running_start,
    output reg stuff_bypass,
    output reg tx
);
    reg [5:0] state;
    reg [4:0] id_bit;

    wire [3:0] DLC;

    reg [5:0] bit_counter;
    reg [3:0] crc_bit;


    assign DLC = num_bytes & (num_bytes[3] ? 4'b1000 : 4'b0111); // Cap at 8 bytes

    reg update_crc, clear_crc;
    wire [14:0] crc_computed;

    crc_step_machine crcer (.next_bit(tx), .update_crc(update_crc), .clear_crc(clear_crc), .crc(crc_computed));


    always @(posedge restart) begin
        state <= 0;
    end

    always @(posedge running_start) begin
        state <= 1;
        id_bit <= 28;
        stuff_bypass <= 0;

        tx = 1;
        update_crc <= 1;
    end


    // tx assignments need to be blocking so that CRC is computed after the bit updates
    always @(posedge bit_advance) begin
        case (state) // These nums do not match the state machine in the receiver
            0: begin // Start of Frame
                tx = 1;
                state <= 1;
                id_bit <= 28;
                stuff_bypass <= 0;

                update_crc <= 1;
            end
            1: begin // ID
                tx = msg_id[id_bit];
                id_bit <= id_bit - 1;

                if (id_bit == 18)
                    state <= extended ? 2 : 3; // SRR or RTR
                else if (id_bit == 0)
                    state <= 3; // RTR

                update_crc <= 1;
            end
            2: begin // SRR
                tx = 0;
                state <= 4; // IDE

                update_crc <= 1;
            end
            3: begin // RTR
                tx = rtr;
                state <= extended ? 5 : 4; // R1 or IDE

                update_crc <= 1;
            end
            4: begin // IDE
                tx = !extended;
                state <= extended ? 1 : 5; // ID or R1

                update_crc <= 1;
            end
            5: begin // R1
                tx = 1;
                state <= 6; // R0

                update_crc <= 1;
            end
            6: begin // R0
                tx = 0;
                state <= 7; // DLC 3

                update_crc <= 1;
            end



            7, // DLC 3
            8, // DLC 2
            9: begin // DLC 1
                tx <= DLC[10 - state];
                state <= state + 1;
            end
            10: begin // DLC 0
                tx <= DLC[0];
                state <= (DLC == 0) ? 12 : 11; // CRC or Data

                if (DLC != 0) begin
                    bit_counter[5:3] <= DLC - 1;
                    bit_counter[2:0] <= 3'b111;
                end

                crc_bit <= 14;
            end
            11: begin // Data
                bit_counter <= bit_counter - 1;

                tx <= msg[bit_counter];

                state <= bit_counter == 0 ? 12 : 11; // CRC or More Data
            end
            12: begin // CRC
                tx <= crc_computed[crc_bit];
                crc_bit <= crc_bit - 1;

                state <= crc_bit == 0 ? 13 : 12; // CRC Delim or More CRC
            end
            13: begin // CRC Delim
                tx <= 0;
                state <= 14;

                stuff_bypass <= 1;
            end
            14: begin // ACK Slot
                tx <= 0;
                state <= 15;
            end
            15: begin // ACK Delim
                tx <= 0;
                state <= 16;
            end
            16, // EOF 1
            17, // EOF 2
            18, // EOF 3
            19, // EOF 4
            20, // EOF 5
            21, // EOF 6
            22, // EOF 7
            23, // Intermission 1
            24: begin // Intermission 2
                tx <= 0;
                state <= state + 1;
            end
            25: begin // Intermission 3
                tx <= 0;
                state <= 0;
            end
        endcase
    end

    always @(negedge bit_advance) begin
        update_crc <= 0;
    end
endmodule

module crc_step_machine (
    input next_bit,
    input clear_crc,
    input update_crc,
    output [14:0] crc
);
    assign crc = crc_reg [14:0];

    reg [15:0] crc_reg;

    always @(posedge clear_crc) begin
        crc_reg <= 0;
    end

    always @(posedge update_crc) begin
        // Shift Left
        crc_reg = {crc_reg[14:0], 1'b0};

        if (next_bit ^ crc_reg[15])
            crc_reg[14:0] = crc_reg[14:0] ^ 15'h4599;
    end
endmodule
