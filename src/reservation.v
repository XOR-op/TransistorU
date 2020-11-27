`include "constant.v"

module reservation(
    input clk, input rst, input ena,
    // assignment
    input assignment_ena,
    input [`DATA_WIDTH ] in_imm,
    input [`OPERATION_BUS ] in_op,
    input [`ROB_WIDTH ] in_Qj, input [`ROB_WIDTH ] in_Qk,
    input [`DATA_WIDTH ] in_Vj, input [`DATA_WIDTH ] in_Vk,
    input [`DATA_WIDTH ] in_pc,
    input [`ROB_WIDTH ] in_rd_rob,
    // CDB broadcast
    input [`ROB_WIDTH ] in_alu_cdb_rob_tag, input [`DATA_WIDTH ] in_alu_cdb_data, input in_alu_cdb_isload,
    input [`ROB_WIDTH ] in_ls_cdb_rob_tag, input [`DATA_WIDTH ] in_ls_cdb_data,
    // pass to alu
    output reg [`OPERATION_BUS ] out_op,
    output reg [`DATA_WIDTH ] out_Vj, output reg [`DATA_WIDTH ] out_Vk,
    output reg [`ROB_WIDTH ] out_rob_tag, output reg [`DATA_WIDTH ] out_pc,
    output reg [`DATA_WIDTH ] out_imm,
    // return to decoder
    output has_capacity
    // debug
`ifdef DEBUG_MACRO
    ,
    output reg [`RS_WIDTH ] debug_cdb_rs, output reg [`RS_WIDTH ] debug_ls_cdb_rs
`endif
);
    // inner storage
    reg [`OPERATION_BUS ] op [`RS_SIZE :0];
    reg [`ROB_WIDTH ] Qj [`RS_SIZE :0];
    reg [`ROB_WIDTH ] Qk [`RS_SIZE :0];
    reg [`DATA_WIDTH ] Vj [`RS_SIZE :0];
    reg [`DATA_WIDTH ] Vk [`RS_SIZE :0];
    reg [`DATA_WIDTH ] A [`RS_SIZE :0];
    reg busy [`RS_SIZE :0];
    reg [`ROB_WIDTH ] rob_tag [`RS_SIZE :0];
    reg [`DATA_WIDTH ] PCs [`RS_SIZE :0];
    reg [`DATA_WIDTH ] imms [`RS_SIZE :0];
    // control variable
    wire [`RS_WIDTH ] free_rs_tag;
    wire [`RS_WIDTH ] what_to_issue;
    wire ready_to_issue [`RS_SIZE :1];
    assign has_capacity = free_rs_tag != `ZERO_RS;

    integer i;

    // assignment
    always @(posedge clk) begin
        // issue to alu
        if (rst) begin
            op[`ZERO_RS ] <= `NOP;
            PCs[`ZERO_RS ] <= `ZERO_DATA;
            for (i = 0; i <= `RS_SIZE;i = i+1)
                busy[i] <= `FALSE;
        end else if (ena) begin
            // when what_to_issue =0, op==NOP
            out_op <= op[what_to_issue];
            out_Vk <= Vk[what_to_issue];
            out_Vj <= Vj[what_to_issue];
            out_rob_tag <= rob_tag[what_to_issue];
            out_pc <= PCs[what_to_issue];
            out_imm <= imms[what_to_issue];
            if (what_to_issue != `ZERO_RS) begin
                busy[what_to_issue] <= `FALSE;
            end
            // broadcast
            for (i = 1; i <= `RS_SIZE;i = i+1) begin
                if (Qj[i] != `ZERO_ROB && Qj[i] == in_alu_cdb_rob_tag && !in_alu_cdb_isload) begin
                    Qj[i] <= `ZERO_ROB;
                    Vj[i] <= in_alu_cdb_data;
`ifdef DEBUG_MACRO
                    debug_cdb_rs <= i;
`endif
                end
                if (Qk[i] != `ZERO_ROB && Qk[i] == in_alu_cdb_rob_tag && !in_alu_cdb_isload) begin
                    Qk[i] <= `ZERO_ROB;
                    Vk[i] <= in_alu_cdb_data;
`ifdef DEBUG_MACRO
                    debug_cdb_rs <= i;
`endif
                end
                if (Qj[i] != `ZERO_ROB && Qj[i] == in_ls_cdb_rob_tag) begin
                    Qj[i] <= `ZERO_ROB;
                    Vj[i] <= in_ls_cdb_data;
`ifdef DEBUG_MACRO
                    debug_ls_cdb_rs <= i;
`endif
                end
                if (Qk[i] != `ZERO_ROB && Qk[i] == in_ls_cdb_rob_tag) begin
                    Qk[i] <= `ZERO_ROB;
                    Vk[i] <= in_ls_cdb_data;
`ifdef DEBUG_MACRO
                    debug_ls_cdb_rs <= i;
`endif
                end
            end
            if (assignment_ena) begin
                // assignment
                op[free_rs_tag] <= in_op;
                Qj[free_rs_tag] <= (in_Qj == in_alu_cdb_rob_tag && !in_alu_cdb_isload) ?`ZERO_ROB :(in_Qj == in_ls_cdb_rob_tag ?`ZERO_ROB :in_Qj);
                Qk[free_rs_tag] <= (in_Qk == in_alu_cdb_rob_tag && !in_alu_cdb_isload) ?`ZERO_ROB :(in_Qk == in_ls_cdb_rob_tag ?`ZERO_ROB :in_Qk);
                Vj[free_rs_tag] <= (in_Qj == `ZERO_ROB) ? in_Vj:((in_Qj == in_alu_cdb_rob_tag && !in_alu_cdb_isload) ? in_alu_cdb_data:(in_Qj == in_ls_cdb_rob_tag ? in_ls_cdb_data:in_Vj));
                Vk[free_rs_tag] <= (in_Qk == `ZERO_ROB) ? in_Vk:((in_Qk == in_alu_cdb_rob_tag && !in_alu_cdb_isload) ? in_alu_cdb_data:(in_Qk == in_ls_cdb_rob_tag ? in_ls_cdb_data:in_Vk));
                busy[free_rs_tag] <= `TRUE;
                PCs[free_rs_tag] <= in_pc;
                imms[free_rs_tag] <= in_imm;
                rob_tag[free_rs_tag] <= in_rd_rob;
            end
        end
    end

    // choose op to ALU
    generate
        genvar ii;
        for (ii = 1;ii <= `RS_SIZE;ii = ii+1) begin : gen_ready_sig
            assign ready_to_issue[ii] = busy[ii] &(Qj[ii] == `ZERO_ROB) &(Qk[ii] == `ZERO_ROB);
        end
    endgenerate

    // priority encoder-like
    assign free_rs_tag = ~busy[1] ? 1:
        ~busy[2] ? 2:
            ~busy[3] ? 3:
                ~busy[4] ? 4:
                    ~busy[5] ? 5:
                        ~busy[6] ? 6:
                            ~busy[7] ? 7:
                                ~busy[8] ? 8:
                                    ~busy[9] ? 9:
                                        ~busy[10] ? 10:
                                            ~busy[11] ? 11:
                                                ~busy[12] ? 12:
                                                    ~busy[13] ? 13:
                                                        ~busy[14] ? 14:
                                                            ~busy[15] ? 15:
                                                            `ZERO_RS;

    assign what_to_issue = ready_to_issue[1] ? 1:
        ready_to_issue[2] ? 2:
            ready_to_issue[3] ? 3:
                ready_to_issue[4] ? 4:
                    ready_to_issue[5] ? 5:
                        ready_to_issue[6] ? 6:
                            ready_to_issue[7] ? 7:
                                ready_to_issue[8] ? 8:
                                    ready_to_issue[9] ? 9:
                                        ready_to_issue[10] ? 10:
                                            ready_to_issue[11] ? 11:
                                                ready_to_issue[12] ? 12:
                                                    ready_to_issue[13] ? 13:
                                                        ready_to_issue[14] ? 14:
                                                            ready_to_issue[15] ? 15:
                                                            `ZERO_RS;
endmodule : reservation

