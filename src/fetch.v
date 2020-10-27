`include "constant.v"
module fetcher(
    input clk, input rst, input ena,
    // from controller
    input [`DATA_WIDTH ] assigned_pc,
    // from i-cache
    input [`INSTRUCTION_WIDTH ] inst,
    // from last cycle
    input [`DATA_WIDTH ] old_pc,
    // loopback and to i-cache
    output [`DATA_WIDTH ] new_pc
);
    always @(posedge clk)begin
        if(rst)begin
            new_pc<=assigned_pc;
        end else if(ena)begin
            new_pc<=old_pc+4;
        end
    end
endmodule : fetcher