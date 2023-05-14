// Aiming for 1Mbit/s == 1 microsecond nominal bit time
// Alchitry Cu Clock is 100 MHz == 0.01 microseconds per clock
// 100 quanta per bit time

`timescale 10 ns / 10 ns

module stuffed_transceiver_tb;
    reg can_bus;
    reg [20:0] cbb;

    // Global Clock
    reg clk;

    // Transciever inputs
    reg [63:0] tx_msg;
    reg [28:0] tx_msg_id;
    reg [3:0] tx_msg_bytes;
    reg tx_rtr, tx_extended, tx_msg_exists;

    wire txcr_tx, rcr_tx, txcr_tx_two;
    wire clean_send, clean_send_two;

    // Transciever two inputs
    reg [63:0] tx_msg_two;
    reg [28:0] tx_msg_id_two;
    reg [3:0] tx_msg_bytes_two;
    reg tx_rtr_two, tx_extended_two, tx_msg_exists_two;


    can_transceiver txcr (.rx_raw(can_bus), .tx_raw(txcr_tx), .clk(clk), .tx_msg(tx_msg), .tx_msg_id(tx_msg_id), .tx_msg_bytes(tx_msg_bytes), .tx_rtr(tx_rtr), .tx_extended(tx_extended), .tx_msg_exists(tx_msg_exists), .clean_send(clean_send));
    can_transceiver txcr_two (.rx_raw(can_bus), .tx_raw(txcr_tx_two), .clk(clk), .tx_msg(tx_msg_two), .tx_msg_id(tx_msg_id_two), .tx_msg_bytes(tx_msg_bytes_two), .tx_rtr(tx_rtr_two), .tx_extended(tx_extended_two), .tx_msg_exists(tx_msg_exists_two), .clean_send(clean_send_two));
    can_receiver rcr (.rx_raw(can_bus), .tx_raw(rcr_tx), .clk(clk));

    always @(posedge clk) begin
        cbb <= {cbb[19:0], txcr_tx & rcr_tx & txcr_tx_two};
        can_bus <= cbb[5];
        // can_bus <= txcr_tx & rcr_tx & txcr_tx_two;
    end

    integer i = 0;

    always @(posedge clean_send) begin
        $display("TX1: %b %b %b %b %b %b %b", tx_msg_exists, tx_msg_id, tx_msg_bytes, tx_rtr, tx_extended, tx_msg, clean_send);


        tx_msg_exists <= 1;
        tx_msg_id <= {tx_msg_id[78:0], 1'b0} ^ (tx_msg_id[28] * 29'b10000000101010010010110100110);
        tx_msg_bytes <= 8;
        tx_rtr <= ~tx_rtr;
        tx_extended <= ~tx_extended ^ tx_rtr;
        tx_msg <= {tx_msg[62:0], 1'b0} ^ (tx_msg[63] * 64'h033E7BDF0CC025A5);
        tx_msg_bytes <= tx_msg_bytes + 1;

        tx_msg_id_two <= tx_msg_id_two - 100;


        clk <= ~clk;
        #1;
        clk <= ~clk;
        #1;
    end

    always @(posedge clean_send_two) begin
        $display("TX2: %b %b %b %b %b %b %b", tx_msg_exists_two, tx_msg_id_two, tx_msg_bytes_two, tx_rtr_two, tx_extended_two, tx_msg_two, clean_send_two);


        tx_msg_exists_two <= 1;
        tx_msg_id_two <= {tx_msg_id_two[78:0], 1'b0} ^ (tx_msg_id_two[28] * 29'b10000000101010010010110100110);
        tx_msg_bytes_two <= 8;
        tx_rtr_two <= ~tx_rtr_two;
        tx_extended_two <= ~tx_extended_two ^ tx_rtr_two;
        tx_msg_two <= {tx_msg_two[62:0], 1'b0} ^ (tx_msg_two[63] * 64'h033E7BDF0CC025A5);
        tx_msg_bytes_two <= tx_msg_bytes_two + 1;

        tx_msg_id <= tx_msg_id - 100;

        clk <= ~clk;
        #1;
        clk <= ~clk;
        #1;
    end

    initial begin
        $dumpfile("can.lx2");
        $dumpvars(0, txcr);
        $dumpvars(0, txcr_two);
        $dumpvars(0, rcr);
        $dumpvars(0, clk);
        $dumpvars(0, can_bus);

        // Init the TXCR with nothing
        tx_msg_exists <= 0;
        tx_msg_id <= 0;
        tx_msg_bytes <= 0;
        tx_rtr <= 0;
        tx_extended <= 0;
        tx_msg <= 0;

        tx_msg_exists_two <= 0;
        tx_msg_id_two <= 0;
        tx_msg_bytes_two <= 0;
        tx_rtr_two <= 0;
        tx_extended_two <= 0;
        tx_msg_two <= 0;

        clk <= 1;
        #1;
        clk <= 0;
        #1;

        // Idle the bus
        for (i = 0; i < 5000; i = i + 1) begin
            clk <= ~clk;
            #1;
        end

        tx_msg_exists_two <= 1;
        tx_msg_id_two <= {11'b01100110011, 18'b0};
        tx_msg_bytes_two <= 5;
        tx_rtr_two <= 0;
        tx_extended_two <= 0;
        tx_msg_two <= {24'd0, 40'h0BADC0FFEE};

        tx_msg_exists <= 1;
        tx_msg_id <= 29'h01AABBCC;
        tx_msg_bytes <= 4'd3;
        tx_rtr <= 1'b0;
        tx_extended <= 1'b1;
        tx_msg <= {40'b0, 24'hFFFFFF};



        // Send the message
        for (i = 0; i < 1000000; i = i + 1) begin
            clk <= ~clk;
            #1;
        end

    end


endmodule

// module send_tb;
//     reg msg_exists, rtr, extended;
//     wire stuff_bypass, tx, running_start, transmission_error;

//     reg [28:0] msg_id;
//     reg [63:0] msg;
//     reg [3:0] num_bytes;

//     reg clk;

//     reg rx, stuff_error, updated_sample;
//     wire [63:0] msg_out;
//     wire [28:0] msg_id_out;
//     wire [3:0] num_bytes_out;
//     wire rtr_out, extended_out, bus_idle_out, FORM_ERROR_out, OVERLOAD_ERROR_out, fire_an_ack_out, msg_fresh_out;
//     message_sender sender (.clk(clk), .bit_advance(updated_sample), .msg_id(msg_id), .extended(extended), .rtr(rtr), .msg(msg), .msg_exists(msg_exists), .tx(tx), .stuff_bypass(stuff_bypass), .num_bytes(num_bytes), .running_start(running_start), .restart(transmission_error));
//     message_receiver receiver (.clk(clk), .updated_sample(updated_sample), .msg_exists(1'b1), .stuff_error(stuff_error), .rx(rx), .msg_id(msg_id_out), .rtr(rtr_out), .extended(extended_out), .msg(msg_out), .bus_idle(bus_idle_out), .stuff_bypass(stuff_bypass), .FORM_ERROR(FORM_ERROR_out), .OVERLOAD_ERROR(OVERLOAD_ERROR_out), .fire_an_ack(fire_an_ack_out), .msg_fresh(msg_fresh_out), .msg_bytes(num_bytes_out), .running_start(running_start), .transmission_error(transmission_error), .bit_error(1'b0));


//     wire [63:0] msg_remote;
//     wire [28:0] msg_id_remote;
//     wire [3:0] num_bytes_remote;
//     wire rtr_remote, extended_remote, bus_idle_remote, FORM_ERROR_remote, OVERLOAD_ERROR_remote, fire_an_ack_remote, msg_fresh_remote;
//     message_receiver remote_receiver (.clk(clk), .updated_sample(updated_sample), .msg_exists(1'b0), .stuff_error(stuff_error), .rx(rx), .msg_id(msg_id_remote), .rtr(rtr_remote), .extended(extended_remote), .msg(msg_remote), .bus_idle(bus_idle_remote), .stuff_bypass(stuff_bypass), .FORM_ERROR(FORM_ERROR_remote), .OVERLOAD_ERROR(OVERLOAD_ERROR_remote), .fire_an_ack(fire_an_ack_remote), .msg_fresh(msg_fresh_remote), .msg_bytes(num_bytes_remote), .running_start(running_start), .transmission_error(transmission_error), .bit_error(1'b0));

//     integer i;

//     initial begin
//         $dumpfile("can.lx2");
//         $dumpvars(0, sender);
//         $dumpvars(0, receiver);
//         $dumpvars(0, remote_receiver);


//         // Init
//         stuff_error <= 0;
//         updated_sample <= 0;
//         msg_exists <= 0;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;

//         // Valid MSG
//         msg_id[28:18] <= 11'b01100110011; // ID
//         msg_id[17:0] <= 0;

//         extended <= 0;
//         rtr <= 0;

//         num_bytes <= 5;
//         msg[63:30] <= 0;
//         msg[39:0] <= 40'h0BADC0FFEE;

//         msg_exists <= 1;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;
//         rx <= 0;
//         updated_sample <= 1;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;
//         updated_sample <= 0;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;
//         rx <= 1; // SOF
//         updated_sample <= 1;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;
//         updated_sample <= 0;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;

//         for (i = 0; i < 140; i = i + 1) begin
//             rx <= tx | fire_an_ack_remote;
//             updated_sample <= 1;
//             clk <= 1;
//             #1;
//             clk <= 0;
//             #1;
//             updated_sample <= 0;
//             clk <= 1;
//             #1;
//             clk <= 0;
//             #1;
//         end

//         msg_id[17:0] <= 18'b011001100110011001; // ID

//         extended <= 1;
//         rtr <= 0;

//         num_bytes <= 5;
//         msg[63:30] <= 0;
//         msg[39:0] <= 40'h0BADC0FFEE ^ 40'hEEFF0CDAB0;

//         msg_exists <= 1;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;
//         rx <= 0;
//         updated_sample <= 1;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;
//         updated_sample <= 0;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;
//         rx <= 1; // SOF
//         updated_sample <= 1;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;
//         updated_sample <= 0;
//         clk <= 1;
//         #1;
//         clk <= 0;
//         #1;

//         for (i = 0; i < 140; i = i + 1) begin
//             rx <= tx | fire_an_ack_remote;
//             updated_sample <= 1;
//             clk <= 1;
//             #1;
//             clk <= 0;
//             #1;
//             updated_sample <= 0;
//             clk <= 1;
//             #1;
//             clk <= 0;
//             #1;
//         end

//     end
// endmodule

// module recieve_tb;
//     reg updated_sample, rx, stuff_error;

//     wire [63:0] msg;
//     wire [28:0] msg_id;
//     wire rtr, extended, bus_idle, FORM_ERROR, OVERLOAD_ERROR, fire_an_ack, msg_fresh;

//     reg next_bit, clear_crc, update_crc;

//     wire [14:0] crc;

//     message_receiver receiver (.updated_sample(updated_sample), .stuff_error(stuff_error), .rx(rx), .msg_id(msg_id), .rtr(rtr), .extended(extended), .msg(msg), .bus_idle(bus_idle), .stuff_bypass(stuff_bypass), .FORM_ERROR(FORM_ERROR), .OVERLOAD_ERROR(OVERLOAD_ERROR), .fire_an_ack(fire_an_ack), .msg_fresh(msg_fresh));
//     crc_step_machine crcsm (.next_bit(next_bit), .clear_crc(clear_crc), .update_crc(update_crc), .crc(crc));

//     reg [163:0] test_stream;
//     integer i;

//     initial begin
//         $dumpfile("can.lx2");
//         $dumpvars(0, receiver);
//         $dumpvars(0, test_stream);
//         $dumpvars(0, crcsm);

//         // Init
//         stuff_error <= 0;
//         updated_sample <= 0;

//         // Valid MSG
//         test_stream[63] <= 1; // SOF
//         test_stream[62:52] <= 11'b01100110011; // ID
//         test_stream[51] <= 1; // RTR
//         test_stream[50:49] <= 2'b11; // Reserved
//         test_stream[48:45] <= 4'd0; // DLC

//         test_stream[44:30] <= 15'd0; // CRC
//         test_stream[29] <= 1'b0; // CRC Delim

//         test_stream[28] <= 1'b1; // ACK
//         test_stream[27] <= 1'b0; // ACK Delim

//         test_stream[26:20] <= 7'b0000000; // EOF
//         test_stream[19:0] <= 0;

//         clear_crc <= 1;
//         #1;

//         clear_crc <= 0;
//         #1;

//         for (i = 63; i >= 45; i = i - 1) begin
//             next_bit <= test_stream[i];
//             update_crc <= 1;
//             #0.01;
//             update_crc <= 0;
//             #0.01;
//         end

//         test_stream[44:30] <= crc;

//         #1;

//         for (i = 63; i >= 0; i = i - 1) begin
//             rx = test_stream[i];
//             updated_sample = 1;
//             #1;
//             updated_sample = 0;
//             #1;
//         end

//         // Valid Form, but invalid CRC
//         test_stream[44:30] <= crc ^ 15'b011000101010011;
//         #1;

//         for (i = 63; i >= 0; i = i - 1) begin
//             rx = test_stream[i];
//             updated_sample = 1;
//             #1;
//             updated_sample = 0;
//             #1;
//         end

//         // Msg with data
//         test_stream[163] <= 1; // SOF
//         test_stream[162:152] <= 11'b10001010101; // ID
//         test_stream[151] <= 1; // RTR
//         test_stream[150:149] <= 2'b11; // Reserved
//         test_stream[148:145] <= 4'b1000; // DLC
//         test_stream[144:81] <= 64'hd3359da81bd963e5; // Data

//         test_stream[80:66] <= 15'd0; // CRC
//         test_stream[65] <= 1'b0; // CRC Delim

//         test_stream[64] <= 1'b1; // ACK
//         test_stream[63] <= 1'b0; // ACK Delim

//         test_stream[62:55] <= 7'b0000000; // EOF
//         test_stream[54:0] <= 0;

//         clear_crc <= 1;
//         #1;

//         clear_crc <= 0;
//         #1;

//         for (i = 163; i >= 81; i = i - 1) begin
//             next_bit <= test_stream[i];
//             update_crc <= 1;
//             #0.01;
//             update_crc <= 0;
//             #0.01;
//         end

//         test_stream[80:66] <= crc;

//         #1;

//         for (i = 163; i >= 0; i = i - 1) begin
//             rx = test_stream[i];
//             updated_sample = 1;
//             #1;
//             updated_sample = 0;
//             #1;
//         end

//         // Msg with data
//         // Invalid CRC
//         test_stream[163] <= 1; // SOF
//         test_stream[162:152] <= 11'b10001010101; // ID
//         test_stream[151] <= 1; // RTR
//         test_stream[150:149] <= 2'b11; // Reserved
//         test_stream[148:145] <= 4'b1000; // DLC
//         test_stream[144:81] <= 64'hd3359da81bd963e5; // Data

//         test_stream[80:66] <= 15'd0; // CRC
//         test_stream[65] <= 1'b0; // CRC Delim

//         test_stream[64] <= 1'b1; // ACK
//         test_stream[63] <= 1'b0; // ACK Delim

//         test_stream[62:55] <= 7'b0000000; // EOF
//         test_stream[54:0] <= 0;

//         clear_crc <= 1;
//         #1;

//         clear_crc <= 0;
//         #1;

//         for (i = 163; i >= 81; i = i - 1) begin
//             next_bit <= test_stream[i];
//             update_crc <= 1;
//             #0.01;
//             update_crc <= 0;
//             #0.01;
//         end

//         test_stream[80:66] <= ~crc;

//         #1;

//         for (i = 163; i >= 0; i = i - 1) begin
//             rx = test_stream[i];
//             updated_sample = 1;
//             #1;
//             updated_sample = 0;
//             #1;
//         end

//         // Extended ID Msg with data
//         test_stream[163] <= 1; // SOF
//         test_stream[162:152] <= ~11'b10001010101; // Base ID
//         test_stream[151] <= 0; // SRR
//         test_stream[150] <= 0; // IDE
//         test_stream[149:132] <= 18'b100010101010101010; // Extended ID
//         test_stream[131] <= 1; // RTR
//         test_stream[130:129] <= 2'b11; // Reserved
//         test_stream[128:125] <= 4'b1000; // DLC
//         test_stream[124:61] <= 64'hd3359da81bd963e5 ^ 64'b1010101010101010101010101010101010101010101010101010101010101010; // Datas
//         test_stream[45] <= 1'b0; // CRC Delim

//         test_stream[44] <= 1'b1; // ACK
//         test_stream[43] <= 1'b0; // ACK Delim

//         test_stream[42:35] <= 7'b0000000; // EOF
//         test_stream[34:0] <= 0;

//         clear_crc <= 1;
//         #1;

//         clear_crc <= 0;
//         #1;

//         for (i = 163; i >= 61; i = i - 1) begin
//             next_bit <= test_stream[i];
//             update_crc <= 1;
//             #0.01;
//             update_crc <= 0;
//             #0.01;
//         end

//         test_stream[60:46] <= crc;

//         #1;

//         for (i = 163; i >= 0; i = i - 1) begin
//             rx = test_stream[i];
//             updated_sample = 1;
//             #1;
//             updated_sample = 0;
//             #1;
//         end

//         // High CRC Delim
//         test_stream[45] <= 1'b1; // CRC Delim

//         #1;

//         for (i = 163; i >= 0; i = i - 1) begin
//             rx = test_stream[i];
//             updated_sample = 1;
//             #1;
//             updated_sample = 0;
//             #1;
//         end

//         // High Ack Delim
//         test_stream[43] <= 1'b1; // CRC Delim

//         #1;

//         for (i = 163; i >= 0; i = i - 1) begin
//             rx = test_stream[i];
//             updated_sample = 1;
//             #1;
//             updated_sample = 0;
//             #1;
//         end


//     end
// endmodule

module crc_tb;
    reg next_bit, clear_crc, update_crc;
    wire [14:0] crc;
    reg [63:0] test_stream;

    reg clk;

    integer i;

    crc_step_machine crcsm (.clk(clk), .next_bit(next_bit), .clear_crc(clear_crc), .update_crc(update_crc), .crc(crc));
    initial begin
        $dumpfile("can.lx2");
        $dumpvars(0, test_stream);
        $dumpvars(0, crcsm);

        // Init
        clear_crc <= 1;
        clk <= 1;
        #1;
        clk <= 0;
        #1;
        clear_crc <= 0;
        clk <= 1;
        #1;
        clk <= 0;
        #1;

        // Test Stream
        test_stream = 64'hd3359da81bd963e5;
        for (i = 63; i >= 0; i = i - 1) begin
            next_bit <= test_stream[i];
            update_crc <= 1;
            clk <= 1;
            #1;
            clk <= 0;
            #1;
            update_crc <= 0;
            clk <= 1;
            #1;
            clk <= 0;
            #1;
        end

        $display("Data: %h", test_stream);
        $display("CRC: %h", crc);
    end
endmodule

module txp_tb;
    reg next_bit, updated_sample, rx_updated_sample, stuff_bypass, rx;
    wire tx, bit_advance, stuff_error, out_bit, doorbell;
    reg sync_tick;

    reg [23:0] txp_test_stream;
    reg [23:0] txp_out_stream;

    reg clk;

    integer i;

    tx_pipeline txp (.clk(clk), .tx(tx), .updated_sample(updated_sample), .next_bit(next_bit), .bit_advance(bit_advance), .stuff_bypass(stuff_bypass));
    rx_pipeline rxp (.clk(clk), .rx(rx), .updated_sample(rx_updated_sample), .updated_bit(doorbell), .next_bit(out_bit), .stuff_error(stuff_error), .stuff_bypass(stuff_bypass));

    initial begin
        $dumpfile("can.lx2");
        $dumpvars(0, txp_test_stream);
        $dumpvars(0, txp_out_stream);
        $dumpvars(0, txp);
        $dumpvars(0, rxp);

        // Init
        stuff_bypass <= 1;
        clk <= 1;
        #0.1;
        clk <= 0;
        #1
        stuff_bypass <= 0;
        updated_sample <= 0;
        rx_updated_sample <= 0;
        clk <= 1;
        #0.1;
        clk <= 0;

        #1;

        // Stream without the need for stuff
        txp_test_stream = 24'b100100100100100100100100;
        i = 23;
        while (i >= 0) begin
            next_bit <= txp_test_stream[i];
            updated_sample <= 1;
            clk <= 1;
            #0.1;
            clk <= 0;
            #1;
            rx <= tx;
            rx_updated_sample <= 1;
            if (bit_advance) begin
                i = i - 1;
            end
            clk <= 1;
            #0.1;
            clk <= 0;

            #1
            if (doorbell) begin
                txp_out_stream <= {txp_out_stream[22:0], out_bit};
            end
            #1;
            updated_sample <= 0;
            rx_updated_sample <= 0;
            clk <= 1;
            #0.1;
            clk <= 0;
            #1;
        end

        stuff_bypass <= 1;
        clk <= 1;
        #0.1;
        clk <= 0;
        #1;
        stuff_bypass <= 0;
        clk <= 1;
        #0.1;
        clk <= 0;

        // Stream with stuffing
        txp_test_stream = 24'b100000000011111111100000;
        i = 23;
        #1;
        while (i >= 0) begin
            next_bit <= txp_test_stream[i];
            updated_sample <= 1;
            clk <= 1;
            #0.1;
            clk <= 0;
            #1;
            rx <= tx;
            rx_updated_sample <= 1;
            if (bit_advance) begin
                i = i - 1;
            end
            clk <= 1;
            #0.1;
            clk <= 0;

            #1
            if (doorbell) begin
                txp_out_stream <= {txp_out_stream[22:0], out_bit};
            end
            #1;
            updated_sample <= 0;
            rx_updated_sample <= 0;
            clk <= 1;
            #0.1;
            clk <= 0;
            #1;
        end
    end
endmodule

module rxp_tb;
    reg rx, updated_sample, stuff_bypass;
    wire updated_bit, next_bit, stuff_error;

    reg [23:0] test_stream;
    reg [23:0] out_stream;

    reg clk;

    integer i;

    rx_pipeline rxp (.clk(clk), .rx(rx), .updated_sample(updated_sample), .updated_bit(updated_bit), .next_bit(next_bit), .stuff_error(stuff_error), .stuff_bypass(stuff_bypass));

    initial begin
        $dumpfile("can.lx2");
        $dumpvars(0, test_stream);
        $dumpvars(0, out_stream);
        $dumpvars(0, rxp);

        // Init
        stuff_bypass <= 1;
        clk <= 1;
        #1;
        clk <= 0;
        #1;
        stuff_bypass <= 0;
        rx <= 0;
        updated_sample <= 0;
        clk <= 1;
        #1;
        clk <= 0;
        #1;

        // Valid Data Stream without Stuff
        test_stream = 24'b100100100100100100100100;
        for (i = 23; i >= 0; i = i - 1) begin
            rx <= test_stream[i];
            clk <= 1;
            #1;
            clk <= 0;
            #1;
            clk = 1;
            updated_sample = 1;
            #1;
            clk <= 0;
            #1;
            if (updated_bit) begin
                out_stream[i] <= next_bit;
            end
            updated_sample = 0;
            clk = 1;
            #1;
            clk <= 0;
            #1;
        end

        stuff_bypass <= 1;
        clk <= 1;
        #1;
        clk <= 0;
        #1;
        stuff_bypass <= 0;
        clk <= 1;
        #1;
        clk <= 0;

        // Valid Data Stream with Stuff
        test_stream = 24'b100000100011111011110010;
        #1
        for (i = 23; i >= 0; i = i - 1) begin
            rx <= test_stream[i];
            clk <= 1;
            #1;
            clk <= 0;
            #1;
            clk = 1;
            updated_sample = 1;
            #1;
            clk <= 0;
            #1;
            if (updated_bit) begin
                out_stream[i] <= next_bit;
            end
            updated_sample = 0;
            clk = 1;
            #1;
            clk <= 0;
            #1;
        end

        stuff_bypass <= 1;
        clk <= 1;
        #1;
        clk <= 0;
        #1;
        for (i = 23; i >= 0; i = i - 1) begin
            rx <= test_stream[i];
            clk <= 1;
            #1;
            clk <= 0;
            #1;
            updated_sample = 1;
            clk = 1;
            #1;
            clk <= 0;
            #1;
            if (updated_bit) begin
                out_stream[i] <= next_bit;
            end
            updated_sample = 0;
            clk = 1;
            #1;
            clk <= 0;
            #1;
        end

        stuff_bypass <= 0;
        clk <= 1;
        #1;
        clk <= 0;
        #1;

        // Stuff Error Test
        test_stream = 24'b001000000011111111100000;
        #1
        for (i = 23; i >= 0; i = i - 1) begin
            rx <= test_stream[i];
            clk <= 1;
            #1;
            clk <= 0;
            #1;
            updated_sample = 1;
            clk = 1;
            #1;
            clk <= 0;
            #1;
            if (updated_bit) begin
                out_stream[i] <= next_bit;
            end
            updated_sample = 0;
            clk = 1;
            #1;
            clk <= 0;
            #1;
        end
    end
endmodule

module ssm_tb;
    reg rx_raw, clk, bus_idle;
    wire rx;
    reg [6:0] RJW;

    reg [123:0] can_test;

    always @(rx) begin
        bus_idle = 0;
    end

    reg rst;

    sync_sample_machine ssm (.rst(rst), .rx_raw(rx_raw), .clk(clk), .RJW(RJW), .bus_idle(bus_idle), .rx(rx));
    initial begin
        $dumpfile("can.lx2");
        $dumpvars(0, ssm);

        can_test[123] = 1;
        can_test[122:112] = 11'b1001001001;
        can_test[111:110] = 2'b00; // SRR & IDE
        can_test[109:92] = 18'b100100100100100100; // Extended ID
        can_test[91:89] = 3'b111; // RTR & R0 & R1
        can_test[88:85] = 4'b0001; // DLC
        can_test[84:77] = 8'b01010101; // Data Byte
        can_test[76:62] = 15'b100100100100100; // CRC
        can_test[61:52] = 10'b0100000000; // Delims, ACK & EOF
        can_test[51:0] = 52'b0; // Bus Idle

        rst <= 1;
        clk <= 1;
        #1;
        clk <= 0;
        #1;

        rst <= 0;
        clk <= 1;
        #1;
        clk <= 0;
        #1;


        RJW = 1;
        bus_idle = 1;
        rx_raw = 0;
        clk <= 1;
        #1;
        clk <= 0;
        #1;

        for (integer i = 123; i > 0; i = i - 1) begin
            rx_raw = can_test[i];
            for (integer i = 0; i < 100; i = i + 1) begin
                clk <= 1;
                #1;
                clk <= 0;
                #1;
            end
        end


    end
endmodule
