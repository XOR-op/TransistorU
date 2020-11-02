`include "constant.v"
module ICache(
    input clk, input rst,
    // from fetcher
    input ena, input [`DATA_WIDTH ] address,
    // to fetcher
    output out_ok, output [`DATA_WIDTH ] out_inst,
    // to memory
    output out_mem_ena, output [`DATA_WIDTH ] out_address,
    // from memory
    input in_mem_ready, input [`DATA_WIDTH ] in_mem_inst
);
    reg [`DATA_WIDTH ] data [`ICACHE_WIDTH ];
    reg [`TAG_WIDTH ] tag [`ICACHE_WIDTH ];
    reg valid [`ICACHE_WIDTH ];
    reg stat;
    always @(*) begin
        out_ok = valid[address[`INDEX_WIDTH ]] && tag[address[`INDEX_WIDTH ]] == address[`TAG_WIDTH ];
        out_inst = data[address[`INDEX_WIDTH ]];
        out_address = address;
    end
    always @(posedge clk) begin
        out_mem_ena <= `FALSE;
        if (rst) begin
            valid <= 0;
            data <= 0;
            tag <= 0;
            stat <= `FALSE;
        end else if (in_mem_ready) begin
            data[address[`INDEX_WIDTH ]] <= in_mem_inst;
            valid[address[`INDEX_WIDTH ]] <= `TRUE;
            tag[address[`INDEX_WIDTH ]] <= address[`TAG_WIDTH ];
            stat <= `FALSE;
        end else if (ena && !stat && !out_ok) begin
            stat <= `TRUE;
            out_mem_ena <= `TRUE;
        end
    end
endmodule : ICache