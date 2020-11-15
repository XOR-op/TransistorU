// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "pc.v"
`include "fetch.v"
`include "decode.v"
`include "alu.v"
`include "rob.v"
`include "reservation.v"
`include "LSqueue.v"
`include "ram.v"
`include "registers.v"
`include "memory.v"
module cpu(
    input wire clk_in,            // system clock signal
    input wire rst_in,            // reset signal
    input wire rdy_in,            // ready signal, pause cpu when low

    input wire [7:0] mem_din,        // data input bus
    output wire [7:0] mem_dout,        // data output bus
    output wire [31:0] mem_a,            // address bus (only 17:0 is used)
    output wire mem_wr,            // write/read signal (1 for write)

    input wire io_buffer_full, // 1 if uart buffer is full

    output wire [31:0] dbgreg_dout        // cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)
    // fetcher out
    wire [`DATA_WIDTH ] fetcher_pc_last_pc, fetcher_inst, fetcher_mem_addr, fetcher_decoder_pc;
    wire fetcher_decoder_ena, fetcher_pc_ena, fetcher_taken, fetcher_mem_ena;
    // pc out
    wire pc_clear_all, pc_fetcher_next_pc;
    // decode out
    wire [`REG_WIDTH ] decode_reg_rs1, decode_reg_rs2;
    wire [`ROB_WIDTH ] decode_rob_query_tag1, decode_rob_query_tag2;
    wire decode_rs_ena;
    wire [`IMM_WIDTH ] decode_rs_imm, decode_rs_has_dest;
    wire [`OPERATION_BUS ] decode_rs_op;
    wire [`DATA_WIDTH ] decode_rs_operand1, decode_rs_operand2, decode_rs_current_pc;
    wire [`ROB_WIDTH ] decode_rs_tag1, decode_rs_tag2;
    wire decode_ls_ena;
    wire [`DATA_WIDTH ] decode_ls_op;
    wire decode_rob_assign_ena, decode_rob_taken;
    wire [`DATA_WIDTH ] decode_rob_inst, decode_rob_reg_rd;
    wire [`REG_WIDTH ] decode_rob_reg_rd;
    // RS
    wire [`OPERATION_BUS ] rs_alu_op;
    wire [`DATA_WIDTH ] rs_alu_Vj, rs_alu_Vk, rs_alu_imm, rs_alu_pc;
    wire [`ROB_WIDTH ] rs_alu_rd_rob_tag;
    // alu
    wire [`DATA_WIDTH ] alu_cdb_out, alu_cdb_jump_addr;
    wire [`ROB_WIDTH ] alu_cdb_rob_tag;
    wire alu_cdb_rob_jump_ena;
    // rob
    wire [`REG_WIDTH ] rob_reg_rd_tag;
    wire [`DATA_WIDTH ] rob_reg_value;
    wire [`DATA_WIDTH ] rob_mem_addr;
    wire [`DATA_WIDTH ] rob_decode_value1, rob_decode_value2;
    wire rob_decode_rdy1, rob_decode_rdy2;
    wire [`ROB_WIDTH ] rob_out_available_tag, rob_ls_committed_tag;
    wire [`DATA_WIDTH ] rob_pc_branch_pc, rob_pc_correct_jump_addr;
    wire rob_pc_misbranch, rob_pc_taken;
    // memory
    wire mem_ram_ena, mem_ram_rd_wt_flag, mem_fetcher_ok, mem_ls_ok;
    wire [`RAM_WIDTH ] mem_ram_data;
    wire [`DATA_WIDTH ] mem_ram_addr, mem_fetcher_data, mem_ls_data;
    // register
    wire [`DATA_WIDTH ] reg_decode_value1, reg_decode_value2;
    wire [`ROB_WIDTH ] reg_decode_tag1, reg_decode_tag2;
    // lsqueue
    wire [`DATA_WIDTH ] ls_cdb_val;
    wire [`ROB_WIDTH ] ls_cdb_rob_tag;
    wire [`DATA_WIDTH ] ls_mem_addr, ls_mem_val;
    wire ls_mem_ena, ls_mem_iswrite;
    // ram
    wire [`RAM_WIDTH ] ram_mem_output;


    // modules
    pc pc_reg(.clk(clk_in), .rst(rst_in));
    fetcher fetch_stage(.clk(clk_in), .rst(rst_in));
    decode decode_stage();
    reservation resevation_stage();
    alu alu_unit();
    rob rob_stage();
    memory mem_unit();
    regFile register_unit();
    LSqueue lsbuffer_stage();
    ram ram_unit();

endmodule : cpu