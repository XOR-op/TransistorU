`include "constant.v"

module ROB(
    input clk, input rst, input ena,
    // broadcast
    input [`ROB_WIDTH ] in_cdb_rob_tag, input [`DATA_WIDTH ] in_cdb_value, input in_cdb_isload,
    input in_cdb_isjump, input [`DATA_WIDTH ] in_cdb_jump_addr,
    input [`ROB_WIDTH ] in_ls_cdb_rob_tag, input [`DATA_WIDTH ] in_ls_cdb_value,
    // assignment by decoder
    input in_assignment_ena,
    input [`DATA_WIDTH ] in_inst, input [`REG_WIDTH ] in_dest,
    input [`DATA_WIDTH ] in_pc,
    // assignment info for branch prediction
    input in_predicted_taken,
    // write to registers
    output reg [`REG_WIDTH ] out_reg_reg, output reg [`ROB_WIDTH ] out_reg_rob,
    output reg [`DATA_WIDTH ] out_reg_value,
    // ROB ready from decoder
    input [`ROB_WIDTH ] in_query_tag1, input [`ROB_WIDTH ] in_query_tag2,
    // return to decoder
    output [`DATA_WIDTH ] out_back_value1, output [`DATA_WIDTH ] out_back_value2,
    output out_back_ready1, output out_back_ready2,
    output [`ROB_WIDTH ] out_rob_available_tag,
    output out_rob_ok,
    // commit to LSqueue for store
    output reg [`ROB_WIDTH ] out_committed_rob_tag,
    // misbranch
    output reg out_forwarding_ena,
    output reg [`DATA_WIDTH ] out_forwarding_branch_pc,
    output reg out_misbranch, output reg out_forwarding_taken,
    output reg [`DATA_WIDTH ] out_correct_jump_addr
`ifdef DEBUG_MACRO
    ,
    // debug
    output reg [`DATA_WIDTH ] debug_commit_pc, output reg [`DATA_WIDTH ] debug_commit_inst
`endif
);

    reg [7:0] head, tail;
    reg empty;
    // standard robs
    reg [`DATA_WIDTH ] data_arr [`ROB_SIZE :0];
    reg ready_arr [`ROB_SIZE :0];
    reg [`REG_WIDTH ] dest_arr [`ROB_SIZE :1];
    reg [`DATA_WIDTH ] inst_arr [`ROB_SIZE :1];
    // for branch prediction
    reg [`DATA_WIDTH ] pc_arr [`ROB_SIZE :1];
    reg predicted_taken [`ROB_SIZE :1];
    reg jump_flag_arr [`ROB_SIZE :1];
    reg [`DATA_WIDTH ] jump_addr_arr [`ROB_SIZE :1];
    reg peripheral_bit [`ROB_SIZE :0];

    // next available
    assign out_rob_available_tag = (empty || (head != tail)) ? tail:`ZERO_ROB;
    assign out_rob_ok = empty || (head != tail && !((tail+1 == head) || (tail == `ROB_SIZE && head == 1)));
    // decoder read
    assign out_back_ready1 = ready_arr[in_query_tag1];
    assign out_back_value1 = data_arr[in_query_tag1];
    assign out_back_ready2 = ready_arr[in_query_tag2];
    assign out_back_value2 = data_arr[in_query_tag2];
`ifdef DEBUG_MACRO
    reg [31:0] debug_counter = 0;
    initial begin
    debug_counter = 0;
    end
`endif
    always @(posedge clk) begin
        out_misbranch <= `FALSE;
        out_correct_jump_addr <= `ZERO_DATA;
        out_forwarding_ena <= `FALSE;
        out_committed_rob_tag <= `ZERO_ROB;
        if (rst) begin
            empty <= `TRUE;
            head <= 1;
            tail <= 1;
            ready_arr[`ZERO_ROB ] <= `FALSE;
            data_arr[`ZERO_ROB ] <= `ZERO_DATA;
            peripheral_bit[`ZERO_ROB ]<=0;
        end else if (ena) begin
            // assignment
            if (in_assignment_ena) begin
                ready_arr[tail] <= `FALSE;
                inst_arr[tail] <= in_inst;
                dest_arr[tail] <= in_dest;
                pc_arr[tail] <= in_pc;
                predicted_taken[tail] <= in_predicted_taken;
                peripheral_bit[tail] <= `FALSE;
                tail <= tail == `ROB_SIZE ? 1:tail+1;
                empty <= `FALSE;
            end
            // update
            if (in_cdb_rob_tag != `ZERO_ROB) begin
                if (!in_cdb_isload) begin
                    data_arr[in_cdb_rob_tag] <= in_cdb_value;
                    ready_arr[in_cdb_rob_tag] <= `TRUE;
                    jump_flag_arr[in_cdb_rob_tag] <= in_cdb_isjump;
                    jump_addr_arr[in_cdb_rob_tag] <= in_cdb_jump_addr;
                end else begin
                    // load 0x30000
                    if (in_cdb_value == `PERI_ADDR) begin
                        peripheral_bit[in_cdb_rob_tag] <= `TRUE;
                    end
                end
            end
            if (in_ls_cdb_rob_tag != `ZERO_ROB) begin
                // load
                data_arr[in_ls_cdb_rob_tag] <= in_ls_cdb_value;
                ready_arr[in_ls_cdb_rob_tag] <= `TRUE;
            end

            // commit
            if (!empty & (ready_arr[head]||peripheral_bit[head])) begin
                // work state
`ifdef DEBUG_MACRO
                if (inst_arr[head][`OP_RANGE ] != `STORE_OP && inst_arr[head][`OP_RANGE ] != `BRANCH_OP)
                debug_counter <= debug_counter+1;
                debug_commit_pc <= pc_arr[head];
                debug_commit_inst <= inst_arr[head];
`endif
                // update head
                if ((head+1 == tail) || (head == `RS_SIZE && tail == 1))
                    empty <= `TRUE;
                head <= (head == `RS_SIZE) ? 1:head+1;
                //ready_arr[head] <= `FALSE;// avoid decode query bug

                if (inst_arr[head][`OP_RANGE ] == `BRANCH_OP) begin
                    out_forwarding_ena <= `TRUE;
                    out_forwarding_taken <= jump_flag_arr[head];
                    out_forwarding_branch_pc <= pc_arr[head];
                    if (jump_flag_arr[head] ^ predicted_taken[head]) begin
                        // branch mispredicted
                        out_misbranch <= `TRUE;
                        out_correct_jump_addr <= jump_addr_arr[head];
                    end
                end else if (inst_arr[head][`OP_RANGE ] == `JALR_OP) begin
                    out_forwarding_taken <= `TRUE;
                    out_forwarding_ena <= `TRUE;
                    out_forwarding_branch_pc <= pc_arr[head];
                    out_misbranch <= `TRUE;
                    out_correct_jump_addr <= jump_addr_arr[head];
                    out_reg_reg <= dest_arr[head];
                    out_reg_rob <= head;
                    out_reg_value <= data_arr[head];
                end else if (inst_arr[head][`OP_RANGE ] == `STORE_OP) begin
                    // store
                    out_committed_rob_tag <= head;
                end else if (in_ls_cdb_rob_tag == head) begin
                    // load 0x30000 done
                    peripheral_bit[head] <= `FALSE;
                    out_reg_reg <= dest_arr[head];
                    out_reg_rob <= head;
                    out_reg_value <= in_ls_cdb_value;
                end else if (peripheral_bit[head]) begin
                    // wait for loading 0x30000
                    out_committed_rob_tag <= head;
                    empty <= empty;
                    head <= head; // keep
                end else begin
                    // write to register
                    out_reg_reg <= dest_arr[head];
                    out_reg_rob <= head;
                    out_reg_value <= data_arr[head];
                end
            end else begin
                // avoid latch
                out_reg_reg <= `ZERO_ROB;
                out_reg_value <= `ZERO_DATA;
            end

        end
    end
endmodule : ROB

