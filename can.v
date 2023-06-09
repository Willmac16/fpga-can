module can_transceiver(
    input rx_raw,
    output tx_raw,
    input clk,
    input rst,
    input [28:0] tx_msg_id,
    input tx_rtr,
    input tx_extended,
    input [63:0] tx_msg,
    input [3:0] tx_msg_bytes,
    input tx_msg_exists,
    output [28:0] rx_msg_id,
    output rx_rtr,
    output rx_extended,
    output [63:0] rx_msg,
    output [3:0] rx_msg_bytes,
    output rx_msg_fresh,
    output transmission_error,
    output clean_send,
    output FORM_ERROR,
    output OVERLOAD_ERROR,
    output bus_idle,
    output ssm_sync,
    output yet_to_resync
);
    reg [6:0] RJW = 16;

    // SSM Outs
    wire ssm_rx, ssm_update, ssm_rxp, ssm_rec, ssm_sender, ssm_txp;

    // Receiver Outs
    wire stuff_bypass, fire_an_ack, running_start;

    // rx Pipeline Outs
    wire pipe_rx, pipe_update, stuff_error;

    // Sender Outs
    wire sender_tx, sender_stuff_bypass;

    // tx Pipeline Outs
    wire pipe_tx, pipe_bit_advance;

    // bit error machine Outs
    wire bit_error;

    // running start nonsense
    wire [1:0] txp_running_start;


    sync_sample_machine ssm(
        .rx_raw(rx_raw),
        .tx_raw(tx_raw),
        .clk(clk),
        .rst(rst),
        .RJW(RJW),
        .bus_idle(bus_idle),
        .rx(ssm_rx),
        .sync_tick(ssm_sync),
        .sample_tick(ssm_update),
        .rxp_tick(ssm_rxp),
        .txp_tick(ssm_txp),
        .rec_tick(ssm_rec),
        .sender_tick(ssm_sender),
        .yet_to_resync(yet_to_resync)
    );

    rx_pipeline rx_pipe(
        .clk(clk),
        .rx(ssm_rx),
        .updated_sample(ssm_rxp),
        .stuff_bypass(stuff_bypass),
        .updated_bit(pipe_update),
        .next_bit(pipe_rx),
        .stuff_error(stuff_error)
    );

    message_receiver msg_rec(
        .clk(clk),
        .rec_tick(ssm_rec),
        .updated_sample(pipe_update),
        .rx(pipe_rx),
        .stuff_error(stuff_error),
        .bit_error(bit_error),
        .msg_exists(tx_msg_exists),
        // Message output block
        .msg_id(rx_msg_id),
        .rtr(rx_rtr),
        .extended(rx_extended),
        .msg(rx_msg),
        .msg_bytes(rx_msg_bytes),
        .msg_fresh(rx_msg_fresh),
        // End Message output block
        .bus_idle(bus_idle),
        .stuff_bypass(stuff_bypass),
        .fire_an_ack(fire_an_ack),
        .running_start(running_start),
        .transmission_error(transmission_error),
        .FORM_ERROR(FORM_ERROR),
        .OVERLOAD_ERROR(OVERLOAD_ERROR)
    );

    tx_pipeline tx_pipe(
        .clk(clk),
        .next_bit(sender_tx),
        .stuff_bypass(sender_stuff_bypass),
        .updated_sample(ssm_txp),
        .running_start(txp_running_start),
        .tx(pipe_tx),
        .bit_advance(pipe_bit_advance)
    );

    message_sender msg_send(
        .clk(clk),
        .sender_tick(ssm_sender),
        .bit_advance(pipe_bit_advance),
        // Message input block
        .msg_id(tx_msg_id),
        .rtr(tx_rtr),
        .extended(tx_extended),
        .msg(tx_msg),
        .num_bytes(tx_msg_bytes),
        .msg_exists(tx_msg_exists),
        // End Message input block
        .restart(transmission_error),
        .running_start(running_start),
        .tx(sender_tx),
        .stuff_bypass(sender_stuff_bypass),
        .clean_send(clean_send),
        .txp_running_start(txp_running_start)
    );

    send_machine send(
        .bus_idle(bus_idle),
        .tx_msg_exists(tx_msg_exists),
        .fire_an_ack(fire_an_ack),
        .fire_an_error(1'b0),
        .pipeline_val(pipe_tx),
        .sync_tick(ssm_sync),
        .tx_line(tx_raw)
    );

    bit_error_machine bit_err(
        .rx(rx_raw),
        .tx(tx_raw),
        .sample_update(ssm_update),
        .disagreement(bit_error)
    );
endmodule

module can_receiver(
    input rx_raw,
    output tx_raw,
    input clk,
    input rst,
    output [28:0] msg_id,
    output rtr,
    output extended,
    output [63:0] msg,
    output [3:0] msg_bytes,
    output msg_fresh
);
    reg [6:0] RJW = 5;

    // SSM Outs
    wire ssm_rx, ssm_update, ssm_sync, ssm_rxp, ssm_rec, ssm_sender, ssm_txp;

    // Reciever Outs
    wire bus_idle, stuff_bypass, fire_an_ack;

    // Pipeline Outs
    wire pipe_rx, pipe_update, stuff_error;


    sync_sample_machine ssm(
        .rx_raw(rx_raw),
        .tx_raw(tx_raw),
        .clk(clk),
        .rst(rst),
        .RJW(RJW),
        .bus_idle(bus_idle),
        .rx(ssm_rx),
        .sync_tick(ssm_sync),
        .sample_tick(ssm_update),
        .rxp_tick(ssm_rxp),
        .txp_tick(ssm_txp),
        .rec_tick(ssm_rec),
        .sender_tick(ssm_sender)
    );

    rx_pipeline rx_pipe(
        .clk(clk),
        .rx(ssm_rx),
        .updated_sample(ssm_rxp),
        .stuff_bypass(stuff_bypass),
        .updated_bit(pipe_update),
        .next_bit(pipe_rx),
        .stuff_error(stuff_error)
    );

    message_receiver msg_rec(
        .clk(clk),
        .rec_tick(ssm_rec),
        .updated_sample(pipe_update),
        .rx(pipe_rx),
        .stuff_error(stuff_error),
        .bit_error(1'b0),
        .msg_exists(1'b0),
        // Message output block
        .msg_id(msg_id),
        .rtr(rtr),
        .extended(extended),
        .msg(msg),
        .msg_bytes(msg_bytes),
        .msg_fresh(msg_fresh),
        // End Message output block
        .bus_idle(bus_idle),
        .stuff_bypass(stuff_bypass),
        .fire_an_ack(fire_an_ack)
    );

    send_machine send(
        .bus_idle(bus_idle),
        .tx_msg_exists(1'b0),
        .fire_an_ack(fire_an_ack),
        .fire_an_error(1'b0),
        .pipeline_val(1'b1),
        .sync_tick(ssm_sync),
        .tx_line(tx_raw)
    );
endmodule

module sync_sample_machine(
    input rx_raw,
    input tx_raw,
    input clk,
    input [6:0] RJW,
    input bus_idle,
    input rst,
    output reg rx,
    output reg sync_tick,
    output reg sample_tick,
    output reg rxp_tick,
    output reg rec_tick,
    output reg sender_tick,
    output reg txp_tick,
    output reg yet_to_resync = 1'b1
);

    reg [8:0] current_quantum = 0;
    reg [6:0] prop_seg = 18;
    reg [6:0] phase_seg_one = 40;
    reg [6:0] phase_seg_two = 40;

    reg last_rx_raw;
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            prop_seg <= 18;
            phase_seg_one <= 40;
            phase_seg_two <= 40;

            current_quantum <= 0;

            yet_to_resync <= 1;
        end else if (clk) begin
            // Only sync on recessive to dominant transition of bus not caused by us
            if (!rx_raw & last_rx_raw & tx_raw & yet_to_resync) begin
                if (bus_idle) begin
                    current_quantum <= 0; // Hard Sync
                    sync_tick <= 1;
                    // set all the other ticks to 0
                    sample_tick <= 0;
                    rxp_tick <= 0;
                    rec_tick <= 0;
                    sender_tick <= 0;
                    txp_tick <= 0;
                    yet_to_resync <= 0;
                end else begin
                    yet_to_resync <= 0;
                    if (current_quantum < RJW) begin
                        current_quantum <= 0; // Resync Smaller than Jump width
                    end else if ((prop_seg + phase_seg_one + 1 + phase_seg_two) - current_quantum < RJW)
                        current_quantum <= 0; // Resync Smaller than Jump width
                    else if (current_quantum > 1 + prop_seg + phase_seg_one) begin
                        // Negative Phase Error
                        phase_seg_two <= phase_seg_two - RJW; // Negative Phase error correction
                    end else begin
                        // Positive Phase Error
                        phase_seg_one <= phase_seg_one + RJW; // Positive Phase error correction
                    end
                end
            end else begin
                if (current_quantum >= (prop_seg + phase_seg_one + 1 + phase_seg_two)) begin
                    current_quantum <= 0;
                    sync_tick <= 1;
                    // reset the phase_seg lengths
                    phase_seg_one <= 40;
                    phase_seg_two <= 40;


                    // set all the other ticks to 0
                    sample_tick <= 0;
                    rxp_tick <= 0;
                    rec_tick <= 0;
                    sender_tick <= 0;
                    txp_tick <= 0;
                    yet_to_resync <= 1;
                end else begin
                    current_quantum <= current_quantum + 1;
                    sync_tick <= 0;

                    case (current_quantum - (prop_seg + phase_seg_one))
                        1: begin
                            rx <= rx_raw;
                            sample_tick <= 1;
                        end
                        2: begin
                            rxp_tick <= 1;
                            sample_tick <= 0;
                        end
                        3: begin
                            rec_tick <= 1;
                            rxp_tick <= 0;
                        end
                        4: begin
                            sender_tick <= 1;
                            rec_tick <= 0;
                        end
                        5: begin
                            txp_tick <= 1;
                            sender_tick <= 0;
                        end
                        6:
                            txp_tick <= 0;
                    endcase
                end

                last_rx_raw <= rx_raw;
            end
        end
    end
endmodule

module rx_pipeline(
    input clk,
    input rx,
    input updated_sample,
    input stuff_bypass,
    output reg updated_bit = 0,
    output reg next_bit,
    output reg stuff_error = 0
);
    reg [5:0] stuff_history;
    reg [5:0] history_valid;

    // bit [5] in history gets returned or latest bit
    always @(posedge clk) begin
        if (updated_sample) begin
            if (stuff_bypass) begin
                next_bit = rx;
                updated_bit <= 1;

                stuff_history[5] <= rx;
                history_valid <= 6'b100000;
                stuff_error <= 0;
            end else begin
                // These Shifts need to be blocking so the later logic works
                stuff_history = {rx, stuff_history[5:1]};
                history_valid = {1'b1, history_valid[5:1]};

                if (history_valid == 6'b111111) begin
                    if (stuff_history == 6'b111111) begin
                        stuff_error <= 1;
                        updated_bit <= 0;
                    end else if (stuff_history == 6'b000000) begin
                        stuff_error <= 1;
                        updated_bit <= 0;
                    end else begin
                        if (stuff_history[4:0] == 5'b11111 || stuff_history[4:0] == 5'b00000) begin
                            // Next bit is stuffed: dont return anything
                            updated_bit <= 0;
                        end else begin
                            // Next bit isn't stuffed: return the bit
                            next_bit = stuff_history[5];
                            updated_bit <= 1;
                        end
                    end
                end else begin
                    // We don't know enough yet to unstuff
                    next_bit = stuff_history[5];
                    updated_bit <= 1;
                end
            end
        end
    end
endmodule

module tx_pipeline(
    input clk,
    input next_bit,
    input updated_sample, // This tick is used so the pipeline is ready at the next sync tick
    input stuff_bypass,
    input [1:0] running_start,
    output reg tx = 0,
    output reg bit_advance = 0
);
    reg [4:0] stuff_history;
    reg [4:0] history_valid;

    // Insert SOF that already happened into history and forward the first bit of the id

    // bit [4] in history gets returned or latest bit
    // This fires when the next bit gets read by the ssm machine
    // so the send machine is ready @ sync


    always @(posedge clk) begin
        if (running_start[0]) begin
            stuff_history <= {running_start[1], 4'b0111};
            history_valid <= 5'b11000;

            tx <= running_start[1];
            bit_advance <= 0;
        end else if (updated_sample) begin
            if (stuff_bypass) begin
                stuff_history <= 0;
                history_valid <= 0;
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
    end
endmodule

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

// This single stateless machine handles all the competing interests for the tx line
//
module send_machine(
    input clk,
    input bus_idle, // if the bus is idle & a tx msg is ready this will SOF
    input tx_msg_exists,
    input fire_an_ack,
    input fire_an_error,
    input pipeline_val,
    input sync_tick,
    output reg tx_line
);
    always @(posedge sync_tick) begin
        // Pull low if theres an Error, if not idle and ACK, if idle and a msg exists, or if pipeline val is low
        tx_line <= !fire_an_error & (!fire_an_ack | bus_idle) & (!bus_idle | !tx_msg_exists) & pipeline_val;
    end
endmodule


module bit_error_machine(
    input rx,
    input tx,
    input sample_update,
    output reg disagreement
);
    always @(posedge sample_update)
        disagreement <= rx ^ tx;
endmodule

// State Machine Updated once per bit
module message_receiver(
    input clk,
    input rec_tick,
    input updated_sample,
    input rx,
    input stuff_error,
    input bit_error,
    input msg_exists,
    output reg [28:0] msg_id,
    output reg rtr,
    output reg extended = 0,
    output reg [63:0] msg = 0,
    output reg [3:0] msg_bytes,
    output reg msg_fresh = 0,
    output reg bus_idle = 1,
    output reg stuff_bypass = 1,
    output reg FORM_ERROR = 0,
    output reg OVERLOAD_ERROR = 0,
    output reg fire_an_ack = 0,
    output reg running_start = 0,
    output reg transmission_error = 0,
    output [5:0] state_out
);
    reg [14:0] crc_received = 0;
    wire [14:0] crc_computed;
    reg update_crc = 0, clear_crc = 1;
    reg [5:0] state = 0;

    assign state_out = state;

    reg [3:0] DLC = 0;
    reg [5:0] bit_counter;

    reg throw_after_ack;

    reg [4:0] id_bit;
    reg [3:0] crc_bit;

    crc_step_machine crcer (.clk(clk), .next_bit(rx), .update_crc(update_crc), .clear_crc(clear_crc), .running_start(2'b00), .crc(crc_computed));

    always @(posedge clk) begin
        if (stuff_error) begin
            state <= 31;
            stuff_bypass <= 1;
            transmission_error <= 1;
        end else if (rec_tick && updated_sample) begin
            case (state)
                0: begin // Idle / SOF
                    if (~rx) begin
                        state <= 1;
                        bus_idle <= 0;
                        msg_id <= 0;
                        id_bit <= 28;
                        extended <= 0;
                        stuff_bypass <= 0;
                        FORM_ERROR <= 0;
                        throw_after_ack <= 0;
                        msg_fresh <= 0;
                        clear_crc <= 0;
                        update_crc <= 1;
                        running_start <= 1;
                        transmission_error <= 0;
                        fire_an_ack <= 0;
                    end
                end
                1: begin // Base ID

                    running_start <= 0;

                    update_crc <= 1;

                    msg_id[id_bit] <= rx;
                    id_bit <= id_bit - 1;

                    if (id_bit == 18 || id_bit == 0)
                        state <= 2;

                    transmission_error <= (transmission_error | bit_error) & msg_exists;
                end
                2: begin // RTR / SRR
                    update_crc <= 1;

                    rtr <= rx;

                    state <= extended ? 4 : 3; // R1 or IDE

                    transmission_error <= (transmission_error | bit_error) & msg_exists;
                end
                3: begin // IDE
                    update_crc <= 1;

                    extended <= rx;
                    state <= rx ? 1 : 5; // R0 or Finish ID

                    transmission_error <= (transmission_error | bit_error) & msg_exists;
                end
                4, // R1
                5: begin // R0
                    update_crc <= 1;

                    state <= state + 1;

                    transmission_error <= (transmission_error | bit_error) & msg_exists;
                end
                6, // DLC 3
                7, // DLC 2
                8: begin // DLC 1
                    update_crc <= 1;

                    DLC[9 - state] <= rx;
                    state <= state + 1;

                    transmission_error <= (transmission_error | bit_error) & msg_exists;
                end
                9: begin // DLC 0
                    update_crc <= 1;

                    DLC[0] = rx;
                    DLC <= DLC & (DLC[3] ? 4'b1000 : 4'b0111); // Cap at 8 bytes
                    msg_bytes <= DLC;
                    state <= (DLC == 0 | rtr) ? 11 : 10; // CRC or Data

                    if (DLC != 0 & !rtr) begin
                        bit_counter[5:3] <= DLC - 1;
                        bit_counter[2:0] <= 3'b111;
                    end

                    crc_bit <= 14;

                    transmission_error <= (transmission_error | bit_error) & msg_exists;
                end
                10: begin // Data
                    update_crc <= 1;
                    bit_counter <= bit_counter - 1;

                    msg[bit_counter] <= rx;

                    state <= bit_counter == 0 ? 11 : 10;

                    transmission_error <= (transmission_error | bit_error) & msg_exists;
                end
                11: begin // CRC
                    crc_received[crc_bit] <= rx;
                    crc_bit <= crc_bit - 1;
                    if (crc_bit == 0) begin
                        state <= 12;
                    end

                    transmission_error <= (transmission_error | bit_error) & msg_exists;
                end
                12: begin // CRC Delim
                    state <= ~rx ? 31 : 13;

                    stuff_bypass <= 1; // Disable stuffing now

                    FORM_ERROR <= ~rx;
                    transmission_error <= transmission_error | ~rx;
                    // Arm the ACK if the CRC is good and we aren't actively transmitting
                    fire_an_ack <= (crc_received == crc_computed) && (!msg_exists || transmission_error);
                    throw_after_ack <= crc_received != crc_computed;
                end
                13: begin // ACK Slot
                    fire_an_ack <= 0;

                    state <= ~rx ? 14 : 31;

                    FORM_ERROR <= rx;
                    transmission_error <= transmission_error | rx;
                end
                14: begin // ACK Delim
                    state <= (~rx | throw_after_ack) ? 31 : 15;

                    FORM_ERROR <= ~rx | throw_after_ack;
                    transmission_error <= transmission_error | ~rx;
                end
                15, // EOF 1
                16, // EOF 2
                17, // EOF 3
                18, // EOF 4
                19, // EOF 5
                20: // EOF 6
                begin
                    state <= rx ? state + 1 : 31;

                    clear_crc <= 1;

                    FORM_ERROR <= ~rx;

                    msg_fresh <= rx & state == 20; // Only set msg_fresh if we are in the last EOF
                end
                21: // EOF 7
                begin
                    state <= 22;
                end

                22, // Intermission 1
                23: // Intermission 2
                begin
                    state <= ~rx ? 30: state + 1;

                    OVERLOAD_ERROR <= ~rx;
                end
                24: begin // Intermission 3
                    // Crystal Oscillator Tollerancing Change from 2.0 spec
                    if (~rx) begin
                        state <= 1;
                        bus_idle <= 0;
                        msg_id <= 0;
                        id_bit <= 28;
                        extended <= 0;
                        stuff_bypass <= 0; // Really need to make sure bit stuffing alarm works
                        FORM_ERROR <= 0;
                        OVERLOAD_ERROR <= 0;
                        throw_after_ack <= 0;
                        msg_fresh <= 0;
                        clear_crc <= 0;
                        update_crc <= 1;

                        running_start <= 1; // Fire up the sender machine on the first bit of arb
                        transmission_error <= 0;
                    end else begin
                        state <= 0;
                        bus_idle <= 1;
                    end
                end
                30, // Overload Packet
                31: begin // Form Error
                    fire_an_ack <= 0;
                    state <= rx ? 32 : 31;

                    clear_crc <= 1;
                end
                32, // Error Delim 2
                33, // Error Delim 3
                34, // Error Delim 4
                35, // Error Delim 5
                36, // Error Delim 6
                37: // Error Delim 7
                begin
                    state <= rx ? state + 1 : 31;
                end
                38: // Error Delim 8
                begin
                    state <= rx ? 22 : 31;

                    // If rx is high it clears whichever type of error was high
                    FORM_ERROR <= FORM_ERROR & ~rx;
                    OVERLOAD_ERROR <= OVERLOAD_ERROR & ~rx;
                end
            endcase
        end else begin
            update_crc <= 0;
        end
    end
endmodule

module message_sender(
    input clk,
    input sender_tick,
    input bit_advance,
    input [28:0] msg_id,
    input extended,
    input rtr,
    input restart,
    input [3:0] num_bytes,
    input [63:0] msg,
    input msg_exists,
    input running_start,
    output reg stuff_bypass = 1,
    output reg tx = 1,
    output reg clean_send = 0,
    output [1:0] txp_running_start,
    output [5:0] state_out
);
    reg [5:0] state = 0;
    reg [4:0] id_bit;

    assign state_out = state;

    wire [3:0] DLC;

    reg [5:0] bit_counter;
    reg [3:0] crc_bit;


    assign DLC = num_bytes & (num_bytes[3] ? 4'b1000 : 4'b0111); // Cap at 8 bytes

    reg update_crc = 0, clear_crc = 0;
    reg [1:0] crc_rs = 0;
    wire [14:0] crc_computed;

    assign txp_running_start = crc_rs;

    crc_step_machine crcer (.clk(clk), .next_bit(tx), .update_crc(update_crc), .clear_crc(clear_crc), .crc(crc_computed), .running_start(crc_rs));

    always @(posedge clk) begin
        if (restart) begin
            state <= 0;
            clear_crc <= 1;
            stuff_bypass <= 1;
            tx <= 1;
        end else if (sender_tick) begin
            if (running_start && msg_exists) begin
                state <= 1;
                id_bit <= 26;
                stuff_bypass <= 0;

                // Fire up the CRC and Pipeline
                tx = msg_id[27];
                crc_rs <= {msg_id[28], 1'b1};
            end else begin
                crc_rs <= 0;

                if (!msg_exists) begin
                    state <= 0;
                    clear_crc <= 1;
                    stuff_bypass <= 1;
                    tx <= 1;
                end else if (bit_advance) begin // Holding restart high will freeze the state machine
                    case (state) // These nums do not match the state machine in the receiver
                        0: begin // Start of Frame
                            // This never actually gets called
                            // tx = 0;
                            // state <= 1;
                            // id_bit <= 28;
                            // stuff_bypass <= 0;

                            // update_crc <= 1;
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
                            tx = 1;
                            state <= 4; // IDE

                            update_crc <= 1;
                        end
                        3: begin // RTR
                            tx = rtr;
                            state <= extended ? 5 : 4; // R1 or IDE

                            update_crc <= 1;
                        end
                        4: begin // IDE
                            tx = extended;
                            state <= extended ? 1 : 6; // ID or R1

                            update_crc <= 1;
                        end
                        5: begin // R1
                            tx = 0;
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
                            tx = DLC[10 - state];
                            state <= state + 1;

                            update_crc <= 1;
                        end
                        10: begin // DLC 0
                            tx = DLC[0];
                            state <= (DLC == 0 | rtr) ? 12 : 11; // CRC or Data

                            if (DLC != 0) begin
                                bit_counter[5:3] <= DLC - 1;
                                bit_counter[2:0] <= 3'b111;
                            end

                            crc_bit <= 14;

                            update_crc <= 1;
                        end
                        11: begin // Data
                            bit_counter <= bit_counter - 1;

                            tx <= msg[bit_counter];

                            state <= bit_counter == 0 ? 12 : 11; // CRC or More Data

                            update_crc <= 1;
                        end
                        12: begin // CRC
                            tx <= crc_computed[crc_bit];
                            crc_bit <= crc_bit - 1;

                            state <= crc_bit ? 12 : 13; // More CRC or CRC Delim
                        end
                        13: begin // CRC Delim
                            stuff_bypass <= 1;

                            tx <= 1;
                            state <= 14;
                        end
                        14: begin // ACK Slot
                            tx <= 1;
                            state <= 15;
                        end
                        15: begin // ACK Delim
                            tx <= 1;
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
                            clean_send <= state == 22;
                            tx <= 1;
                            state <= state + 1;
                        end
                        25: begin // Intermission 3
                            tx <= 1;
                        end
                    endcase
                end
            end
        end else begin
            update_crc <= 0;
            clear_crc <= 0;
            clean_send <= 0;
        end
    end
endmodule

module crc_step_machine (
    input clk,
    input next_bit,
    input clear_crc,
    input update_crc,
    input [1:0] running_start,
    output [14:0] crc
);
    assign crc = crc_reg [14:0];

    reg [15:0] crc_reg;

    always @(posedge clk) begin
        if (clear_crc)
            crc_reg <= 0;
        else if (running_start[0]) begin
            crc_reg = 16'd0;

            if (running_start[1])
                crc_reg[14:0] = crc_reg[14:0] ^ 15'h4599;

            crc_reg = {crc_reg[14:0], 1'b0};

            if (next_bit ^ crc_reg[15])
                crc_reg[14:0] = crc_reg[14:0] ^ 15'h4599;
        end else if (update_crc) begin
            // Shift Left
            crc_reg = {crc_reg[14:0], 1'b0};

            if (next_bit ^ crc_reg[15])
                crc_reg[14:0] = crc_reg[14:0] ^ 15'h4599;
        end
    end
endmodule
