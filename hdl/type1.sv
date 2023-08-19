`ifndef _type1_
`define _type1_

`include "multiply_add.sv"

`default_nettype none

module type1
  #(parameter   KER_WIDTH   = 16,
    parameter   IMG_WIDTH   = 16,
    parameter   IMG_NB      = 3)
   (input   wire                            clk,
    input   wire                            rst,

    input   wire    [IMG_WIDTH*IMG_NB-1:0]  img,
    input   wire                            val,

    output  logic   [IMG_WIDTH+KER_WIDTH:0] result
);

    localparam PIPELINE = 6;

    integer d1;
    integer d2;
    integer d3;

    logic   [IMG_WIDTH+KER_WIDTH:0] product1;
    logic   [IMG_WIDTH+KER_WIDTH:0] product1_r;
    logic   [IMG_WIDTH+KER_WIDTH:0] product2;
    logic   [IMG_WIDTH+KER_WIDTH:0] product2_r;
    logic   [IMG_WIDTH+KER_WIDTH:0] product3;
    logic   [IMG_WIDTH+KER_WIDTH:0] product3_r;

    logic   [IMG_WIDTH-1:0] delay1 [PIPELINE*0+1];
    logic   [IMG_WIDTH-1:0] delay2 [PIPELINE*1+1];
    logic   [IMG_WIDTH-1:0] delay3 [PIPELINE*2+1];

    logic   [PIPELINE*3-0:0]    mac_valid;
    logic                       mac1_valid;
    logic                       mac2_valid;
    logic                       mac3_valid;


    always_ff @(posedge clk) begin
        if (rst) begin
            mac_valid <= 'b0;
        end
        else begin
            mac_valid <= {mac_valid[PIPELINE*3-1:0], val};
        end
    end


    always_ff @(posedge clk) begin
        delay1[0] <= img[0*IMG_WIDTH +: IMG_WIDTH];

        for (d1 = 0; d1 < PIPELINE*0-0; d1 = d1+1) begin
            delay1[d1+1] <= delay1[d1];
        end
    end

    multiply_add #(
        .IMG_WIDTH  (IMG_WIDTH),
        .KER_WIDTH  (KER_WIDTH))
    mac1_ (
        .clk    (clk),
        .rst    (rst),

        .ker    (KER_WIDTH'(2)),
        .img    (delay1[PIPELINE*0-0]),
        .add    ({IMG_WIDTH+KER_WIDTH+1{1'b0}}),

        .result (product1)
    );

    assign mac1_valid = mac_valid[PIPELINE*1-1];

    always_ff @(posedge clk) begin
        if (mac1_valid) begin
            product1_r <= product1;
        end
    end


    always_ff @(posedge clk) begin
        delay2[0] <= img[1*IMG_WIDTH +: IMG_WIDTH];

        for (d2 = 0; d2 < PIPELINE*1-0; d2 = d2+1) begin
            delay2[d2+1] <= delay2[d2];
        end
    end

    multiply_add #(
        .IMG_WIDTH  (IMG_WIDTH),
        .KER_WIDTH  (KER_WIDTH))
    mac2_ (
        .clk    (clk),
        .rst    (rst),

        .ker    (KER_WIDTH'(3)),
        .img    (delay2[PIPELINE*1-0]),
        .add    (product1_r),

        .result (product2)
    );

    assign mac2_valid = mac_valid[PIPELINE*2-1];

    always_ff @(posedge clk) begin
        if (mac2_valid) begin
            product2_r <= product2;
        end
    end


    always_ff @(posedge clk) begin
        delay3[0] <= img[2*IMG_WIDTH +: IMG_WIDTH];

        for (d3 = 0; d3 < PIPELINE*2-0; d3 = d3+1) begin
            delay3[d3+1] <= delay3[d3];
        end
    end

    multiply_add #(
        .IMG_WIDTH  (IMG_WIDTH),
        .KER_WIDTH  (KER_WIDTH))
    mac3_ (
        .clk    (clk),
        .rst    (rst),

        .ker    (KER_WIDTH'(4)),
        .img    (delay3[PIPELINE*2-0]),
        .add    (product2_r),

        .result (product3)
    );

    assign mac3_valid = mac_valid[PIPELINE*3-1];

    always_ff @(posedge clk) begin
        if (mac3_valid) begin
            product3_r <= product3;
        end
    end


    assign result = mac_valid[PIPELINE*3-0] ? product3_r : (IMG_WIDTH+KER_WIDTH+1)'(0);


`ifdef FORMAL


`endif
endmodule

`ifndef YOSYS
`default_nettype wire
`endif

`endif //  `ifndef _type1_
