module top (
    input rst,
    input rx_raw,
    input tx_raw,
    input clk
);
    reg [6:0] RJW = 5;
    wire bus_idle;

    sync_sample_machine ssm (
        .rx_raw(rx_raw),
        .clk(clk),
        .RJW(RJW),
        .bus_idle(bus_idle),
        .rx(rx)
    );



endmodule

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
    output reg tx,
    output reg bit_advance
);
    reg [4:0] stuff_history;
    reg [4:0] history_valid;


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

// // State Machine Updated once per bit
// module mesage_reciever(
//     input updated_sample,
//     input rx,
//     input stuff_error,
//     output reg [28:0] msg_id,
//     output reg rtr,
//     output reg extended,
//     output reg [63:0] msg,
//     output reg msg_error,
//     output reg bus_idle,
//     output reg stop_de_stuff,
//     output reg FORM_ERROR,
//     output reg OVERLOAD,
//     output reg fire_an_ack
// );
//     reg [14:0] crc_recieved;
//     wire [14:0] crc_computed;
//     reg update_crc;
//     reg [5:0] state = 0;

//     reg [3:0] DLC;
//     reg [3:0] bit_counter;

//     integer msg_size;
//     integer id_bit;
//     integer crc_bit;

//     crc_step_machine crcer (.next_bit(rx), .update_crc(update_crc), .clear_crc(state == 0), .crc(crc_computed));

//     always @(posedge stuff_error)
//         state <= 31;

//     always @(posedge updated_sample) begin
//         case (state)
//             0: begin // Idle / SOF
//                 if (rx) begin
//                     state <= 1;
//                     bus_idle <= 0;
//                     msg_size <= 0;
//                     msg_id <= 0;
//                     id_bit <= 28;
//                     extended <= 28;
//                     stop_de_stuff <= 0;
//                     FORM_ERROR <= 0;
//                     throw_after_ack <= 0;
//                 end
//             end
//             1: begin // Base ID
//                 msg_id[id_bit] <= rx;
//                 id_bit <= id_bit - 1;

//                 if (id_bit == 21)
//                     state <= 2;
//                 else if (id_bit == 0)
//                     state <= 2;
//             end
//             2: begin // RTR / SRR
//                 rtr <= rx;

//                 state <= extended ? 4 : 3; // R1 or IDE
//             end
//             3: begin // IDE
//                 extended <= !rx;
//                 state <= rx ? 5 : 1; // R0 or Finish ID
//             end
//             4, // R1
//             5: // R0
//                 state <= state + 1;
//             6, // DLC 3
//             7, // DLC 2
//             8: begin // DLC 1
//                 DLC[state - 7] <= rx;
//                 state <= state + 1;
//             end
//             9: begin // DLC 0
//                 DLC[0] = rx;
//                 DLC &= DLC[0] ? 4'b1000 : 4'b0111; // Cap at 8 bytes
//                 state = DLC == 0 ? 10 : 11; // Data or CRC
//                 msg_size = DLC * 8;
//                 bit_counter <= 4'hf;
//                 DLC = DLC - 1; // So my indexing works
//             end
//             10: begin // Data
//                 update_crc <= 1;
//                 bit_counter <= bit_counter - 1;
//                 DLC <= DLC - (bit_counter == 0);

//                 msg[DLC * 8 + bit_counter] <= rx;

//                 if (bit_counter == 0 && DLC == 0) begin
//                     crc_bit <= 14;
//                     state <= 11;
//                 end
//             end
//             11: begin // CRC
//                 crc[crc_bit] <= rx;
//                 crc_bit <= crc_bit - 1;
//                 if (crc_bit == 0)
//                     state <= 12;
//             end
//             12: begin // CRC Delim
//                 state <= 13;

//                 FORM_ERROR <= rx;
//                 stop_de_stuff <= 1;
//                 // Arm the ACK
//                 fire_an_ack <= crc == crc_computed;
//                 throw_after_ack <= !fire_an_ack;
//             end
//             13: begin // ACK Slot
//                 fire_an_ack <= 0;

//                 state <= rx ? 14: 31;

//                 FORM_ERROR <= !rx;
//             end
//             14: begin // ACK Delim
//                 state <= rx | throw_after_ack ? 31 : 15;

//                 FORM_ERROR <= rx | throw_after_ack;
//             end
//             15, // EOF 1
//             16, // EOF 2
//             17, // EOF 3
//             18, // EOF 4
//             19, // EOF 5
//             20, // EOF 6
//             21: // EOF 7
//             begin
//                 state <= rx ? 31: state + 1;

//                 FORM_ERROR <= rx;
//             end
//             22, // Intermission 1
//             23: // Intermission 2
//             begin
//                 state <= rx ? 30: state + 1;

//                 OVERLOAD <= rx;
//             end
//             24: begin // Intermission 3
//                 // Collapse into state 0 with a check?
//                 if (rx) begin
//                     state <= 1;
//                     bus_idle <= 0;
//                     msg_size <= 0;
//                     msg_id <= 0;
//                     id_bit <= 28;
//                     extended <= 28;
//                     stop_de_stuff <= 0; // Really need to make sure bit stuffing alarm works
//                     FORM_ERROR <= 0;
//                     OVERLOAD <= 0;
//                     throw_after_ack <= 0;
//                 end
//             end
//             30, // Overload Packet
//             31: begin // Form Error
//                 state <= rx ? 31 : 32;
//             end
//             32, // Error Delim 2
//             33, // Error Delim 3
//             34, // Error Delim 4
//             35, // Error Delim 5
//             36, // Error Delim 6
//             37: // Error Delim 7
//             begin
//                 state <= rx ? 31 : state + 1;
//             end
//             38: // Error Delim 8
//             begin
//                 state <= rx ? 31 : 22;

//                 FORM_ERROR &= rx;
//                 OVERLOAD_ERROR &= rx;
//             end
//         endcase
//     end
// endmodule

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
