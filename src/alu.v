`include "constant.v"
module alu(
    input clk,
    // from rs
    input [`OPERATION_BUS ] op, input [`ROB_WIDTH ] in_rob_tag,
    input [`DATA_WIDTH ] pc,
    input [`DATA_WIDTH ] A, input [`DATA_WIDTH ] B,
    input [`DATA_WIDTH ] imm,
    // to rs and rob and LSqueue
    output reg [`DATA_WIDTH ] out, output reg [`ROB_WIDTH ] out_rob_tag,
    output reg [`DATA_WIDTH ] out_ls_data,
    // to rob for jump
    output reg jump_ena, output reg[`DATA_WIDTH ] jump_addr
);
    // combinational logic
    always @(*) begin
        out_ls_data = B;
        out_rob_tag = in_rob_tag;
        jump_ena = `FALSE;
        case (op)
            // a b op
            `ADD : begin out = A+B; end
        `SUB: begin out = A-B; end
        `AND: begin out = A & B; end
        `OR: begin out = A | B; end
        `XOR: begin out = A ^ B; end
        `SLL: begin out = A << B; end
        `SRL: begin out = A >> B; end
        `SRA: begin out = A >>> B; end
        `SLTU: begin out = (A < B); end
        `SLT: begin out = $signed(A) < $signed(B); end
        // imm op
        `ADDI: begin out = A+imm; end
        `ANDI: begin out = A & imm; end
        `ORI: begin out = A | imm; end
        `XORI: begin out = A ^ imm; end
        `SLLI: begin out = A << imm; end
        `SRLI: begin out = A >> imm; end
        `SRAI: begin out = A >>> imm; end
        `SLTIU: begin out = (A < imm); end
        `SLTI: begin out = $signed(A) < $signed(imm); end
        // other
        `LUI: begin out = {imm, 12'b0}; end
        `AUIPC: begin out = pc+imm; end
        `JAL: begin out = pc+4; end // jump in fetch stage
        `JALR: begin
            out = pc+4;
            jump_addr = A+imm; jump_ena = `TRUE; end
        `BEQ: begin
            out = A == B;
            jump_addr = pc+out ? imm:4;
            jump_ena = out; end
        `BNE: begin out = A != B;
            jump_addr = pc+out ? imm:4;
            jump_ena = out; end
        `BLT: begin out = $signed(A) < $signed(B);
            jump_addr = pc+out ? imm:4;
            jump_ena = out; end
        `BGE: begin out = $signed(A) >= $signed(B);
            jump_addr = pc+out ? imm:4;
            jump_ena = out; end
        `BLTU: begin out = A < B;
            jump_addr = pc+out ? imm:4;
            jump_ena = out; end
        `BGEU: begin out = A >= B;
            jump_addr = pc+out ? imm:4;
            jump_ena = out; end
        `LW: begin out = A+imm; end
        `LHU: begin out = A+imm; end
        `LH: begin out = A+imm; end
        `LBU: begin out = A+imm; end
        `LB: begin out = A+imm; end
        `SW: begin out = A+imm; end
        `SH: begin out = A+imm; end
        `SB: begin out = A+imm; end
            default: begin
                out = `ZERO_DATA;
                out_rob_tag = `ZERO_DATA; end
        endcase

    end
endmodule : alu

