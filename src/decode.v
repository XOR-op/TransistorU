`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/03/2020 10:56:57 PM
// Design Name: 
// Module Name: decode
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "constant.v"
module decode(
    input clk, input ena,
    input [`INSTRUCTION_WIDTH] inst,
    // to regfile
    output [`REG_WIDTH ] rs1, output [`REG_WIDTH ] rs2,
    // from regfile
    input [`DATA_WIDTH ] in_operand1, input [`DATA_WIDTH ] in_operand2,
    input [`ROB_WIDTH ] in_tag1, input [`ROB_WIDTH ] in_tag2,
    input in_busy1, input in_busy2,
    // to ROB
    output [`ROB_WIDTH ] query_tag1, output [`ROB_WIDTH ] query_tag2,
    // from ROB
    input in_tag1_ready, input in_tag2_ready,
    input [`DATA_WIDTH ] ready_value1, input [`DATA_WIDTH ] ready_value2,
    // to RS
    output [`REG_WIDTH ] rd, output [`IMM_WIDTH ] imm, output [`OPERATION_BUS] op,
    output [`DATA_WIDTH ] operand1, output [`DATA_WIDTH ] operand2,
    output [`ROB_WIDTH ] tag1, output [`ROB_WIDTH ] tag2
);
    // may accelerate imm calculation?
    reg [`DATA_WIDTH ] I_IMM, S_IMM, U_IMM, B_IMM, J_IMM;
    assign I_IMM = {{21{inst[31]}}, inst[30:20]},
        S_IMM = {{21{inst[31]}}, inst[30:25], inst[11:7]},
        B_IMM = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0},
        U_IMM = {inst[31:12], 12'b0},
        J_IMM = {{12{inst31}}, inst[19:12], inst[20], inst[30:25], inst[24:21], 1'b0};
    // decode
    always @(posedge clk) begin
        if (ena) begin
            case (inst[6:0])
                `LUI_OP: begin
                op <= `LUI;
                imm <= U_IMM;
                {rs1, rs2, rd} <= {`ZERO_REG , `ZERO_REG , inst[`RD_RANGE ]};
            end
            `AUIPC_OP: begin

                op <= `AUIPC;
                imm <= U_IMM;
                {rs1, rs2, rd} <= {`ZERO_REG , `ZERO_REG , inst[`RD_RANGE ]};
            end
            `JAL_OP: begin
                op <= `JAL;
                imm <= J_IMM;
                {rs1, rs2, rd} <= {`ZERO_REG , `ZERO_REG , inst[`RD_RANGE ]};
            end
            `JALR_OP: begin
                op <= `JALR;
                imm <= I_IMM;
                {rs1, rs2, rd} <= {inst[`RS1_RANGE ], `ZERO_REG , inst[`RD_RANGE ]};
            end
            `BRANCH_OP: begin
                imm <= B_IMM;
                case (inst[14:12])
                    `BEQ3 : op <= `BEQ;
                        `BNE3 : op <= `BNE;
                        `BLT3 : op <= `BLT;
                        `BGE3: op <= `BGE;
                        `BLTU3 : op <= `BLTU;
                        `BGEU3 : op <= `BGEU;
                endcase
                {rs1, rs2, rd} <= {inst[`RS1_RANGE ], inst[`RS2_RANGE ], `ZERO_REG };
            end
            `LOAD_OP: begin
                imm <= I_IMM;
                case (inst[14:12])
                    `LB3: op <= `LB;
                        `LH3: op <= `LH;
                        `LW3: op <= `LW;
                        `LBU3: op <= `LBU;
                        `LHU3: op <= `LHU;
                endcase
                {rs1, rs2, rd} <= {inst[`RS1_RANGE ], `ZERO_REG , inst[`RD_RANGE ]};
            end
            `STORE_OP: begin
                imm <= S_IMM;
                case (inst[14:12])
                    `SB3 : op <= `SB;
                        `SH3 : op <= `SH3;
                        `SW3 : op <= `SH;
                endcase
                {rs1, rs2, rd} <= {inst[`RS1_RANGE ], inst[`RS2_RANGE ], inst[`RD_RANGE ]};
            end
            `ARITHMETIC_OP: begin
                case (inst[14:12])
                    `ADDorSUB3 : op <= (inst[31:25] == `NORMAL_FUNCT7) ?`ADD :`SUB;
                        `SLL3 : op <= `SLL;
                        `SLT3 : op <= `SLT;
                        `SLTU3 : op <= `SLTU;
                        `XOR3 : op <= `XOR;
                        `SRLorA3 : op <= (inst[31:25] == `NORMAL_FUNCT7) ?`SRL :`SRA;
                        `OR3 : op <= `OR;
                        `AND3 : op <= `AND;
                endcase
                {rs1, rs2, rd} <= {inst[`RS1_RANGE ], inst[`RS2_RANGE ], inst[`RD_RANGE ]};
            end
            `ARITHMETIC_IMM_OP: begin
                case (inst[14:12])
                    `ADDorSUB3 : op <= (inst[31:25] == `NORMAL_FUNCT7) ?`ADD :`SUB;
                        `SLL3 : op <= `SLL;
                        `SLT3 : op <= `SLT;
                        `SLTU3 : op <= `SLTU;
                        `XOR3 : op <= `XOR;
                        `SRLorA3 : op <= (inst[31:25] == `NORMAL_FUNCT7) ?`SRL :`SRA;
                        `OR3 : op <= `OR;
                        `AND3 : op <= `AND;
                endcase
                {rs1, rs2, rd} <= {inst[`RS1_RANGE ], `ZERO_REG , inst[`RD_RANGE ]};
            end
                default: begin
                    // avoid latch
                    imm <= 0;
                    op <= `NOP;
                    {rs1, rs2, rd} <= {`ZERO_REG ,`ZERO_REG ,`ZERO_REG };
                end
            endcase
        end
    end
    reg [`DATA_WIDTH ] reg_operand1, reg_operand2, rob_operand1, rob_operand2;
    // get operands and tags from regfile and output
    always @(*) begin
        reg_operand1 = in_operand1;
        reg_operand2 = in_operand2;
        query_tag1 = in_busy1 ? in_tag1:`ZERO_ROB;
        query_tag2 = in_busy2 ? in_tag2:`ZERO_ROB;
    end
    // get from ROB and output
    always @(*) begin
        rob_operand1=in_tag1_ready?ready_value1:`ZERO_DATA ;
        rob_operand2=in_tag2_ready?ready_value2:`ZERO_DATA ;
    end
    // decide output
    assign operand1 = in_tag1_ready ? rob_operand1:reg_operand1;
    assign operand2 = in_tag2_ready ? rob_operand2:reg_operand2;
    assign tag1 = in_tag1_ready ?`ZERO_ROB :in_tag1;
    assign tag2 = in_tag2_ready ?`ZERO_ROB :in_tag2;
endmodule: decode
