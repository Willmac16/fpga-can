// Can2040 will hit 1Mbit/s == 1 microsecond nominal bit time
// Alchitry Clock is 100 MHz == 0.01 microseconds per clock
// 100 quanta per bit time

`timescale 10 ns / 1 ps

module rxp_tb;
    reg rx, updated_sample, stuff_bypass;
    wire updated_bit, next_bit, stuff_error;

    reg [23:0] test_stream;
    reg [23:0] out_stream;

    integer i;

    rx_pipeline rxp (.rx(rx), .updated_sample(updated_sample), .updated_bit(updated_bit), .next_bit(next_bit), .stuff_error(stuff_error), .stuff_bypass(stuff_bypass));

    initial begin
        $dumpfile("can.lx2");
        $dumpvars(0, test_stream);
        $dumpvars(0, out_stream);
        $dumpvars(0, rxp);

        // Init
        stuff_bypass <= 1;
        #1
        stuff_bypass <= 0;
        rx <= 0;
        updated_sample <= 0;
        #1;

        // Valid Data Stream without Stuff
        test_stream = 24'b100100100100100100100100;
        for (i = 23; i >= 0; i = i - 1) begin
            rx <= test_stream[i];
            #1;
            updated_sample <= 1;
            #1;
            if (updated_bit) begin
                out_stream <= {next_bit, out_stream[23:1]};
            end
            updated_sample <= 0;
        end

        stuff_bypass <= 1;
        #1;
        stuff_bypass <= 0;

        // Valid Data Stream with Stuff
        test_stream = 24'b100000100011111011110010;
        #1
        for (i = 23; i >= 0; i = i - 1) begin
            rx <= test_stream[i];
            #1;
            updated_sample <= 1;
            #1;
            if (updated_bit) begin
                out_stream <= {next_bit, out_stream[23:1]};
            end
            updated_sample <= 0;
        end

        stuff_bypass <= 1;
        #1;
        for (i = 23; i >= 0; i = i - 1) begin
            rx <= test_stream[i];
            #1;
            updated_sample <= 1;
            #1;
            if (updated_bit) begin
                out_stream <= {next_bit, out_stream[23:1]};
            end
            updated_sample <= 0;
        end

        stuff_bypass <= 0;
        #1;

        // Stuff Error Test
        test_stream = 24'b100000000011111111100000;
        #1
        for (i = 23; i >= 0; i = i - 1) begin
            rx <= test_stream[i];
            #1;
            updated_sample <= 1;
            #1;
            if (updated_bit) begin
                out_stream <= {next_bit, out_stream[23:1]};
            end
            updated_sample <= 0;
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

    sync_sample_machine ssm (.rx_raw(rx_raw), .clk(clk), .RJW(RJW), .bus_idle(bus_idle), .rx(rx));
    initial begin
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



        // $dumpfile("can.vcd");
        $dumpvars(0, ssm);
        clk = 0;
        RJW = 1;
        bus_idle = 1;
        rx_raw = 0;
        #1;

        for (integer i = 123; i > 0; i = i - 1) begin
            rx_raw = can_test[i];
            for (integer i = 0; i < 100; i = i + 1) begin
                clk = 1;
                #0.45;
                clk = 0;
                #0.45;
            end
        end


    end

endmodule
