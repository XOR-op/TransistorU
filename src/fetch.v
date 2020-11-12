`include "constant.v"
module fetcher(
    input clk, input rst, input ena,
    // from controller
    input [`DATA_WIDTH ] assigned_pc,
    // to decoder
    output [`DATA_WIDTH ] out_inst, output [`DATA_WIDTH ] out_pc, output out_decoder_ena,
    // to memory
    output out_mem_ena, output [`DATA_WIDTH ] out_address,
    // from memory
    input in_mem_ready, input [`DATA_WIDTH ] in_mem_inst,
    // loopback
    input [`DATA_WIDTH ] in_pc,
    output [`DATA_WIDTH ] loopback_pc
);
    reg [`DATA_WIDTH ] buffered_pc;
    // i-cache
    reg [`DATA_WIDTH ] data [`ICACHE_WIDTH ];
    reg [`TAG_WIDTH ] tag [`ICACHE_WIDTH ];
    reg valid [`ICACHE_WIDTH ];

    assign out_inst = in_inst;
    assign out_pc = buffered_pc;
    assign out_decoder_ena = in_icache_ready;
    assign next_pc = in_icache_ready ? buffered_pc+4:buffered_pc;

    // i-cache logic
    always @(*) begin
        out_decoder_ena = valid[in_pc[`INDEX_WIDTH ]] && tag[in_pc[`INDEX_WIDTH ]] == in_pc[`TAG_WIDTH ];
        out_inst = data[in_pc[`INDEX_WIDTH ]];
        out_pc = buffered_pc;
    end
    // fetcher logic
    always @(posedge clk) begin
        out_mem_ena <= `FALSE;
        loopback_pc <= in_pc;
        if (rst) begin
            valid <= 0;
            data <= 0;
            tag <= 0;
            stat <= `FALSE;
            loopback_pc <= assigned_pc;
        end else if (in_mem_ready) begin
            data[in_pc[`INDEX_WIDTH ]] <= in_mem_inst;
            valid[in_pc[`INDEX_WIDTH ]] <= `TRUE;
            tag[in_pc[`INDEX_WIDTH ]] <= in_pc[`TAG_WIDTH ];
            stat <= `FALSE;
            loopback_pc <= in_pc+4;
        end else if (ena && !stat && !out_ok) begin
            stat <= `TRUE;
            out_mem_ena <= `TRUE;
            out_address<=in_pc;
        end
    end
endmodule : fetcher