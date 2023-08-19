`timescale 1ns/10ps
`define SIMULATION

`include "type3.sv"

module type3_tb;

    // Generate a clk
    reg clk = 0;
    always #1 clk = !clk;

    //initial begin
    //    $dumpfile("type3.vcd");
    //    $dumpvars;
    //end

    localparam IMG_WIDTH    = 16;
    localparam KER_WIDTH    = 8;
    localparam IMG_NB       = 3;

    logic                           rst;

    logic   [IMG_WIDTH*IMG_NB-1:0]  img;
    logic                           val;

    logic   [IMG_WIDTH+KER_WIDTH:0] result;


    type3 #(
        .KER_WIDTH  (KER_WIDTH),
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_NB     (IMG_NB))
    uut (
        .clk    (clk),
        .rst    (rst),

        .img    (img),
        .val    (val),

        .result (result)
    );

    always @(posedge clk) begin
        $display(
            "%d\t%d",
            $time, rst,

            "\tval: %b, img: %d",
            val,
            $signed(img[0*IMG_WIDTH +: IMG_WIDTH]),
            $signed(img[1*IMG_WIDTH +: IMG_WIDTH]),
            $signed(img[2*IMG_WIDTH +: IMG_WIDTH]),

            "\tmac2: %d, %d",
            $signed(uut.delay2[uut.PIPELINE*1-1]),
            $signed(uut.product1_r),

            "\tmac3: %d, %d",
            $signed(uut.delay3[uut.PIPELINE*2-1]),
            $signed(uut.product2_r),

            "\tproduct3: %b, %d",
            $signed(uut.mac3_valid),
            $signed(uut.product3),

            "\tresult: %d",
            $signed(result),
        );
    end

    initial begin
        // init values
        rst = 0;

        img <= (IMG_WIDTH*IMG_NB)'(0);
        val = 1'b0;
        //end init

        $display("RESET");
        repeat(6) @(negedge clk);
        rst <= 1'b1;
        repeat(6) @(negedge clk);
        rst <= 1'b0;
        repeat(6) @(negedge clk);


        $display("test continuous stream");
        img[2*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(1);
        img[0*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(2);
        img[1*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(3);
        val <= 1'b1;
        @(negedge clk);

        img[2*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(1);
        img[0*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(2);
        img[1*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(3);
        val <= 1'b1;
        @(negedge clk);

        $display("test non-continuous stream");
        img[2*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(1);
        img[0*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(2);
        img[1*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(3);
        val <= 1'b1;
        @(negedge clk);

        img <= (IMG_WIDTH*IMG_NB)'(0);
        val <= 1'b0;
        repeat (20) @(negedge clk);

        img[2*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(1);
        img[0*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(2);
        img[1*IMG_WIDTH +: IMG_WIDTH] <= IMG_WIDTH'(3);
        val <= 1'b1;
        @(negedge clk);

        img <= (IMG_WIDTH*IMG_NB)'(0);
        val <= 1'b0;
        repeat (20) @(negedge clk);


        repeat(10) @(negedge clk);
        $display("type3 done");

        $finish;
    end
endmodule
