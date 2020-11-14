`include "constant.v"
`define ELEMENT prediction_table[in_forwarding_branch_pc[`PREDICTION_INDEX_RANGE ]]
module pc(
    input clk, input rst,
    input ena,
    // from fetch
    input [`DATA_WIDTH ] in_last_pc, input [`INSTRUCTION_WIDTH ] in_last_inst,
    output reg [`DATA_WIDTH ] out_next_pc,
    // from branch info forwarding
    input [`DATA_WIDTH ] in_forwarding_branch_pc, input in_misbranch, input in_forwarding_branch_taken,
    input [`DATA_WIDTH ] in_forwarding_correct_address,
    // reset all components for misbranch
    output out_clear_all
);
    reg [`DATA_WIDTH ] pc;
    // 2-bit saturating counter now
    reg [1:0] prediction_table [`PREDICTION_SLOT_SIZE -1:0];
    wire [`DATA_WIDTH ] J_IMM = {{12{in_inst[31]}}, in_inst[19:12], in_inst[20], in_inst[30:25], in_inst[24:21], 1'b0},
                        B_IMM = {{20{in_inst[31]}}, in_inst[7], in_inst[30:25], in_inst[11:8], 1'b0};
    always @(*) begin
        out_clear_all=in_misbranch;
    end
    always @(posedge clk) begin
        if (rst) begin
            pc<=`ZERO_DATA ;
        end else if (ena) begin
            if (in_misbranch) begin
                out_next_pc<=in_forwarding_correct_address;
            end else if (in_last_inst[`OP_RANGE ] == `BRANCH_OP) begin
                // predict
                out_next_pc <= prediction_table[in_last_pc[`PREDICTION_INDEX_RANGE ]] [1] ? in_last_pc+B_IMM:in_last_pc+4;
            end else if (in_last_inst[`OP_RANGE ] == `JAL_OP) begin
                out_next_pc <= in_last_pc+J_IMM;
            end else begin
                out_next_pc <= in_last_pc+4;
            end
            `ELEMENT <= `ELEMENT +in_forwarding_branch_taken ?
                ((`ELEMENT == 2'b11) ? 0:1):(((`ELEMENT == 2'b00) ? 0: -1));
        end
    end
endmodule : pc
`undef ELEMENT