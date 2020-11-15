`include "constant.v"
module alu(
    input clk, input ena,
    // from rs
    input [`OPERATION_BUS ] op, input [`DATA_WIDTH ] A, input [`DATA_WIDTH ] B,
    input [`ROB_WIDTH ] in_rob_tag, input [`DATA_WIDTH ] pc, input [`DATA_WIDTH ] imm,
    // to rs and rob and LSqueue
    output [`DATA_WIDTH ] out, output [`ROB_WIDTH ] out_rob_tag,
    // to rob for jump
    output jump_ena, output [`DATA_WIDTH ] jump_addr
);
    // combinational logic
    assign out_rob_tag = in_rob_tag;
    always @(*) begin
        jump_ena = `FALSE;
        if (ena) begin
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
                default: begin
                    out = `ZERO_DATA; end
            endcase
        end

    end
endmodule : alu

