`timescale 1ns/10ps
`define SIMULATION

`include "group_add.sv"

module group_add_tb;

    // Generate a clk
    reg clk = 0;
    always #1 clk = !clk;


    //initial begin
    //    $dumpfile("group_add.vcd");
    //    $dumpvars;
    //end

    localparam GROUP_NB     = 4;
    localparam NUM_WIDTH    = 16;
    localparam NUM_POINT    = 8;


    // transform signed fixed point representation to real
    function real num_f2r;
        input signed [NUM_WIDTH-1:0] value;

        begin
            num_f2r = value / ((1<<NUM_POINT) * 1.0);
        end
    endfunction

    // transform real to signed fixed point representation
    function signed [NUM_WIDTH-1:0] num_r2f;
        input real value;

        begin
            num_r2f = value * (1<<(NUM_POINT));
        end
    endfunction

    logic   [NUM_WIDTH*GROUP_NB-1:0]    up_data;
    logic   [NUM_WIDTH-1:0]             dn_data;

    group_add #(
        .GROUP_NB   (GROUP_NB),
        .NUM_WIDTH  (NUM_WIDTH))
    uut (
        .clk        (clk),

        .up_data    (up_data),
        .dn_data    (dn_data)
    );

    always @(posedge clk) begin
        $display(
            "%4d",
            $time,

            "\tup: %x",
            up_data,

            "\tup3: %12f, up2: %12f, up1: %12f, up0: %12f",
            num_f2r(up_data[3*NUM_WIDTH +: NUM_WIDTH]),
            num_f2r(up_data[2*NUM_WIDTH +: NUM_WIDTH]),
            num_f2r(up_data[1*NUM_WIDTH +: NUM_WIDTH]),
            num_f2r(up_data[0*NUM_WIDTH +: NUM_WIDTH]),

            "\tdn: %12f",
            num_f2r($signed(dn_data)),
        );
    end

    initial begin
        // init values
        up_data = 'b0;

        repeat(5) @(negedge clk);

        up_data     <= {num_r2f( 4), num_r2f( 3), num_r2f( 2), num_r2f( 1)};
        @(negedge clk);

        up_data     <= {num_r2f( 8), num_r2f( 7), num_r2f( 6), num_r2f( 5)};
        @(negedge clk);

        up_data     <= {num_r2f(12), num_r2f(11), num_r2f(10), num_r2f( 9)};
        @(negedge clk);

        up_data     <= {num_r2f(16), num_r2f(15), num_r2f(14), num_r2f(13)};
        @(negedge clk);

        up_data     <= {num_r2f(20), num_r2f(19), num_r2f(18), num_r2f(17)};
        @(negedge clk);

        up_data <= 'b0;
        @(negedge clk);


        repeat(10) @(negedge clk);
        $display("slice done");

        $finish;
    end

endmodule
