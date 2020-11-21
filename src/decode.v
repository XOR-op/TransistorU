`include "constant.v"
module decode(
    // if rob or rs is not ready, ena will be inhibited
    input clk, input ena,
    input [`INSTRUCTION_WIDTH] in_inst,
    input [`DATA_WIDTH ] in_current_pc, input in_predicted_taken,
    // to regfile
    output reg [`REG_WIDTH ] out_regi1, output reg [`REG_WIDTH ] out_regi2,
    // from regfile
    input [`DATA_WIDTH ] in_operand1, input [`DATA_WIDTH ] in_operand2,
    input [`ROB_WIDTH ] in_tag1, input [`ROB_WIDTH ] in_tag2,
    input in_busy1, input in_busy2,
    // from ROB of sequential logic than pass to next
    input [`ROB_WIDTH ] in_rob_tobe_tag,
    // to ROB query
    output [`ROB_WIDTH ] out_query_tag1, output [`ROB_WIDTH ] out_query_tag2,
    // query result from ROB
    input in_query_tag1_ready, input in_query_tag2_ready,
    input [`DATA_WIDTH ] in_query_ready_value1, input [`DATA_WIDTH ] in_query_ready_value2,
    // to RS
    output reg [`IMM_WIDTH ] out_rs_imm,
    output reg [`OPERATION_BUS] out_rs_op,
    output [`DATA_WIDTH ] out_operand1, output [`DATA_WIDTH ] out_operand2,
    output [`ROB_WIDTH ] out_tag1, output [`ROB_WIDTH ] out_tag2,
    // to LSqueue
    output reg out_lsqueue_ena, output [`ROB_WIDTH ] out_rd_rob_tag,
    // to ROB assignment
    output reg [`REG_WIDTH ] out_reg_rd, output reg out_predicted_taken,
    // ROB RS Regfile
    output reg out_assign_ena, output reg [`DATA_WIDTH ] out_current_pc, output reg [`DATA_WIDTH ] out_inst
);
    wire [`DATA_WIDTH ] I_IMM, S_IMM, U_IMM, B_IMM, J_IMM;
    assign I_IMM = {{21{in_inst[31]}}, in_inst[30:20]},
        S_IMM = {{21{in_inst[31]}}, in_inst[30:25], in_inst[11:7]},
        B_IMM = {{20{in_inst[31]}}, in_inst[7], in_inst[30:25], in_inst[11:8], 1'b0},
        U_IMM = {in_inst[31:12], 12'b0},
        J_IMM = {{12{in_inst[31]}}, in_inst[19:12], in_inst[20], in_inst[30:25], in_inst[24:21], 1'b0};
    // decode
    assign out_rd_rob_tag = in_rob_tobe_tag;
    always @(posedge clk) begin
        out_predicted_taken <= in_predicted_taken;
        out_current_pc <= in_current_pc;
        out_inst <= in_inst;
        out_lsqueue_ena <= `FALSE;
        out_assign_ena <= `FALSE;
        out_reg_rd <= `ZERO_REG;
        if (ena) begin
            out_assign_ena <= `TRUE;
            case (in_inst[`OP_RANGE ])
                `LUI_OP: begin
                out_rs_op <= `LUI;
                out_rs_imm <= U_IMM;
                {out_regi1, out_regi2, out_reg_rd} <= {`ZERO_REG , `ZERO_REG , in_inst[`RD_RANGE ]};
                out_regi1 <= `ZERO_REG;
                out_regi2 <= `ZERO_REG;
                out_reg_rd <= in_inst[`RD_RANGE ];
            end
            `AUIPC_OP: begin
                out_rs_op <= `AUIPC;
                out_rs_imm <= U_IMM;
                {out_regi1, out_regi2, out_reg_rd} <= {`ZERO_REG , `ZERO_REG , in_inst[`RD_RANGE ]};
                out_regi1 <= `ZERO_REG;
                out_regi2 <= `ZERO_REG;
                out_reg_rd <= in_inst[`RD_RANGE ];
            end
            `JAL_OP: begin
                out_rs_op <= `JAL;
                out_rs_imm <= J_IMM;
                {out_regi1, out_regi2, out_reg_rd} <= {`ZERO_REG , `ZERO_REG , in_inst[`RD_RANGE ]};
                out_regi1 <= `ZERO_REG;
                out_regi2 <= `ZERO_REG;
                out_reg_rd <= in_inst[`RD_RANGE ];
            end
            `JALR_OP: begin
                out_rs_op <= `JALR;
                out_rs_imm <= I_IMM;
                out_regi1 <= in_inst[`RS1_RANGE ];
                out_regi2 <= `ZERO_REG;
                out_reg_rd <= in_inst[`RD_RANGE ];
            end
            `BRANCH_OP: begin
                out_rs_imm <= B_IMM;
                case (in_inst[14:12])
                    `BEQ3 : out_rs_op <= `BEQ;
                        `BNE3 : out_rs_op <= `BNE;
                        `BLT3 : out_rs_op <= `BLT;
                        `BGE3: out_rs_op <= `BGE;
                        `BLTU3 : out_rs_op <= `BLTU;
                        `BGEU3 : out_rs_op <= `BGEU;
                endcase
                out_regi1 <= in_inst[`RS1_RANGE ];
                out_regi2 <= in_inst[`RS2_RANGE ];
                out_reg_rd <= `ZERO_REG;
            end
            `LOAD_OP: begin
                out_rs_imm <= I_IMM;
                case (in_inst[14:12])
                    `LB3: out_rs_op <= `LB;
                        `LH3: out_rs_op <= `LH;
                        `LW3: out_rs_op <= `LW;
                        `LBU3: out_rs_op <= `LBU;
                        `LHU3: out_rs_op <= `LHU;
                endcase
                out_lsqueue_ena <= `TRUE;
                out_regi1 <= in_inst[`RS1_RANGE ];
                out_regi2 <= `ZERO_REG;
                out_reg_rd <= in_inst[`RD_RANGE ];
            end
            `STORE_OP: begin
                out_rs_imm <= S_IMM;
                case (in_inst[14:12])
                    `SB3 : out_rs_op <= `SB;
                        `SH3 : out_rs_op <= `SH;
                        `SW3 : out_rs_op <= `SH;
                endcase
                out_lsqueue_ena <= `TRUE;
                out_regi1 <= in_inst[`RS1_RANGE ];
                out_regi2 <= in_inst[`RS2_RANGE ];
                out_reg_rd <= `ZERO_REG;
            end
            `ARITHMETIC_OP: begin
                out_rs_imm <= `ZERO_DATA;
                case (in_inst[14:12])
                    `ADDorSUB3 : out_rs_op <= (in_inst[31:25] == `NORMAL_FUNCT7) ?`ADD :`SUB;
                        `SLL3 : out_rs_op <= `SLL;
                        `SLT3 : out_rs_op <= `SLT;
                        `SLTU3 : out_rs_op <= `SLTU;
                        `XOR3 : out_rs_op <= `XOR;
                        `SRLorA3 : out_rs_op <= (in_inst[31:25] == `NORMAL_FUNCT7) ?`SRL :`SRA;
                        `OR3 : out_rs_op <= `OR;
                        `AND3 : out_rs_op <= `AND;
                endcase
                out_regi1 <= in_inst[`RS1_RANGE ];
                out_regi2 <= in_inst[`RS2_RANGE ];
                out_reg_rd <= in_inst[`RD_RANGE ];
            end
            `ARITHMETIC_IMM_OP: begin
                out_rs_imm <= I_IMM;
                case (in_inst[14:12])
                    `ADDorSUB3 : out_rs_op <= `ADDI;
                        `SLL3 : out_rs_op <= `SLLI;
                        `SLT3 : out_rs_op <= `SLTI;
                        `SLTU3 : out_rs_op <= `SLTIU;
                        `XOR3 : out_rs_op <= `XORI;
                        `SRLorA3 : begin
                        out_rs_op <= (in_inst[31:25] == `NORMAL_FUNCT7) ?`SRLI :`SRAI;
                        out_rs_imm <= I_IMM[4:0]; end
                    `OR3: out_rs_op <= `ORI;
                        `AND3 : out_rs_op <= `ANDI;
                endcase
                out_regi1 <= in_inst[`RS1_RANGE ];
                out_regi2 <= `ZERO_REG;
                out_reg_rd <= in_inst[`RD_RANGE ];
            end
                default: begin
                    // avoid latch
                    out_rs_imm <= 0;
                    out_rs_op <= `NOP;
                    out_regi1 <= `ZERO_REG;
                    out_regi2 <= `ZERO_REG;
                    out_reg_rd <= `ZERO_REG;
                end
            endcase
        end
    end
    wire [`DATA_WIDTH ] reg_operand1, reg_operand2, rob_operand1, rob_operand2;
    // get operands and tags from regfile and output
    assign reg_operand1 = in_operand1;
    assign reg_operand2 = in_operand2;
    assign out_query_tag1 = in_busy1 ? in_tag1:`ZERO_ROB;
    assign out_query_tag2 = in_busy2 ? in_tag2:`ZERO_ROB;
    // get from ROB and output
    assign rob_operand1 = in_query_tag1_ready ? in_query_ready_value1:`ZERO_DATA;
    assign rob_operand2 = in_query_tag2_ready ? in_query_ready_value2:`ZERO_DATA;
    // decide output
    assign out_operand1 = in_query_tag1_ready ? rob_operand1:reg_operand1;
    assign out_operand2 = in_query_tag2_ready ? rob_operand2:reg_operand2;
    assign out_tag1 = in_query_tag1_ready ?`ZERO_ROB :in_tag1;
    assign out_tag2 = in_query_tag2_ready ?`ZERO_ROB :in_tag2;

endmodule : decode

