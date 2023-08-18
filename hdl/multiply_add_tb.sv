`timescale 1ns/10ps
`define SIMULATION

`include "multiply_add.sv"

module multiply_add_tb;

    // Generate a clk
    reg clk = 0;
    always #1 clk = !clk;

    //initial begin
    //    $dumpfile("multiply_add.vcd");
    //    $dumpvars;
    //end

    localparam M1_WIDTH = 16;
    localparam M2_WIDTH = 8;

    logic                           rst;

    logic   [M2_WIDTH-1:0]          m2;
    logic   [M1_WIDTH-1:0]          m1;
    logic   [M1_WIDTH+M2_WIDTH:0]   add;

    logic   [M1_WIDTH+M2_WIDTH:0]   result;

    multiply_add #(
        .M1_WIDTH   (M1_WIDTH),
        .M2_WIDTH   (M2_WIDTH))
    uut (
        .clk    (clk),
        .rst    (rst),

        .m2     (m2),
        .m1     (m1),
        .add    (add),

        .result (result)
    );

    always @(posedge clk) begin
        $display(
            "%d\t%d",
            $time, rst,

            "\tm2: %d, m1: %d, add: %d",
            $signed(m2),
            $signed(m1),
            $signed(add),

            "\tresult: %d",
            $signed(result),
        );
    end

    initial begin
        // init values
        rst = 0;

        m2 = '0;
        m1 = '0;
        add = '0;
        //end init

        $display("RESET");
        repeat(6) @(negedge clk);
        rst <= 1'b1;
        repeat(6) @(negedge clk);
        rst <= 1'b0;
        repeat(6) @(negedge clk);


        $display("test continuous stream");
        m2 <= M2_WIDTH'(1);
        m1 <= M1_WIDTH'(1);
        add <= (M1_WIDTH+M2_WIDTH+1)'(1);
        @(negedge clk);
        repeat (10) begin
            m2 <= m2 +  'b1;
            m1 <= m1 * -'b1;
            @(negedge clk);
        end

        m2 <= '0;
        m1 <= '0;
        repeat (10) @(negedge clk);


        repeat(10) @(negedge clk);
        $display("multiply_add done");

        $finish;
    end
endmodule
