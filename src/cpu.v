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
    wire [`DATA_WIDTH ] fetcher_pc_last_pc, fetcher_inst, fetcher_mem_addr, fetcher_out_pc;
    wire fetcher_decoder_ena, fetcher_pc_ena, fetcher_taken, fetcher_mem_ena;
    // pc
    wire pc_rollback, pc_fetcher_next_taken;
    wire [`DATA_WIDTH ] pc_fetcher_next_pc,pc_fetcher_rollback_pc;
    // decode
    wire [`OPERATION_BUS ] decode_rs_op;
    wire [`REG_WIDTH ] decode_reg_regi1, decode_reg_regi2;
    wire [`ROB_WIDTH ] decode_rob_query_tag1, decode_rob_query_tag2;
    wire [`IMM_WIDTH ] decode_rs_imm;
    wire decode_out_has_dest;
    wire [`DATA_WIDTH ] decode_rs_operand1, decode_rs_operand2;
    wire [`ROB_WIDTH ] decode_rs_tag1, decode_rs_tag2;
    wire decode_ls_ena;
    wire [`ROB_WIDTH ] decode_out_rob;
    wire decode_out_assign_ena, decode_rob_taken;
    wire [`DATA_WIDTH ] decode_out_inst, decode_out_current_pc;
    wire [`REG_WIDTH ] decode_out_reg_rd;
    // RS
    wire [`OPERATION_BUS ] rs_alu_op;
    wire [`DATA_WIDTH ] rs_alu_Vj, rs_alu_Vk, rs_alu_imm, rs_alu_pc;
    wire [`ROB_WIDTH ] rs_alu_rd_rob_tag;
    wire rs_out_ready;
    // alu
    wire [`DATA_WIDTH ] alu_cdb_out, alu_cdb_jump_addr, alu_ls_data;
    wire [`ROB_WIDTH ] alu_cdb_rob_tag;
    wire alu_cdb_rob_jump_ena,alu_cdb_isload;
    // rob
    wire [`REG_WIDTH ] rob_reg_rd_reg;
    wire [`ROB_WIDTH ] rob_reg_rd_rob;
    wire [`DATA_WIDTH ] rob_reg_value;
    wire [`DATA_WIDTH ] rob_decode_value1, rob_decode_value2;
    wire rob_decode_rdy1, rob_decode_rdy2;
    wire [`ROB_WIDTH ] rob_out_available_tag, rob_ls_committed_tag;
    wire [`DATA_WIDTH ] rob_pc_branch_pc, rob_pc_correct_jump_addr;
    wire rob_pc_misbranch, rob_pc_taken, rob_pc_forwarding_ena;
    wire rob_out_ok;
    // memory
    wire mem_fetcher_ok, mem_ls_ok;
    wire [`DATA_WIDTH ] mem_fetcher_data, mem_ls_data;
    // register
    wire [`DATA_WIDTH ] reg_decode_value1, reg_decode_value2;
    wire [`ROB_WIDTH ] reg_decode_tag1, reg_decode_tag2;
    wire reg_decode_busy1, reg_decode_busy2;
    // lsqueue
    wire [`DATA_WIDTH ] ls_cdb_val;
    wire [`ROB_WIDTH ] ls_cdb_rob_tag;
    wire [`DATA_WIDTH ] ls_mem_addr, ls_mem_val;
    wire [2:0] ls_mem_size;
    wire ls_mem_ena, ls_mem_iswrite;
    wire ls_is_ok;
    // ram
    wire [`RAM_WIDTH ] ram_mem_output;


    // modules
    pc pc_reg(
        .clk(clk_in), .rst(rst_in), .ena(rdy_in),
        .in_fetcher_ena(fetcher_pc_ena),

        .in_last_pc(fetcher_out_pc), .in_last_inst(fetcher_inst),
        .out_next_pc(pc_fetcher_next_pc),.out_next_taken(pc_fetcher_next_taken),
        .out_rollback_pc(pc_fetcher_rollback_pc),

        .in_misbranch(rob_pc_misbranch), .in_forwarding_branch_taken(rob_pc_taken),
        .in_forwarding_branch_pc(rob_pc_branch_pc), .in_forwarding_correct_address(rob_pc_correct_jump_addr),

        .out_rollback(pc_rollback)
    );

    fetcher fetch_stage(
        .clk(clk_in), .rst(rst_in), .ena(rdy_in),
        .in_rollback(pc_rollback),

        .out_decoder_and_pc_ena(fetcher_decoder_ena), .out_branch_taken(fetcher_taken),
        .out_inst(fetcher_inst), .out_decoder_pc(fetcher_out_pc),

        .out_pc_reg_ena(fetcher_pc_ena),
        // .out_pc_query_taken(fetcher_pc_last_pc),


        .out_mem_ena(fetcher_mem_ena), .out_address(fetcher_mem_addr),

        .in_mem_ready(mem_fetcher_ok), .in_mem_inst(mem_fetcher_data),

        .in_normal_pc(pc_fetcher_next_pc), .in_rollback_pc(pc_fetcher_rollback_pc),
        .in_result_taken(pc_fetcher_next_taken),

        .in_rs_ok(rs_out_ready),.in_rob_ok(rob_out_ok),.in_lsqueue_ok(ls_is_ok)
    );

    decode decode_stage(
        .clk(clk_in), .ena(~rst_in && rdy_in && fetcher_decoder_ena ),
        .in_inst(fetcher_inst),
        .in_current_pc(fetcher_out_pc), .in_predicted_taken(fetcher_taken),

        .out_regi1(decode_reg_regi1), .out_regi2(decode_reg_regi2),

        .in_operand1(reg_decode_value1), .in_operand2(reg_decode_value2),
        .in_tag1(reg_decode_tag1), .in_tag2(reg_decode_tag2),
        .in_busy1(reg_decode_busy1), .in_busy2(reg_decode_busy2),

        .in_rob_tobe_tag(rob_out_available_tag),

        .out_query_tag1(decode_rob_query_tag1), .out_query_tag2(decode_rob_query_tag2),

        .in_query_tag1_ready(rob_decode_rdy1), .in_query_tag2_ready(rob_decode_rdy2),
        .in_query_ready_value1(rob_decode_value1), .in_query_ready_value2(rob_decode_value2),

        .out_rs_imm(decode_rs_imm),
        .out_rs_op(decode_rs_op),
        .out_operand1(decode_rs_operand1), .out_operand2(decode_rs_operand2),
        .out_tag1(decode_rs_tag1), .out_tag2(decode_rs_tag2),
        .out_lsqueue_ena(decode_ls_ena),.out_rd_rob_tag(decode_out_rob),

        .out_reg_rd(decode_out_reg_rd), .out_predicted_taken(decode_rob_taken),

        .out_assign_ena(decode_out_assign_ena), .out_current_pc(decode_out_current_pc),.out_inst(decode_out_inst)
    );

    reservation resevation_stage(
        .clk(clk_in), .rst(pc_rollback | rst_in), .ena(rdy_in),

        .assignment_ena(decode_out_assign_ena), .in_imm(decode_rs_imm),
        .in_op(decode_rs_op), .in_Qj(decode_rs_tag1), .in_Qk(decode_rs_tag2),
        .in_Vj(decode_rs_operand1), .in_Vk(decode_rs_operand2),
        .in_pc(decode_out_current_pc), .in_rd_rob(decode_out_rob),

        .in_alu_cdb_rob_tag(alu_cdb_rob_tag), .in_alu_cdb_data(alu_cdb_out),.in_alu_cdb_isload(alu_cdb_isload),
        .in_ls_cdb_rob_tag(ls_cdb_rob_tag), .in_ls_cdb_data(ls_cdb_val),

        .out_op(rs_alu_op),
        .out_Vj(rs_alu_Vj), .out_Vk(rs_alu_Vk),
        .out_rob_tag(rs_alu_rd_rob_tag), .out_pc(rs_alu_pc),
        .out_imm(rs_alu_imm),

        .has_capacity(rs_out_ready)
    );

    alu alu_unit(
        .clk(clk_in),

        .op(rs_alu_op), .in_rob_tag(rs_alu_rd_rob_tag),
        .pc(rs_alu_pc),
        .A(rs_alu_Vj), .B(rs_alu_Vk),
        .imm(rs_alu_imm),

        .out(alu_cdb_out), .out_rob_tag(alu_cdb_rob_tag),
        .out_ls_data(alu_ls_data),.out_is_load(alu_cdb_isload),

        .jump_ena(alu_cdb_rob_jump_ena), .jump_addr(alu_cdb_jump_addr)
    );

    ROB rob_stage(
        .clk(clk_in), .rst(rst_in | pc_rollback), .ena(rdy_in),

        .in_cdb_rob_tag(alu_cdb_rob_tag), .in_cdb_value(alu_cdb_out),.in_cdb_isload(alu_cdb_isload),
        .in_cdb_isjump(alu_cdb_rob_jump_ena), .in_cdb_jump_addr(alu_cdb_jump_addr),
        .in_ls_cdb_rob_tag(ls_cdb_rob_tag), .in_ls_cdb_value(ls_cdb_val),

        .in_assignment_ena(decode_out_assign_ena),
        .in_inst(decode_out_inst), .in_dest(decode_out_reg_rd), .in_pc(decode_out_current_pc),

        .in_predicted_taken(decode_rob_taken),

        .out_reg_reg(rob_reg_rd_reg), .out_reg_rob(rob_reg_rd_rob),
        .out_reg_value(rob_reg_value),

        .in_query_tag1(decode_rob_query_tag1), .in_query_tag2(decode_rob_query_tag2),

        .out_back_value1(rob_decode_value1), .out_back_value2(rob_decode_value2),
        .out_back_ready1(rob_decode_rdy1), .out_back_ready2(rob_decode_rdy2),
        .out_rob_available_tag(rob_out_available_tag),
        .out_rob_ok(rob_out_ok),

        .out_committed_rob_tag(rob_ls_committed_tag),

        .out_forwarding_ena(rob_pc_forwarding_ena),
        .out_forwarding_branch_pc(rob_pc_branch_pc),
        .out_misbranch(rob_pc_misbranch), .out_forwarding_taken(rob_pc_taken),
        .out_correct_jump_addr(rob_pc_correct_jump_addr)
    );

    memory mem_unit(
        .clk(clk_in), .rst(rst_in), .ena(rdy_in),
        .in_rollback(pc_rollback),

        .out_ram_rd_wt_flag(mem_wr),
        .out_ram_addr(mem_a),
        .out_ram_data(mem_dout), .in_ram_data(mem_din),

        .in_fetcher_ena(fetcher_mem_ena), .in_fetcher_addr(fetcher_mem_addr),
        .out_fetcher_ok(mem_fetcher_ok), .out_fetcher_data(mem_fetcher_data),

        .in_ls_ena(ls_mem_ena), .in_ls_iswrite(ls_mem_iswrite), .in_ls_addr(ls_mem_addr),
        .in_ls_data(ls_mem_val), .in_ls_size(ls_mem_size),
        .out_ls_data(mem_ls_data), .out_ls_ok(mem_ls_ok)
    );

    regFile register_unit(
        .clk(clk_in), .rst(rst_in), .ena(rdy_in),
        .in_rollback(pc_rollback),

        .read1(decode_reg_regi1), .read2(decode_reg_regi2),
        .value1(reg_decode_value1), .value2(reg_decode_value2),
        .rob_tag1(reg_decode_tag1), .rob_tag2(reg_decode_tag2),
        .busy1(reg_decode_busy1), .busy2(reg_decode_busy2),

        .in_assignment_ena(decode_out_assign_ena),
        .in_occupied_reg(decode_out_reg_rd), .in_occupied_rob_tag(decode_out_rob),

        .in_rob_reg_index(rob_reg_rd_reg), .in_rob_entry_tag(rob_reg_rd_rob),
        .in_new_value(rob_reg_value)
    );

    LSqueue lsbuffer_stage(
        .clk(clk_in), .rst(rst_in), .ena(rdy_in),
        .in_rollback(pc_rollback),

        .in_enqueue_ena(decode_ls_ena), .in_enqueue_rob_tag(decode_out_rob),
        .in_inst(decode_out_inst),

        .in_cdb_address(alu_cdb_out), .in_cdb_rob_tag(alu_cdb_rob_tag),
        .in_cdb_data(alu_ls_data),

        .in_commit_rob(rob_ls_committed_tag),

        .out_result(ls_cdb_val), .out_rob_tag(ls_cdb_rob_tag),

        .in_mem_ready(mem_ls_ok), .in_mem_read_data(mem_ls_data),
        .out_mem_addr(ls_mem_addr), .out_mem_write_data(ls_mem_val),
        .out_mem_ena(ls_mem_ena), .out_mem_iswrite(ls_mem_iswrite), .out_mem_size(ls_mem_size),

        .out_lsqueue_isok(ls_is_ok)

        //.debug_in_assign_pc(decode_out_current_pc)
    );

endmodule