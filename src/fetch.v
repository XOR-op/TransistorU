`include "constant.v"
module fetcher(
    input clk, input rst, input ena,
    // to decoder
    output reg out_decoder_ena,
    output reg [`DATA_WIDTH ] out_inst, output reg [`DATA_WIDTH ] out_decoder_pc, output reg out_branch_taken,
    // predictor
    output reg out_pc_reg_ena, output reg [`DATA_WIDTH ] out_pc_query_taken,
    input in_result_taken,
    // to memory
    output reg out_mem_ena, output reg [`DATA_WIDTH ] out_address,
    // from memory
    input in_mem_ready, input [`DATA_WIDTH ] in_mem_inst,
    // from pc reg
    input [`DATA_WIDTH ] in_pc
);
    reg busy;
    // i-cache
    reg [`DATA_WIDTH ] data [`ICACHE_WIDTH ];
    reg [`TAG_WIDTH ] tag [`ICACHE_WIDTH ];
    reg valid [`ICACHE_WIDTH ];

    // i-cache logic
    always @(*) begin
        out_decoder_ena = valid[in_pc[`INDEX_WIDTH ]] && tag[in_pc[`INDEX_WIDTH ]] == in_pc[`TAG_WIDTH ];
        out_inst = data[in_pc[`INDEX_WIDTH ]];
        out_decoder_pc = in_pc;
        out_branch_taken = in_result_taken;
    end
    // fetcher logic
    integer i;
    always @(posedge clk) begin
        out_mem_ena <= `FALSE;
        out_pc_reg_ena <= `TRUE;
        if (rst) begin
            for (i = 0; i < `ICACHE_SIZE;i = i+1) begin
                valid[i] <= 0;
                data[i] <= 0;
                tag[i] <= 0;
            end
            busy <= `FALSE;
            out_pc_reg_ena <= `FALSE;
        end else if (in_mem_ready) begin
            data[in_pc[`INDEX_WIDTH ]] <= in_mem_inst;
            valid[in_pc[`INDEX_WIDTH ]] <= `TRUE;
            tag[in_pc[`INDEX_WIDTH ]] <= in_pc[`TAG_WIDTH ];
            busy <= `FALSE;
        end else if (ena && !busy && !out_decoder_ena) begin
            // read from memory
            busy <= `TRUE;
            out_mem_ena <= `TRUE;
            out_address <= in_pc;
            out_pc_reg_ena <= `FALSE;
        end else if (busy)
            out_pc_reg_ena <= `FALSE;
    end
endmodule : fetcher