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

            "\tval: %b, image: %d %d %d",
            image_valid,
            $signed(uut.image_offset[0*IMAGE_WIDTH +: IMAGE_WIDTH]),
            $signed(uut.image_offset[1*IMAGE_WIDTH +: IMAGE_WIDTH]),
            $signed(uut.image_offset[2*IMAGE_WIDTH +: IMAGE_WIDTH]),

            "\tmac2: %d, %d",
            $signed(uut.MAC_[1].delay[uut.PIPELINE*1-uut.MAC_[1].DELAY_OFFSET]),
            $signed(uut.product_r[1]),

            "\tmac3: %d, %d",
            $signed(uut.MAC_[2].delay[uut.PIPELINE*2-uut.MAC_[2].DELAY_OFFSET]),
            $signed(uut.product_r[2]),

            "\tproduct3: %b, %d",
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
        weight          <= WEIGHT_WIDTH'(2);
        weight_valid    <= 3'b001;
        @(negedge clk);

        weight          <= WEIGHT_WIDTH'(2);
        weight_valid    <= 3'b010;
        @(negedge clk);

        weight          <= WEIGHT_WIDTH'(2);
        weight_valid    <= 3'b100;
        @(negedge clk);

        weight          <= WEIGHT_WIDTH'(0);
        weight_valid    <= 1'b0;
        @(negedge clk);

        $display("test continuous stream");
        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(1);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(2);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(3);

        image_valid <= 1'b1;
        @(negedge clk);

        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(4);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(5);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(6);

        image_valid <= 1'b1;
        @(negedge clk);

        $display("test not-continuous stream");
        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(1);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(2);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(3);

        image_valid <= 1'b1;
        @(negedge clk);

        image <= (IMAGE_WIDTH*MAC_NB)'(0);
        image_valid <= 1'b0;
        repeat (20) @(negedge clk);

        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(4);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(5);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(6);

        image_valid <= 1'b1;
        @(negedge clk);

        image       <= IMAGE_WIDTH'(0);
        image_valid <= 1'b0;
        repeat (20) @(negedge clk);


        repeat(10) @(negedge clk);
        $display("slice done");

        $finish;
    end
endmodule
