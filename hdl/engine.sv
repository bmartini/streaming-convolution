`ifndef _engine_
`define _engine_

`include "slice.sv"
`include "group_add.sv"

`default_nettype none

module engine
  #(parameter   WEIGHT_WIDTH    = 8,
    parameter   IMAGE_WIDTH     = 16,
    parameter   IMAGE_NB        = 8,
    parameter   KERNEL_WIDTH    = 3,
    parameter   KERNEL_HEIGHT   = 3,
    localparam  WORD_WIDTH      = IMAGE_WIDTH*IMAGE_NB,
    localparam  RESULT_WIDTH    = IMAGE_WIDTH+WEIGHT_WIDTH+1)
   (input   wire    clk,
    input   wire    rst,

    input   wire    [WEIGHT_WIDTH-1:0]  weight,
    input   wire                        weight_valid,

    input   wire    [KERNEL_HEIGHT*WORD_WIDTH-1:0]  image,
    input   wire                                    image_valid,

    output  logic   [RESULT_WIDTH*IMAGE_NB-1:0] result
);

    localparam KERNEL_NB = KERNEL_WIDTH*KERNEL_HEIGHT;

    genvar h;
    genvar s;
    genvar i;

    logic   [KERNEL_NB*2-1:0]   token_wrap;
    logic   [KERNEL_NB-1:0]     token;

    logic   [RESULT_WIDTH*KERNEL_HEIGHT-1:0]    slice_reorder   [IMAGE_NB];
    logic   [RESULT_WIDTH*IMAGE_NB-1:0]         slice_result    [KERNEL_HEIGHT];
    logic   [IMAGE_NB-1:0]                      slice_done      [KERNEL_HEIGHT];


    always_comb begin
        token_wrap = {token, token};
    end


    always_ff @(posedge clk) begin
        if (rst) begin
            token <= 'b1;
        end
        else if (weight_valid) begin
            token <= token_wrap[KERNEL_NB-1 +: KERNEL_NB];
        end
    end


    generate
        for (h=0; h<KERNEL_HEIGHT; h=h+1) begin : HEIGHT_


            for (s=0; s<IMAGE_NB; s=s+1) begin: SLICE_

                localparam BOUNDARY = IMAGE_NB-KERNEL_WIDTH;
                localparam OFFSET   = (s <= BOUNDARY) ? 0 : s-BOUNDARY;

                logic   [WORD_WIDTH*2-1:0]  image_wrap;

                always_comb begin
                    image_wrap = {image[h*WORD_WIDTH +: WORD_WIDTH], image[h*WORD_WIDTH +: WORD_WIDTH]};
                end


                slice #(
                    .MAC_NB         (KERNEL_WIDTH),
                    .OFFSET         (OFFSET),
                    .WEIGHT_WIDTH   (WEIGHT_WIDTH),
                    .IMAGE_WIDTH    (IMAGE_WIDTH))
                slice_ (
                    .clk    (clk),
                    .rst    (rst),

                    .weight         (weight),
                    .weight_valid   ({KERNEL_WIDTH{weight_valid}} & token[h*KERNEL_WIDTH +: KERNEL_WIDTH]),

                    .image          (image_wrap[(s+1)*IMAGE_WIDTH+WORD_WIDTH-1 -: WORD_WIDTH]),
                    .image_valid    (image_valid),

                    .result         (slice_result[h][s*RESULT_WIDTH +: RESULT_WIDTH]),
                    .result_valid   (slice_done[h][s])
                );

                always_comb begin
                    slice_reorder[s][h*RESULT_WIDTH +: RESULT_WIDTH] = slice_result[h][s*RESULT_WIDTH +: RESULT_WIDTH];
                end
            end
        end
    endgenerate


    generate
        for (i=0; i<IMAGE_NB; i=i+1) begin: ADDERS_

            group_add #(
                .GROUP_NB   (KERNEL_HEIGHT),
                .NUM_WIDTH  (RESULT_WIDTH))
            group_add_ (
                .clk        (clk),

                .up_data    (slice_reorder[i]),
                .dn_data    (result[i*RESULT_WIDTH +: RESULT_WIDTH])
            );
        end
    endgenerate


`ifdef FORMAL


`endif
endmodule

`ifndef YOSYS
`default_nettype wire
`endif

`endif //  `ifndef _engine_
