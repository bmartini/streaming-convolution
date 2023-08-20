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


    logic   [IMAGE_WIDTH*MAC_NB*2-1:0]  image_wrap;
    logic   [IMAGE_WIDTH*MAC_NB-1:0]    image_offset;
    logic   [RESULT_WIDTH-1:0]          product_r   [MAC_NB+1];

    logic   [PIPELINE*3:0]  slice_valid;


    always_comb begin
        image_wrap      = {image, image};
        image_offset    = image_wrap[OFFSET*IMAGE_WIDTH +: IMAGE_WIDTH*MAC_NB];

        product_r[0] = {RESULT_WIDTH{1'b0}};
    end

    always_ff @(posedge clk) begin
        if (rst)    slice_valid <= 'b0;
        else        slice_valid <= {slice_valid[PIPELINE*3-1:0], image_valid};
    end


    genvar x;
    generate
        for (x = 0; x < MAC_NB; x = x + 1) begin : MAC_

            localparam DELAY_OFFSET = MAC_NB-OFFSET > x ? 0 : 1; // 0 on 1st clock or 1 on 2nd clock
            localparam VALID_OFFSET = MAC_NB-OFFSET > x ? 1 : 2; // 1 on 1st clock or 2 on 2nd clock
            localparam EXTEND       = MAC_NB-OFFSET > x ? 1 : 0; // 1 on 1st clock or 0 on 2nd clock

            integer dd;
            logic   [IMAGE_WIDTH-1:0]   delay [PIPELINE*x+EXTEND];
            logic   [WEIGHT_WIDTH-1:0]  weight_r;
            logic   [RESULT_WIDTH-1:0]  product;
            logic                       product_valid;

            always_ff @(posedge clk) begin
                if (weight_valid[x]) begin
                    weight_r <= weight;
                end
            end

            always_ff @(posedge clk) begin
                delay[0] <= image_offset[x*IMAGE_WIDTH +: IMAGE_WIDTH];

                for (dd = 0; dd < PIPELINE*x-DELAY_OFFSET; dd = dd+1) begin
                    delay[dd+1] <= delay[dd];
                end
            end

            multiply_add #(
                .M1_WIDTH   (IMAGE_WIDTH),
                .M2_WIDTH   (WEIGHT_WIDTH))
            mac_ (
                .clk    (clk),
                .rst    (rst),

                .m1     (delay[PIPELINE*x-DELAY_OFFSET]),
                .m2     (weight_r),
                .add    (product_r[x]),

                .result (product)
            );

            assign product_valid = slice_valid[PIPELINE*(x+1)-VALID_OFFSET];

            always_ff @(posedge clk) begin
                if (product_valid) begin
                    product_r[x+1] <= product;
                end
            end
        end
    endgenerate


    assign result_valid = slice_valid[PIPELINE*3];

    generate
        if (OFFSET == 0) begin

            assign result = slice_valid[PIPELINE*3] ? product_r[MAC_NB] : (RESULT_WIDTH)'(0);

        end
        else begin

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
