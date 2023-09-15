`timescale 1ns/10ps
`define SIMULATION

`include "engine.sv"

module engine_tb;

    // Generate a clk
    reg clk = 0;
    always #1 clk = !clk;

    //initial begin
    //    $dumpfile("engine.vcd");
    //    $dumpvars;
    //end

    localparam WEIGHT_WIDTH     = 8;
    localparam IMAGE_WIDTH      = 16;
    localparam IMAGE_NB         = 3;
    localparam KERNEL_WIDTH     = 3;
    localparam KERNEL_HEIGHT    = 3;

    // local to the uut module
    localparam  WORD_WIDTH      = IMAGE_WIDTH*IMAGE_NB;
    localparam  RESULT_WIDTH    = IMAGE_WIDTH+WEIGHT_WIDTH+1;

    logic   rst;

    logic   [7:0]   cfg_shift;
    logic           cfg_valid;

    logic   [WEIGHT_WIDTH-1:0]  weight;
    logic                       weight_valid;

    logic   [WORD_WIDTH*KERNEL_HEIGHT-1:0]  image;
    logic                                   image_valid;

    logic   [WORD_WIDTH-1:0] result;

    engine #(
        .WEIGHT_WIDTH   (WEIGHT_WIDTH),
        .IMAGE_WIDTH    (IMAGE_WIDTH),
        .IMAGE_NB       (IMAGE_NB),
        .KERNEL_WIDTH   (KERNEL_WIDTH),
        .KERNEL_HEIGHT  (KERNEL_HEIGHT))
    uut (
        .clk    (clk),
        .rst    (rst),

        .cfg_shift  (cfg_shift),
        .cfg_valid  (cfg_valid),

        .weight         (weight),
        .weight_valid   (weight_valid),

        .image          (image),
        .image_valid    (image_valid),

        .result (result)
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

            "\tresult: %x",
            result,

            "\t%b",
            uut.token,
        );
    end

    initial begin
        // init values
        rst = 0;

        cfg_shift   = WEIGHT_WIDTH'(0);
        cfg_valid   = 1'b0;

        weight          = WEIGHT_WIDTH'(0);
        weight_valid    = 1'b0;

        image           = IMAGE_WIDTH'(0);
        image_valid     = 1'b0;
        //end init

        $display("RESET");
        repeat(6) @(negedge clk);
        rst <= 1'b1;
        repeat(6) @(negedge clk);
        rst <= 1'b0;
        repeat(6) @(negedge clk);

        $display("send weight stream");
        repeat(uut.KERNEL_NB) begin
            weight          <= WEIGHT_WIDTH'(2);
            weight_valid    <= 1'b1;
            @(negedge clk);
        end

        weight          <= WEIGHT_WIDTH'(0);
        weight_valid    <= 1'b0;
        @(negedge clk);

        $display("test continuous stream");
        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(1);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(2);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(3);

        image_valid <= 1'b1;
        @(negedge clk);

        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(1);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(2);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(3);

        image_valid <= 1'b1;
        @(negedge clk);

        $display("test not-continuous stream");
        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(1);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(2);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(3);

        image_valid <= 1'b1;
        @(negedge clk);

        image <= (IMAGE_WIDTH*IMAGE_NB)'(0);
        image_valid <= 1'b0;
        repeat (20) @(negedge clk);

        image[0*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(1);
        image[1*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(2);
        image[2*IMAGE_WIDTH +: IMAGE_WIDTH] <= IMAGE_WIDTH'(3);

        image_valid <= 1'b1;
        @(negedge clk);

        image       <= IMAGE_WIDTH'(0);
        image_valid <= 1'b0;
        repeat (20) @(negedge clk);


        repeat(10) @(negedge clk);
        $display("engine done");

        $finish;
    end
endmodule
