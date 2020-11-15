`include "constant.v"
module LSqueue(
    input clk, input rst,
    // input instruction
    input in_enqueue_ena, input [`ROB_WIDTH ] in_enqueue_rob_tag, input [`INSTRUCTION_WIDTH ] in_op,
    // input address and data
    input [`DATA_WIDTH ] in_address, input [`DATA_WIDTH] in_data, input [`ROB_WIDTH ] in_issue_rob_tag,
    // rob commit
    input [`DATA_WIDTH ] in_commit_rob,
    // out to rob and rs
    output reg [`DATA_WIDTH ] out_result, output reg [`ROB_WIDTH ] out_rob_tag,
    // with memory
    input in_mem_ready, input [`DATA_WIDTH ] in_mem_read_data,
    output reg out_mem_ena, output reg [`DATA_WIDTH ] out_mem_addr, output reg [`DATA_WIDTH ] out_mem_write_data,
    output reg out_mem_iswrite
);
    reg [`ROB_WIDTH ] buffered_rob_tag [`ROB_SIZE :1];
    reg [`INSTRUCTION_WIDTH] buffered_op [`ROB_SIZE :1];
    reg [`DATA_WIDTH ] buffered_address [`ROB_SIZE :1];
    reg [`DATA_WIDTH ] buffered_data [`ROB_SIZE :1];
    reg buffered_valid [`ROB_SIZE :1];
    reg committed [`ROB_SIZE :1];
    reg [`DATA_WIDTH ] head, tail;
    // LH and LB calls for signed-extension
    parameter IDLE=0, STORE=1, LOAD=2, LH=3, LB=4;
    reg [2:0] busy_stat;
    reg [`ROB_WIDTH ] pending_rob;
    integer i;

    always @(posedge clk) begin
        out_mem_ena <= `FALSE;
        out_rob_tag <= `ZERO_ROB;
        out_result <= `ZERO_DATA;
        if (rst) begin
            head <= 0;
            tail <= 1;
            busy_stat <= `FALSE;
        end else begin
            if (in_enqueue_ena) begin
                buffered_rob_tag[tail] <= in_enqueue_rob_tag;
                buffered_op[tail] <= in_op;
                buffered_valid[tail] <= `FALSE;
                committed[tail] <= `FALSE;
                tail <= tail == `ROB_SIZE ? 1:tail+1;
            end
            // broadcast
            for (i = 1; i <= `ROB_SIZE;i = i+1) begin
                // Only when rs1 and rs2 are both ready, instructions will be issued to ALU then CDB.
                // So when it comes to LSqueue, it will be ready immediately.
                if (in_issue_rob_tag == buffered_rob_tag[i]) begin
                    buffered_data[i] <= in_data;
                    buffered_address[i] <= in_address;
                    buffered_valid[i] <= `TRUE;
                end
                if (in_commit_rob == buffered_rob_tag[i])
                    committed[i] <= `TRUE;
            end
            // try to issue LOAD&STORE
            if (busy_stat == IDLE) begin
                if (head != 0 && buffered_valid[head] && (buffered_op[head][`OP_RANGE ] == `LOAD_OP || committed[head])) begin
                    out_mem_ena <= `TRUE;
                    pending_rob <= buffered_rob_tag[head];
                    if (buffered_op[head][`OP_RANGE ] == `LOAD_OP) begin
                        out_mem_iswrite <= `FALSE;
                        case (buffered_op[head][14:12])
                            3'b000: busy_stat <= LB;
                            3'b001: busy_stat <= LH;
                            default: busy_stat <= LOAD;
                        endcase
                        out_mem_write_data <= `ZERO_DATA;
                        out_mem_addr <= buffered_address[head];
                    end else begin
                        // store
                        out_mem_iswrite <= `TRUE;
                        out_mem_write_data <= buffered_data[head];
                        out_mem_addr <= buffered_address[head];
                        busy_stat <= STORE;
                    end
                end
            end else begin
                // wait for memory
                if (in_mem_ready) begin
                    busy_stat <= IDLE;
                    if (busy_stat != STORE) begin
                        out_rob_tag <= pending_rob;
                        case (busy_stat)
                            LB: out_result <= {{24{in_mem_read_data[7]}}, in_mem_read_data[7:0]};
                            LH: out_result <= {{16{in_mem_read_data[15]}}, in_mem_read_data[15:0]};
                            default: out_result <= in_mem_read_data;
                        endcase
                    end
                end
            end
        end

    end
endmodule : LSqueue