`timescale 1ns/1ps

// `define DEBUG_MACRO

// width and capacity
`define INSTRUCTION_WIDTH 31:0
`define DATA_WIDTH 31:0
`define OPERATION_BUS 5:0
`define OPERAND_BUS 31:0
`define REG_WIDTH 4:0
`define IMM_WIDTH 31:0
`define REG_ONEHOT_BOUND 31:0
`define REG_SIZE 32
`define ROB_WIDTH 3:0
`define ROB_SIZE 15
`define OP_RANGE 6:0
`define RS1_RANGE 19:15
`define RS2_RANGE 24:20
`define RD_RANGE 11:7
`define RS_WIDTH 3:0
`define RS_SIZE 15
`define RAM_WIDTH 7:0
`define ICACHE_WIDTH 127:0
`define ICACHE_SIZE 128
`define TAG_WIDTH 31:9
`define INDEX_WIDTH 8:2
`define PREDICTION_SLOT_SIZE 256
`define PREDICTION_HISTORY_SIZE 8
`define PREDICTION_INDEX_RANGE 9:2

// constant
`define ZERO_DATA 32'b0
`define ZERO_REG 8'b0
`define ZERO_ROB 8'b0
`define ZERO_RS 8'b0
`define TRUE 1'b1
`define FALSE 1'b0
`define PREDICTED 32'b0
`define MISPREDICTED 32'b1
`define UART_ADDR 32'h30000


// agreement
`define RAM_RD 1'b0
`define RAM_WT 1'b1

// opcode
`define LUI_OP 7'b0110111
`define AUIPC_OP 7'b0010111
`define JAL_OP 7'b1101111
`define JALR_OP 7'b1100111
`define BRANCH_OP 7'b1100011
`define LOAD_OP 7'b0000011
`define STORE_OP 7'b0100011
`define ARITHMETIC_IMM_OP 7'b0010011
`define ARITHMETIC_OP 7'b0110011

// funct3
`define BEQ3 3'b000
`define BNE3 3'b001
`define BLT3 3'b100
`define BGE3 3'b101
`define BLTU3 3'b110
`define BGEU3 3'b111
`define LB3 3'b000
`define LH3 3'b001
`define LW3 3'b010
`define LBU3 3'b100
`define LHU3 3'b101
`define SB3 3'b000
`define SH3 3'b001
`define SW3 3'b010
`define ADDorSUB3 3'b000
`define SLL3 3'b001
`define SLT3 3'b010
`define SLTU3 3'b011
`define XOR3 3'b100
`define SRLorA3 3'b101
`define OR3 3'b110
`define AND3 3'b111

// funct7
`define NORMAL_FUNCT7 7'b0000000
`define SPECIAL_FUNCT7 7'b0100000

// opcode inside CPU
`define NOP 6'd0
`define LUI 6'd1
`define AUIPC 6'd2
`define JAL 6'd3
`define JALR 6'd4
`define BEQ 6'd5
`define BNE 6'd6
`define BLT 6'd7
`define BGE 6'd8
`define BLTU 6'd9
`define BGEU 6'd10
`define LB 6'd11
`define LH 6'd12
`define LW 6'd13
`define LBU 6'd14
`define LHU 6'd15
`define SB 6'd16
`define SH 6'd17
`define SW 6'd18

`define ADDI 6'd36
`define SLTI 6'd37
`define SLTIU 6'd29
`define XORI 6'd30
`define ORI 6'd31
`define ANDI 6'd32
`define SLLI 6'd33
`define SRLI 6'd34
`define SRAI 6'd35

`define ADD 6'd19
`define SUB 6'd20
`define SLL 6'd21
`define SLT 6'd22
`define SLTU 6'd23
`define XOR 6'd24
`define SRL 6'd25
`define SRA 6'd26
`define OR 6'd27
`define AND 6'd28
