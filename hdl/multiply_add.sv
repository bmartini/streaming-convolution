`ifndef _multiply_add_
`define _multiply_add_


`default_nettype none

module multiply_add
  #(parameter   M1_WIDTH    = 16,
    parameter   M2_WIDTH    = 16)
   (input  wire                             clk,
    input  wire                             rst,

    input  wire     [M2_WIDTH-1:0]          m2,
    input  wire     [M1_WIDTH-1:0]          m1,
    input  wire     [M1_WIDTH+M2_WIDTH:0]   add,

    output logic    [M1_WIDTH+M2_WIDTH:0]   result
);



    function signed [M1_WIDTH+M2_WIDTH-1:0] multiply;
        input signed [M1_WIDTH-1:0] a1;
        input signed [M2_WIDTH-1:0] a2;

        begin
            multiply = a1 * a2;
        end
    endfunction


    function signed [M1_WIDTH+M2_WIDTH:0] addition;
        input signed [M1_WIDTH+M2_WIDTH:0]      a1;
        input signed [M1_WIDTH+M2_WIDTH-1:0]    a2;

        begin
            addition = a1 + a2;
        end
    endfunction


    logic   [M2_WIDTH-1:0]          m2_2p;
    logic   [M2_WIDTH-1:0]          m2_1p;

    logic   [M1_WIDTH-1:0]          m1_2p;
    logic   [M1_WIDTH-1:0]          m1_1p;

    logic   [M1_WIDTH+M2_WIDTH:0]   add_3p;
    logic   [M1_WIDTH+M2_WIDTH:0]   add_2p;
    logic   [M1_WIDTH+M2_WIDTH:0]   add_1p;

    logic   [M1_WIDTH+M2_WIDTH-1:0] product_3p;
    logic   [M1_WIDTH+M2_WIDTH:0]   result_4p;


    always_ff @(posedge clk) begin
        m2_1p   <= m2;
        m1_1p   <= m1;
        add_1p  <= add;

        if (rst) begin
            m2_1p   <= 'b0;
            m1_1p   <= 'b0;
            add_1p  <= 'b0;
        end
    end


`ifdef ALTERA_FPGA
    always_ff @(posedge clk or posedge rst) begin
`else //!ALTERA_FPGA
    always_ff @(posedge clk) begin
`endif
        if (rst) begin
            m2_2p       <= 'b0;
            m1_2p       <= 'b0;
            add_2p      <= 'b0;

            product_3p  <= 'b0;
            add_3p      <= 'b0;

            result_4p   <= 'b0;
            result      <= 'b0;
        end
        else begin
            m2_2p       <= m2_1p;
            m1_2p       <= m1_1p;
            add_2p      <= add_1p;

            product_3p  <= multiply(m1_2p, m2_2p);
            add_3p      <= add_2p;

            result_4p   <= addition(add_3p, product_3p);
            result      <= result_4p;
        end
    end



`ifdef FORMAL

    reg         past_exists;
    reg  [3:0]  past_wait;
    initial begin
        restrict property (past_exists == 1'b0);
        restrict property (past_wait   ==  'b0);
    end

    // extend wait time unit the past can be accessed
    always_ff @(posedge clk) begin
        {past_exists, past_wait} <= {past_wait, 1'b1};
    end



    //
    // Check that the down stream value is correctly calculated
    //


    // check that arithmetic is correct
    always_ff @(posedge clk) begin
        if (past_exists && $past( ~rst)) begin
            assert($signed(product_3p) == ($signed($past(m1_2p)) * $signed($past(m2_2p))));

            assert($signed(result_4p) == ($signed($past(add_3p)) + $signed($past(product_3p))));
        end
    end


    // result and data pipeline is reset to zero after a reset signal
    always_ff @(posedge clk) begin
        if (past_exists && ~rst && $past(rst)) begin
            assert(m2_1p        == 'b0);
            assert(m1_1p        == 'b0);
            assert(add_1p       == 'b0);

            assert(m1_2p        == 'b0);
            assert(m2_2p        == 'b0);
            assert(add_2p       == 'b0);

            assert(product_3p   == 'b0);
            assert(add_3p       == 'b0);

            assert(result_4p    == 'b0);
            assert(result       == 'b0);
        end
    end


`endif
endmodule

`ifndef YOSYS
`default_nettype wire
`endif

`endif //  `ifndef _multiply_add_
