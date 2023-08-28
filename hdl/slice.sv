`ifndef _slice_
`define _slice_

`include "multiply_add.sv"

`default_nettype none

module slice
  #(parameter   MAC_NB          = 3,
    parameter   OFFSET          = 0, // (0, 1, or 2) must be less then MAC_NB
    parameter   WEIGHT_WIDTH    = 16,
    parameter   IMAGE_WIDTH     = 16,
    localparam  RESULT_WIDTH    = IMAGE_WIDTH+WEIGHT_WIDTH+1)
   (input   wire    clk,
    input   wire    rst,

    input   wire    [WEIGHT_WIDTH-1:0]          weight,
    input   wire    [MAC_NB-1:0]                weight_valid,

    input   wire    [IMAGE_WIDTH*MAC_NB-1:0]    image,
    input   wire                                image_valid,

    output  logic   [RESULT_WIDTH-1:0]          result,
    output  logic                               result_valid
);

    localparam PIPELINE = 6; // pipeline depth of MAC and register for product


    logic   [RESULT_WIDTH-1:0]  product_r   [MAC_NB+1];
    logic   [PIPELINE*3:0]      slice_valid;


    always_comb begin
        product_r[0] = {RESULT_WIDTH{1'b0}};
    end


    genvar x;
    generate
        for (x = 0; x < MAC_NB; x = x + 1) begin : MAC_

            localparam VALID_OFFSET = (OFFSET == MAC_NB-1) ? 2 : ((MAC_NB-1-OFFSET) <= x) ? 3 : 2;
            localparam EXTEND       = (OFFSET == MAC_NB-1) ? 1 : ((MAC_NB-1-OFFSET) <= x) ? 0 : 1;
            localparam DELAY_NB     = (PIPELINE*x)+EXTEND;

            integer dd;
            logic   [IMAGE_WIDTH*(DELAY_NB+1)-1:0]  delay_shift;
            logic   [IMAGE_WIDTH*DELAY_NB-1:0]      delay;
            logic   [WEIGHT_WIDTH-1:0]              weight_r;

            logic   [RESULT_WIDTH-1:0]              product;
            logic                                   product_valid;
            logic   [PIPELINE*(x+1)-VALID_OFFSET:0] pipeline_valid;


            always_ff @(posedge clk) begin
                if (weight_valid[x]) begin
                    weight_r <= weight;
                end
            end


            assign delay_shift = {delay, image[x*IMAGE_WIDTH +: IMAGE_WIDTH]};

            always_ff @(posedge clk) begin
                delay <= delay_shift[IMAGE_WIDTH*DELAY_NB-1:0];
            end


            multiply_add #(
                .M1_WIDTH   (IMAGE_WIDTH),
                .M2_WIDTH   (WEIGHT_WIDTH))
            mac_ (
                .clk    (clk),
                .rst    (rst),

                .m1     (delay[IMAGE_WIDTH*DELAY_NB-1 -: IMAGE_WIDTH]),
                .m2     (weight_r),
                .add    (product_r[x]),

                .result (product)
            );


            always_ff @(posedge clk) begin
                if (rst)    {product_valid, pipeline_valid} <= '0;
                else        {product_valid, pipeline_valid} <= {pipeline_valid, image_valid};
            end


            always_ff @(posedge clk) begin
                if (rst) begin
                    product_r[x+1] <= '0;
                end
                else if (product_valid) begin
                    product_r[x+1] <= product;
                end
            end
        end
    endgenerate


    assign result_valid = slice_valid[PIPELINE*3];


    always_ff @(posedge clk) begin
        if (rst)    slice_valid <= 'b0;
        else        slice_valid <= {slice_valid[PIPELINE*3-1:0], image_valid};
    end


    generate
        if (OFFSET == (MAC_NB-1)) begin
            // one clock tick worth of data is needed for calculation

            assign result = slice_valid[PIPELINE*3] ? product_r[MAC_NB] : (RESULT_WIDTH)'(0);

        end
        else begin
            // two clock ticks worth of data are needed for calculation

            always_ff @(posedge clk) begin
                result <= (RESULT_WIDTH)'(0);

                if (slice_valid[PIPELINE*3-1]) begin
                    result <= product_r[MAC_NB];
                end
            end
        end
    endgenerate


`ifdef FORMAL


`endif
endmodule

`ifndef YOSYS
`default_nettype wire
`endif

`endif //  `ifndef _slice_
