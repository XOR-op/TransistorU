`include "constant.v"
module alu(
    input clk, input ena,
    // from rs
    input [`OPERATION_BUS ] op, input [`DATA_WIDTH ] A, input [`DATA_WIDTH ] B,
    input [`ROB_WIDTH ] in_rob_tag, input [`DATA_WIDTH ] pc, input [`DATA_WIDTH ] imm,
    // to rs and rob
    output [`OPERATION_BUS ] out, output [`ROB_WIDTH ] out_rob_tag,
    // to pc
    output jump_ena, output [`DATA_WIDTH ] jump_addr
);
    // combinational logic
    assign out_rob_tag = in_rob_tag;
    always @(*) begin
        jump_ena = op == `JALR;
        if (ena) begin
            case (op)
                // a b op
                `ADD : out = A+B;
                    `SUB : out = A-B;
                    `AND: out = A & B;
                    `OR: out = A | B;
                    `XOR : out = A ^ B;
                    `SLL : out = A << B;
                    `SRL : out = A >> B;
                    `SRA : out = A >>> B;
                    `SLTU : out = (A < B);
                // `SLT : out <= (A[31] ^ B[31]) ? A[31]:{A-B}[31];
                    `SLT : out = $signed(A) < $signed(B);
                // imm op
                    `ADDI : out = A+imm;
                    `ANDI: out = A & imm;
                    `ORI: out = A | imm;
                    `XORI : out = A ^ imm;
                    `SLLI: out = A << imm;
                    `SRLI: out = A >> imm;
                    `SRAI: out = A >>> imm;
                    `SLTIU : out = (A < imm);
                // `SLTI : out <= (A[31] ^ imm[31]) ? A[31]:{A-imm}[31];
                    `SLTI : out = $signed(A) < $signed(imm);
                // other
                    `LUI: out = {imm, 12'b0};
                    `AUIPC : out = pc+imm;
                    `JAL : begin
                    out = pc+4;
                end
                `JALR: begin
                out = pc+4;
                jump_addr = A+imm;
            end
            `BEQ: begin
                out = A == B;
            end
            `BNE: out = A != B;
                    `BLT: out = $signed(A) < $signed(B);
                    `BGE : out = $signed(A) >= $signed(B);
                    `BLTU : out = A < B;
                    `BGEU : out = A >= B;
                default:
                    out = `ZERO_DATA;
            endcase
        end

    end
endmodule : alu

