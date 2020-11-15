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
    // fetcher
    wire [`DATA_WIDTH ] fetcher_pc_last_pc, fetcher_inst, fetcher_mem_addr, fetcher_decoder_pc;
    wire fetcher_decoder_ena, fetcher_pc_ena, fetcher_taken, fetcher_mem_ena;
    // pc
    wire pc_clear_all,pc_fetcher_next_taken;
    wire [`DATA_WIDTH ] pc_fetcher_next_pc;
    // decode
    wire [`REG_WIDTH ] decode_reg_regi1, decode_reg_regi2;
    wire [`ROB_WIDTH ] decode_rob_query_tag1, decode_rob_query_tag2;
    wire decode_rs_ena;
    wire [`IMM_WIDTH ] decode_rs_imm, decode_rs_has_dest;
    wire [`OPERATION_BUS ] decode_rs_op;
    wire [`DATA_WIDTH ] decode_rs_operand1, decode_rs_operand2, decode_rs_current_pc;
    wire [`ROB_WIDTH ] decode_rs_tag1, decode_rs_tag2;
    wire decode_ls_ena;
    wire [`DATA_WIDTH ] decode_ls_op;
    wire [`ROB_WIDTH ] decode_out_rd_rob;
    wire decode_rob_assign_ena, decode_rob_taken;
    wire [`DATA_WIDTH ] decode_rob_inst, decode_rob_reg_rd;
    wire [`REG_WIDTH ] decode_rob_reg_rd;
    // RS
    wire [`OPERATION_BUS ] rs_alu_op;
    wire [`DATA_WIDTH ] rs_alu_Vj, rs_alu_Vk, rs_alu_imm, rs_alu_pc;
    wire [`ROB_WIDTH ] rs_alu_rd_rob_tag;
    wire rs_decoder_ready;
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
    wire rob_pc_misbranch, rob_pc_taken,rob_pc_forwarding_ena;
    // memory
    wire mem_ram_ena, mem_ram_rd_wt_flag, mem_fetcher_ok, mem_ls_ok;
    wire [`RAM_WIDTH ] mem_ram_data;
    wire [`DATA_WIDTH ] mem_ram_addr, mem_fetcher_data, mem_ls_data;
    // register
    wire [`DATA_WIDTH ] reg_decode_value1, reg_decode_value2;
    wire [`ROB_WIDTH ] reg_decode_tag1, reg_decode_tag2;
    wire reg_decode_busy1,reg_decode_busy2;
    // lsqueue
    wire [`DATA_WIDTH ] ls_cdb_val;
    wire [`ROB_WIDTH ] ls_cdb_rob_tag;
    wire [`DATA_WIDTH ] ls_mem_addr, ls_mem_val;
    wire ls_mem_ena, ls_mem_iswrite;
    // ram
    wire [`RAM_WIDTH ] ram_mem_output;


    // modules
    pc pc_reg(
        .clk(clk_in), .rst(rst_in),
        .in_fetcher_ena(fetcher_pc_ena),
        .in_last_pc(fetcher_pc_last_pc),.in_last_inst(fetcher_inst),
        .out_next_pc(pc_fetcher_next_pc),
        .in_misbranch(rob_pc_misbranch),.in_forwarding_branch_taken(rob_pc_taken),
        .in_forwarding_branch_pc(rob_pc_branch_pc),.in_forwarding_correct_address(rob_pc_correct_jump_addr),
        .out_clear_all(pc_clear_all)
    );

    fetcher fetch_stage(
        .clk(clk_in), .rst(rst_in),.ena(1),
        .out_decoder_ena(fetcher_decoder_ena),.out_branch_taken(fetcher_taken),
        .out_inst(fetcher_inst),.out_decoder_pc(fetcher_decoder_pc),
        .out_pc_reg_ena(fetcher_pc_ena),.out_pc_query_taken(fetcher_pc_last_pc),
        .in_result_taken(pc_fetcher_next_taken),
        .out_mem_ena(fetcher_mem_ena),.out_address(fetcher_mem_addr),
        .in_mem_ready(mem_fetcher_ok),.in_mem_inst(mem_fetcher_data),
        .in_pc(pc_fetcher_next_pc)
    );

    decode decode_stage(
        .clk(clk_in),.ena(~rst_in&rs_decoder_ready&rob_out_available_tag!=`ZERO_ROB ),
        .in_inst(fetcher_inst),
        .in_current_pc(fetcher_decoder_pc),.in_predicted_taken(fetcher_taken),
        .regi1(decode_reg_regi1),.regi2(decode_reg_regi2),
        .in_operand1(reg_decode_value1),.in_operand2(reg_decode_value2),
        .in_tag1(reg_decode_tag1),.in_tag2(reg_decode_tag2),
        .in_busy1(reg_decode_busy1),.in_busy2(reg_decode_busy2),
        .in_rob_tobe_tag(rob_out_available_tag),
        .out_query_tag1(decode_rob_query_tag1),.out_query_tag2(decode_rob_query_tag2),
        .in_query_tag1_ready(rob_decode_rdy1),.in_query_tag2_ready(rob_decode_rdy2),
        .in_query_ready_value1(rob_decode_value1),.in_query_ready_value2(rob_decode_value2),
        .out_rs_ena(decode_rs_ena),
        .out_rs_imm(decode_rs_imm),
        .out_rs_op(decode_rs_op),
        .out_operand1(decode_rs_operand1),.out_operand2(decode_rs_operand2),
        .out_tag1(decode_rs_tag1),.out_tag2(decode_rs_tag2),.out_current_pc(decode_rs_current_pc),
        .out_rs_has_dest(decode_rs_has_dest),
        .out_lsqueue_ena(decode_ls_ena),.out_lsqueue_op(decode_ls_op),.out_rd_rob_tag(decode_out_rd_rob),
        .out_rob_assign_ena(decode_rob_assign_ena),.out_rob_inst(decode_rob_inst),.out_reg_rd(decode_rob_reg_rd),
        .out_predicted_taken(decode_rob_taken)
    );
    reservation resevation_stage(
        .clk(clk_in),.rst(pc_clear_all|rst_in),.ena(1),
        .assignment_ena(decode_rs_ena),.in_imm(decode_rs_imm),
        .in_op(decode_rs_op),.in_Qj(decode_rs_tag1),.in_Qk(decode_rs_tag2),
        .in_Vj(decode_rs_operand1),.in_Vk(decode_rs_operand2),
        .in_pc(decode_rs_current_pc),.in_rd_rob(decode_out_rd_rob)
    );
    alu alu_unit();
    rob rob_stage();
    memory mem_unit();
    regFile register_unit();
    LSqueue lsbuffer_stage();
    ram ram_unit();

endmodule : cpu