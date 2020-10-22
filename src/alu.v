`include "constant.v"
module alu(
    input clk, input ena,
    input [`OPERATION_BUS ] op, input [`DATA_WIDTH ] A, input [`DATA_WIDTH ] B, input [`ROB_WIDTH ] in_rob_tag,
    output [`OPERATION_BUS ] out, output [`ROB_WIDTH ] out_rob_tag
);
    // combinational logic
    assign out_rob_tag = in_rob_tag;
    always @(*) begin
        if (ena) begin
            case (op)
                `ADD : out <= A+B;
                    `SUB : out <= A-B;
                    `AND: out <= A & B;
                    `OR: out <= A | B;
                    `XOR : out <= A ^ B;
                    `SLL : out <= A << B;
                    `SRL : out <= A >> B;
                    `SRA : out <= A >>> B;
                    `SLTU : out <= (A < B);
                    `SLT : out <= (A[31] ^ B[31]) ? A[31]:{A-B}[31];
                default:
                    out <= `ZERO_DATA;
            endcase
        end

    end
endmodule : alu

