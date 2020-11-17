`include "constant.v"

module ROB(
    input clk, input rst, input ena,
    // broadcast
    input [`ROB_WIDTH ] in_cdb_rob_tag, input [`DATA_WIDTH ] in_cdb_value,
    input in_cdb_isjump, input [`DATA_WIDTH ] in_cdb_jump_addr,
    input [`ROB_WIDTH ] in_ls_cdb_rob_tag, input [`DATA_WIDTH ] in_ls_cdb_value,
    // assignment by decoder
    input [`ROB_WIDTH ] in_assignment_tag,
    input [`DATA_WIDTH ] in_inst, input [`REG_WIDTH ] in_dest,
    // assignment info for branch prediction
    input in_predicted_taken,
    // write to registers
    output [`REG_WIDTH ] out_reg_reg, output [`ROB_WIDTH ] out_reg_rob,
    output [`DATA_WIDTH ] out_reg_value,
    // write value to memory
    output [`DATA_WIDTH ] out_mem_address,
    // ROB ready from decoder
    input [`ROB_WIDTH ] in_query_tag1, input [`ROB_WIDTH ] in_query_tag2,
    // return to decoder
    output [`DATA_WIDTH ] out_back_value1, output [`DATA_WIDTH ] out_back_value2,
    output out_back_ready1, output out_back_ready2,
    output [`ROB_WIDTH ] out_rob_available_tag,
    // commit to LSqueue for store
    output [`ROB_WIDTH ] out_committed_rob_tag,
    // misbranch
    output out_forwarding_ena,
    output [`DATA_WIDTH ] out_forwarding_branch_pc,
    output out_misbranch, output out_forwarding_taken,
    output [`DATA_WIDTH ] out_correct_jump_addr
);

    reg [`DATA_WIDTH ] head = 0, tail = 1;
    // standard robs
    reg [`DATA_WIDTH ] data_arr [`ROB_SIZE :1];
    reg ready_arr [`ROB_SIZE :1];
    reg [`REG_WIDTH ] dest_arr [`ROB_SIZE :1];
    reg [`DATA_WIDTH ] inst_arr [`ROB_SIZE :1];
    // for branch prediction
    reg [`DATA_WIDTH ] pc_arr [`ROB_SIZE :1];
    reg predicted_taken [`ROB_SIZE :1];
    reg jump_flag_arr [`ROB_SIZE :1];
    reg [`DATA_WIDTH ] jump_addr_arr [`ROB_SIZE :1];

    assign out_rob_available_tag = head == tail ?`ZERO_ROB :tail;
    // decoder read
    always @(*) begin
        if (in_query_tag1 != `ZERO_ROB) begin
            out_back_ready1 = ready_arr[in_query_tag1];
            out_back_value1 = data_arr[in_query_tag1];
        end else begin
            out_back_ready1 = `FALSE;
            out_back_value1 = `ZERO_DATA;
        end
        if (in_query_tag2 != `ZERO_ROB) begin
            out_back_ready2 = ready_arr[in_query_tag2];
            out_back_value2 = data_arr[in_query_tag2];
        end else begin
            out_back_ready2 = `FALSE;
            out_back_value2 = `ZERO_DATA;
        end
    end
    always @(posedge clk) begin
        out_misbranch <= `FALSE;
        out_correct_jump_addr <= `ZERO_DATA;
        out_forwarding_ena <= `FALSE;
        if (rst) begin
            head <= 0;
            tail <= 1;
        end else if (ena) begin
            // assignment
            if (in_assignment_tag != `ZERO_ROB) begin
                ready_arr[tail] <= `FALSE;
                inst_arr[tail] <= in_inst;
                dest_arr[tail] <= in_dest;
                tail <= tail == `ROB_SIZE ? 1:tail+1;
                predicted_taken[tail] <= in_predicted_taken;
            end
            // update
            if (in_cdb_rob_tag != `ZERO_ROB) begin
                data_arr[in_cdb_rob_tag] <= in_cdb_value;
                ready_arr[in_cdb_rob_tag] <= `TRUE;
                jump_flag_arr[in_cdb_rob_tag] <= in_cdb_isjump;
                jump_addr_arr[in_cdb_rob_tag] <= in_cdb_jump_addr;
            end
            if (in_ls_cdb_rob_tag != `ZERO_ROB) begin
                data_arr[in_ls_cdb_rob_tag] <= in_ls_cdb_value;
                ready_arr[in_ls_cdb_rob_tag] <= `TRUE;
            end
            // commit
            // start from null-state
            if (head == 0) begin
                // move to work-state
                if (tail != 1)
                    head <= 1;
            end
            else if (ready_arr[head]) begin
                // work state
                if (inst_arr[head][`OP_RANGE ] == `BRANCH_OP) begin
                    out_forwarding_ena <= `TRUE;
                    if (jump_flag_arr[head] ^ predicted_taken[head]) begin
                        // branch mispredicted
                        out_misbranch <= `TRUE;
                        out_correct_jump_addr <= data_arr[head];
                    end
                end else if (inst_arr[head][`OP_RANGE ] == `JALR_OP) begin
                    out_forwarding_ena <= `TRUE;
                    out_misbranch <= `TRUE;
                    out_correct_jump_addr <= jump_addr_arr[head];
                    out_reg_reg <= dest_arr[head];
                    out_reg_rob <= head;
                    out_reg_value <= data_arr[head];
                end else if (inst_arr[head][`OP_RANGE ] == `STORE_OP) begin
                    // store
                    out_committed_rob_tag <= head;
                end else begin
                    // write to register
                    out_reg_reg <= dest_arr[head];
                    out_reg_rob <= head;
                    out_reg_value <= data_arr[head];
                end
                // update head and tail
                if ((head%`ROB_SIZE)+1 == tail) begin
                    // no existing robs
                    head <= 0;
                    tail <= 1;
                end else begin
                    head <= head == `ROB_SIZE ? 1:head+1;
                end
            end else begin
                // avoid latch
                out_reg_reg <= `ZERO_ROB;
                out_reg_value <= `ZERO_DATA;
            end

        end
    end
endmodule : ROB

