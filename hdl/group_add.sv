`ifndef _group_add_
`define _group_add_


`default_nettype none

module group_add
  #(parameter GROUP_NB  = 4,
    parameter NUM_WIDTH = 16)
   (input   wire    clk,

    input   wire    [NUM_WIDTH*GROUP_NB-1:0]    up_data,
    output  logic   [NUM_WIDTH-1:0]             dn_data
);

    function signed [NUM_WIDTH-1:0] addition;
        input signed [NUM_WIDTH-1:0] a1;
        input signed [NUM_WIDTH-1:0] a2;

        begin
            addition = a1 + a2;
        end
    endfunction


    generate
        if (GROUP_NB == 1) begin : GROUP_1_

            assign dn_data = up_data;

        end
        else if (GROUP_NB == 2) begin : GROUP_2_

            (* use_dsp48 = "no" *) logic [NUM_WIDTH-1:0]            dn_data_1p;
            (* use_dsp48 = "no" *) logic [NUM_WIDTH*GROUP_NB-1:0]   up_data_r;

            always_ff @(posedge clk) begin
                up_data_r <= up_data;
            end

            always_ff @(posedge clk) begin
                dn_data_1p  <= addition(up_data_r[0*NUM_WIDTH +: NUM_WIDTH],
                                        up_data_r[1*NUM_WIDTH +: NUM_WIDTH]);

                dn_data     <= dn_data_1p;
            end
        end
        else if ((GROUP_NB % 2) == 1) begin : GROUP_ODD_

            localparam ADDER_NB = (GROUP_NB+1)/2;

            (* use_dsp48 = "no" *) logic [NUM_WIDTH*ADDER_NB-1:0]   dn_data_3p;
            (* use_dsp48 = "no" *) logic [NUM_WIDTH*ADDER_NB-1:0]   dn_data_2p;
            (* use_dsp48 = "no" *) logic [NUM_WIDTH*GROUP_NB-1:0]   up_data_r;

            always_ff @(posedge clk) begin
                up_data_r <= up_data;
            end

            genvar x;
            for (x=0; x<ADDER_NB-1; x=x+1) begin : ADDITION_

                always_ff @(posedge clk) begin
                    dn_data_3p[x*NUM_WIDTH +: NUM_WIDTH] <= addition(up_data_r[(x*2+0)*NUM_WIDTH +: NUM_WIDTH],
                                                                     up_data_r[(x*2+1)*NUM_WIDTH +: NUM_WIDTH]);
                end
            end

            always_ff @(posedge clk) begin
                dn_data_3p[NUM_WIDTH*ADDER_NB-1 -: NUM_WIDTH] <= up_data_r[NUM_WIDTH*GROUP_NB-1 -: NUM_WIDTH];

                dn_data_2p <= dn_data_3p;
            end

            group_add #(
                .GROUP_NB   (ADDER_NB),
                .NUM_WIDTH  (NUM_WIDTH))
            group_add_ (
                .clk        (clk),

                .up_data    (dn_data_2p),
                .dn_data    (dn_data)
            );
        end
        else if ((GROUP_NB % 2) == 0) begin : GROUP_EVEN_

            localparam ADDER_NB = GROUP_NB/2;

            (* use_dsp48 = "no" *) logic [NUM_WIDTH*ADDER_NB-1:0]   dn_data_3p;
            (* use_dsp48 = "no" *) logic [NUM_WIDTH*ADDER_NB-1:0]   dn_data_2p;
            (* use_dsp48 = "no" *) logic [NUM_WIDTH*GROUP_NB-1:0]   up_data_r;

            always_ff @(posedge clk) begin
                up_data_r <= up_data;
            end

            genvar x;
            for (x=0; x<ADDER_NB; x=x+1) begin : ADDITION_

                always_ff @(posedge clk) begin
                    dn_data_3p[x*NUM_WIDTH +: NUM_WIDTH] <= addition(up_data_r[(x*2+0)*NUM_WIDTH +: NUM_WIDTH],
                                                                     up_data_r[(x*2+1)*NUM_WIDTH +: NUM_WIDTH]);
                end
            end

            always_ff @(posedge clk) begin
                dn_data_2p <= dn_data_3p;
            end

            group_add #(
                .GROUP_NB   (ADDER_NB),
                .NUM_WIDTH  (NUM_WIDTH))
            group_add_ (
                .clk        (clk),

                .up_data    (dn_data_2p),
                .dn_data    (dn_data)
            );
        end
    endgenerate



endmodule

`ifndef YOSYS
`default_nettype wire
`endif

`endif //  `ifndef _group_add_
