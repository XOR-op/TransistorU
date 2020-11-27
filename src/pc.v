`include "constant.v"
`define ELEMENT prediction_table[in_forwarding_branch_pc[`PREDICTION_INDEX_RANGE ]]
module pc(
    input clk, input rst, input ena,
    input in_fetcher_ena,
    // with fetch
    input [`DATA_WIDTH ] in_last_pc, input [`DATA_WIDTH ] in_last_inst,
    output reg [`DATA_WIDTH ] out_next_pc, output reg out_next_taken,
    output [`DATA_WIDTH ] out_rollback_pc,
    // from branch info forwarding
    input in_misbranch, input in_forwarding_branch_taken,
    input [`DATA_WIDTH ] in_forwarding_branch_pc, input [`DATA_WIDTH ] in_forwarding_correct_address,
    // reset all components for misbranch
    output reg out_rollback
);
    // 2-bit saturating counter now
    // now always not taken for debug propose
    // reg [1:0] prediction_table [`PREDICTION_SLOT_SIZE -1:0];
    wire [`DATA_WIDTH ] J_IMM = {{12{in_last_inst[31]}}, in_last_inst[19:12], in_last_inst[20], in_last_inst[30:25], in_last_inst[24:21], 1'b0},
                        B_IMM = {{20{in_last_inst[31]}}, in_last_inst[7], in_last_inst[30:25], in_last_inst[11:8], 1'b0};
    always @(*) begin
        out_rollback = in_misbranch;
        //out_next_taken = prediction_table[in_last_pc[`PREDICTION_INDEX_RANGE ]] [1];
        out_next_taken = 0;
    end
    assign out_rollback_pc=in_forwarding_correct_address;
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            out_next_pc <= `ZERO_DATA;
            out_rollback <= `FALSE;
            out_next_pc <= `ZERO_DATA;
            //for (i = 0; i < `PREDICTION_SLOT_SIZE;i = i+1)
            //    prediction_table[i] <= 2'b01;
        end else if (ena) begin
            if (in_misbranch) begin
                out_next_pc <= in_forwarding_correct_address;
            end else if (in_fetcher_ena) begin
                if (in_last_inst[`OP_RANGE ] == `BRANCH_OP) begin
                    // predict
                    // out_next_pc <= prediction_table[in_last_pc[`PREDICTION_INDEX_RANGE ]] [1] ? in_last_pc+B_IMM:in_last_pc+4;
                    out_next_pc <= in_last_pc+4;
                end else if (in_last_inst[`OP_RANGE ] == `JAL_OP) begin
                    out_next_pc <= in_last_pc+J_IMM;
                end else begin
                    out_next_pc <= in_last_pc+4;
                end
            end
        end
        // `ELEMENT <= `ELEMENT +in_forwarding_branch_taken ?
        //     ((`ELEMENT == 2'b11) ? 0:1):(((`ELEMENT == 2'b00) ? 0: -1));
    end

endmodule : pc
`undef ELEMENT