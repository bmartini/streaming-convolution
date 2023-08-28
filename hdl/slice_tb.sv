`timescale 1ns/10ps
`define SIMULATION

`include "slice.sv"

module slice_tb;

    // Generate a clk
    reg clk = 0;
    always #1 clk = !clk;

    //initial begin
    //    $dumpfile("slice.vcd");
    //    $dumpvars;
    //end

    localparam MAC_NB       = 3;
    localparam OFFSET       = 0;
    localparam IMAGE_WIDTH  = 16;
    localparam WEIGHT_WIDTH = 8;

    logic   rst;

    logic   [WEIGHT_WIDTH-1:0]              weight;
    logic   [MAC_NB-1:0]                    weight_valid;

    logic   [IMAGE_WIDTH*MAC_NB-1:0]        image;
    logic                                   image_valid;

    logic   [IMAGE_WIDTH+WEIGHT_WIDTH:0]    result;
    logic                                   result_valid;

    slice #(
        .MAC_NB         (MAC_NB),
        .OFFSET         (OFFSET),
        .WEIGHT_WIDTH   (WEIGHT_WIDTH),
        .IMAGE_WIDTH    (IMAGE_WIDTH))
    uut (
        .clk    (clk),
        .rst    (rst),

        .weight         (weight),
        .weight_valid   (weight_valid),

        .image          (image),
        .image_valid    (image_valid),

        .result         (result),
        .result_valid   (result_valid)
    );

    always @(posedge clk) begin
        $display(
            "%d\t%d",
            $time, rst,

            "\tval: %b, weight: %d",
            weight_valid,
            $signed(weight),

            "\tval: %b, image: %d %d %d",
            image_valid,
            $signed(image[0*IMAGE_WIDTH +: IMAGE_WIDTH]),
            $signed(image[1*IMAGE_WIDTH +: IMAGE_WIDTH]),
            $signed(image[2*IMAGE_WIDTH +: IMAGE_WIDTH]),

            //"\tdelay: %x, %x, %x",
            //uut.MAC_[0].delay[IMAGE_WIDTH*uut.MAC_[0].DELAY_NB-1 -: IMAGE_WIDTH],
            //uut.MAC_[1].delay[IMAGE_WIDTH*uut.MAC_[1].DELAY_NB-1 -: IMAGE_WIDTH],
            //uut.MAC_[2].delay[IMAGE_WIDTH*uut.MAC_[2].DELAY_NB-1 -: IMAGE_WIDTH],

            //"\tadd: %d, %d, %d",
            //$signed(uut.product_r[0]),
            //$signed(uut.product_r[1]),
            //$signed(uut.product_r[2]),

            "\tproductA: %b, %d",
            uut.MAC_[0].product_valid,
            $signed(uut.MAC_[0].product),

            "\tproductB: %b, %d",
            uut.MAC_[1].product_valid,
            $signed(uut.MAC_[1].product),

            "\tproductC: %b, %d",
            uut.MAC_[2].product_valid,
            $signed(uut.MAC_[2].product),

            "\tresult: %b, %d",
            result_valid,
            $signed(result),
        );
    end

    initial begin
        // init values
        rst = 0;

        weight         <= WEIGHT_WIDTH'(0);
        weight_valid   <= 'b0;

        image         <= IMAGE_WIDTH'(0);
        image_valid   <= 1'b0;
        //end init

        $display("RESET");
        repeat(6) @(negedge clk);
        rst <= 1'b1;
        repeat(6) @(negedge clk);
        rst <= 1'b0;
        repeat(6) @(negedge clk);

        $display("send weightnel stream");
        weight          <= WEIGHT_WIDTH'(1);
        weight_valid    <= 3'b001;
        @(negedge clk);

        weight          <= WEIGHT_WIDTH'(1);
        weight_valid    <= 3'b010;
        @(negedge clk);

        weight          <= WEIGHT_WIDTH'(1);
        weight_valid    <= 3'b100;
        @(negedge clk);

        weight          <= WEIGHT_WIDTH'(0);
        weight_valid    <= 3'b000;
        @(negedge clk);

        $display("test continuous stream");
        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(2);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(3);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(1);

        image_valid <= 1'b1;
        @(negedge clk);

        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(5);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(6);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(4);

        image_valid <= 1'b1;
        @(negedge clk);

        $display("test not-continuous stream");
        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(2);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(3);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(1);

        image_valid <= 1'b1;
        @(negedge clk);

        image <= (IMAGE_WIDTH*MAC_NB)'(0);
        image_valid <= 1'b0;
        repeat (20) @(negedge clk);

        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(5);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(6);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(4);

        image_valid <= 1'b1;
        @(negedge clk);

        image       <= IMAGE_WIDTH'(0);
        image_valid <= 1'b0;
        repeat (20) @(negedge clk);


        repeat(10) @(negedge clk);
        $display("slice offset: %2d", OFFSET);

        $finish;
    end
endmodule
