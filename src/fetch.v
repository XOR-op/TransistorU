`include "constant.v"
module fetcher(
    input clk, input rst, input ena,
    input in_rollback,
    // to decoder
    output reg out_decoder_and_pc_ena, output reg out_branch_taken,
    output reg [`DATA_WIDTH ] out_inst, output reg [`DATA_WIDTH ] out_decoder_pc,
    // ask for pc
    output out_pc_reg_ena,
    // to memory
    output reg out_mem_ena, output reg [`DATA_WIDTH ] out_address,
    // from memory
    input in_mem_ready, input [`DATA_WIDTH ] in_mem_inst,
    // from pc reg
    input [`DATA_WIDTH ] in_pc, input in_result_taken,
    input in_rs_ok, input in_rob_ok
);
    reg busy;
    // i-cache
    reg [`DATA_WIDTH ] data [`ICACHE_WIDTH ];
    reg [`TAG_WIDTH ] tag [`ICACHE_WIDTH ];
    reg valid [`ICACHE_WIDTH ];

    assign out_pc_reg_ena = out_decoder_and_pc_ena;
    wire icache_valid=valid[in_pc[`INDEX_WIDTH ]] && tag[in_pc[`INDEX_WIDTH ]] == in_pc[`TAG_WIDTH ];
    // i-cache logic
    always @(*) begin
        out_decoder_and_pc_ena =icache_valid&& in_rs_ok && in_rob_ok;
        out_inst = data[in_pc[`INDEX_WIDTH ]];
        out_decoder_pc = in_pc;
        out_branch_taken = in_result_taken;
    end
    // fetcher logic
    integer i;
    always @(posedge clk) begin
        out_mem_ena <= `FALSE;
        // out_pc_reg_ena <= `TRUE;
        if (rst) begin
            for (i = 0; i < `ICACHE_SIZE;i = i+1) begin
                valid[i] <= 0;
                data[i] <= 0;
                tag[i] <= 0;
            end
            busy <= `FALSE;
            out_address <= `ZERO_DATA;
        end else if (in_rollback) begin
            // stop reading inst
            busy <= `FALSE;
        end else if (in_mem_ready) begin
            data[in_pc[`INDEX_WIDTH ]] <= in_mem_inst;
            valid[in_pc[`INDEX_WIDTH ]] <= `TRUE;
            tag[in_pc[`INDEX_WIDTH ]] <= in_pc[`TAG_WIDTH ];
            busy <= `FALSE;
        end else if (ena && !busy && !icache_valid) begin
            // read from memory
            busy <= `TRUE;
            out_mem_ena <= `TRUE;
            out_address <= in_pc;
        end
    end
endmodule