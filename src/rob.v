`include "constant.v"

module ROB(input clk, input rst,
    // broadcast
    input [`ROB_WIDTH ] cdb_rob_tag, input [`DATA_WIDTH ] cdb_value,
    // assignment by decoder
    input [`ROB_WIDTH ] assignment_tag,
    input [`OPERATION_BUS ] in_op, input [`REG_WIDTH ] in_dest,
    // write to registers
    output [`REG_WIDTH ] reg_tag, output [`DATA_WIDTH ] reg_value,
    // write value to memory
    output [`DATA_WIDTH ] address,
    // ROB ready from decoder
    input [`ROB_WIDTH ] query_tag1, input [`ROB_WIDTH ] query_tag2,
    // return to decoder
    output [`ROB_WIDTH ] back_value1, output [`ROB_WIDTH ] back_value2,
    output back_ready1, output back_ready2,
    output [`ROB_WIDTH ] available_tag,
    // to LSqueue
    output reg [`ROB_WIDTH ] just_allocated_rob_tag
);

    // regs and wires
    reg [`DATA_WIDTH ] data_arr [`ROB_COUNT :1];
    reg ready_arr [`ROB_COUNT :1];
    reg [`REG_WIDTH ] dest_arr [`ROB_COUNT :1];
    reg [`OPERATION_BUS ] op_arr [`ROB_COUNT :1];
    reg [`DATA_WIDTH ] head = 0, tail = 1;

    assign available_tag = head == tail ?`ZERO_ROB :tail;
    // decoder read
    always @(*) begin
        if (query_tag1 != `ZERO_ROB) begin
            back_ready1 = ready_arr[query_tag1];
            back_value1 = data_arr[query_tag1];
        end else begin
            back_ready1 = `FALSE;
            back_value1 = `ZERO_DATA;
        end
        if (query_tag2 != `ZERO_ROB) begin
            back_ready2 = ready_arr[query_tag2];
            back_value2 = data_arr[query_tag2];
        end else begin
            back_ready2 = `FALSE;
            back_value2 = `ZERO_DATA;
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            head <= 0;
            tail <= 1;
        end else begin
            // assignment
            if (assignment_tag != `ZERO_ROB) begin
                ready_arr[tail] <= `FALSE;
                op_arr[tail] <= in_op;
                dest_arr[tail] <= in_dest;
                tail <= tail == `ROB_COUNT ? 1:tail+1;
                just_allocated_rob_tag<=tail;
            end
            // update
            if (cdb_rob_tag != `ZERO_ROB) begin
                data_arr[cdb_rob_tag] <= cdb_value;
                ready_arr[cdb_rob_tag] <= `TRUE;
            end
            // commit
            // start from null-state
            if(head==0)begin
                // move to work-state
                if(tail!=1)
                    head<=1;
            end
            else if(ready_arr[head])begin
                // work state
                if()begin
                    // branch mispredicted

                end else if()begin
                    // store

                end else begin
                    reg_tag<=dest_arr[head];
                    reg_value<=data_arr[head];
                end
                // update head and tail
                if((head % `ROB_COUNT )+1==tail)begin
                    // no existing robs
                    head<=0;
                    tail<=1;
                end else begin
                    head<=head==`ROB_COUNT ?1:head+1;
                end
            end else begin
                // avoid latch
                reg_tag<=`ZERO_ROB ;
                reg_value<=`ZERO_DATA ;
            end

        end
    end
endmodule : ROB

