`include "constant.v"

module reservation(
    input clk, input rst,input ena,
    // assignment
    input assignment,
    input [`DATA_WIDTH ] in_imm,
    input [`OPERATION_BUS ] in_op,
    input [`ROB_WIDTH ] in_Qj, input [`ROB_WIDTH ] in_Qk,
    input [`DATA_WIDTH ] in_Vj, input [`DATA_WIDTH ] in_Vk,
    input [`DATA_WIDTH ] in_A,input [`DATA_WIDTH ] in_pc,
    // CDB broadcast
    input [`ROB_WIDTH ] newest_data_rob_tag, input [`DATA_WIDTH ] newest_data,
    // pass to alu
    output reg [`OPERATION_BUS ] out_op,
    output reg [`DATA_WIDTH ] out_Vj, output reg [`DATA_WIDTH ] out_Vk, output reg [`DATA_WIDTH ] out_A,
    output reg [`ROB_WIDTH ] out_rob_tag,output reg[`DATA_WIDTH ] out_pc,output reg[`DATA_WIDTH ]out_imm,
    // return to decoder
    output reg has_capacity
);
    // inner storage
    reg [`OPERATION_BUS ] op [`RS_COUNT :1];
    reg [`ROB_WIDTH ] Qj [`RS_COUNT :1];
    reg [`ROB_WIDTH ] Qk [`RS_COUNT :1];
    reg [`DATA_WIDTH ] Vj [`RS_COUNT :1];
    reg [`DATA_WIDTH ] Vk [`RS_COUNT :1];
    reg [`DATA_WIDTH ] A [`RS_COUNT :1];
    reg busy [`RS_WIDTH ];
    reg [`ROB_WIDTH ] rob_tag [`RS_COUNT :1];
    reg [`DATA_WIDTH ] PCs [`RS_COUNT :1];
    reg [`DATA_WIDTH ] imms[`RS_COUNT :1];
    // control variable
    reg [`DATA_WIDTH ] size;
    assign has_capacity = size == `RS_COUNT;
    reg [`RS_WIDTH ] free_rs_tag;
    wire ready_to_issue [`RS_COUNT :1];
    reg [`RS_WIDTH ] what_to_issue;
    // broadcast
    generate
        genvar i;
        for (i = 1;i <= `RS_COUNT;i++) begin : broadcast_update
            always @(posedge clk) begin
                if (~rst && Qj[i] == newest_data_rob_tag) begin
                    Qj[i] <= `ZERO_ROB;
                    Vj[i] <= newest_data;
                end
                if (~rst && Qk[i] == newest_data_rob_tag) begin
                    Qk[i] <= `ZERO_ROB;
                    Vk[i] <= newest_data;
                end
            end
        end : broadcast_update
    endgenerate
    // assignment
    always @(posedge clk) begin
        if (~rst && assignment) begin
            // assignment
            op[free_rs_tag] <= in_op;
            {Qj[free_rs_tag], Qk[free_rs_tag]} <= {in_Qj, in_Qk};
            {Vj[free_rs_tag], Vk[free_rs_tag]} <= {in_Vj, in_Vk};
            A[free_rs_tag] <= in_A;
            busy[free_rs_tag] <= 1'b1;
            PCs[free_rs_tag]<= in_pc;
            imms[free_rs_tag]<=in_imm;
        end
    end

    // choose op to ALU
    generate
        genvar i;
        for (i = 1;i <= `RS_COUNT;i++) begin : gen_ready_sig
            assign ready_to_issue[i] = busy[i] &(Qj[i] == `ZERO_ROB) &(Qk[i] == `ZERO_ROB);
        end
    endgenerate
    always @(*) begin
        case (ready_to_issue)
            15'b1xxxxxxxxxxxxxx: what_to_issue = 1;
            15'bx1xxxxxxxxxxxxx: what_to_issue = 2;
            15'bxx1xxxxxxxxxxxx: what_to_issue = 3;
            15'bxxx1xxxxxxxxxxx: what_to_issue = 4;
            15'bxxxx1xxxxxxxxxx: what_to_issue = 5;
            15'bxxxxx1xxxxxxxxx: what_to_issue = 6;
            15'bxxxxxx1xxxxxxxx: what_to_issue = 7;
            15'bxxxxxxx1xxxxxxx: what_to_issue = 8;
            15'bxxxxxxxx1xxxxxx: what_to_issue = 9;
            15'bxxxxxxxxx1xxxxx: what_to_issue = 10;
            15'bxxxxxxxxxx1xxxx: what_to_issue = 11;
            15'bxxxxxxxxxxx1xxx: what_to_issue = 12;
            15'bxxxxxxxxxxxx1xx: what_to_issue = 13;
            15'bxxxxxxxxxxxxx1x: what_to_issue = 14;
            15'bxxxxxxxxxxxxxx1: what_to_issue = 15;
            default: what_to_issue = `ZERO_RS;
        endcase
    end
    always @(posedge clk) begin
        // issue to alu
        if (~rst) begin
            out_op <= op[what_to_issue];
            out_Vk <= Vk[what_to_issue];
            out_Vj <= Vj[what_to_issue];
            out_A <= A[what_to_issue];
            out_rob_tag <= rob_tag[what_to_issue];
            out_pc<=PCs[what_to_issue];
            out_imm<=imms[what_to_issue];
        end
    end


    // priority encoder-like
    always @(*) begin
        case (busy)
            15'b1xxxxxxxxxxxxxx: free_rs_tag = 1;
            15'bx1xxxxxxxxxxxxx: free_rs_tag = 2;
            15'bxx1xxxxxxxxxxxx: free_rs_tag = 3;
            15'bxxx1xxxxxxxxxxx: free_rs_tag = 4;
            15'bxxxx1xxxxxxxxxx: free_rs_tag = 5;
            15'bxxxxx1xxxxxxxxx: free_rs_tag = 6;
            15'bxxxxxx1xxxxxxxx: free_rs_tag = 7;
            15'bxxxxxxx1xxxxxxx: free_rs_tag = 8;
            15'bxxxxxxxx1xxxxxx: free_rs_tag = 9;
            15'bxxxxxxxxx1xxxxx: free_rs_tag = 10;
            15'bxxxxxxxxxx1xxxx: free_rs_tag = 11;
            15'bxxxxxxxxxxx1xxx: free_rs_tag = 12;
            15'bxxxxxxxxxxxx1xx: free_rs_tag = 13;
            15'bxxxxxxxxxxxxx1x: free_rs_tag = 14;
            15'bxxxxxxxxxxxxxx1: free_rs_tag = 15;
            default: free_rs_tag = `ZERO_RS;
        endcase
    end
endmodule : reservation

/*
module reservationEntry(
    input clk, input rst,
    // assignment
    input assignment,
    input [`OPERATION_BUS ] in_op,
    input [`ROB_WIDTH ] in_Qj, input [`ROB_WIDTH ] in_Qk,
    input [`DATA_WIDTH ] in_Vj, input [`DATA_WIDTH ] in_Vk,
    input [`DATA_WIDTH ] in_A,
    input [`ROB_WIDTH ] in_rob_tag,
    // CDB broadcast
    input [`ROB_WIDTH ] newest_data_rob_tag, input [`DATA_WIDTH ] newest_data,
    // inner storage
    output reg [`OPERATION_BUS ] op,
    output reg [`ROB_WIDTH ] Qj, output reg [`ROB_WIDTH ] Qk,
    output reg [`DATA_WIDTH ] Vj, output reg [`DATA_WIDTH ] Vk,
    output reg [`DATA_WIDTH ] A, output reg busy,
    output reg [`ROB_WIDTH ] rob_tag
);
    always @(posedge clk) begin
        if (rst) begin
            op <= `NOP;
            {Qj, Qk} <= {`ZERO_ROB , `ZERO_ROB };
            {Vj, Vk} <= {`ZERO_DATA , `ZERO_DATA };
            A <= `ZERO_DATA;
            busy <= 1'b0;
        end
        else if (assignment) begin
            // assignment
            op <= in_op;
            {Qj, Qk} <= {in_Qj, in_Qk};
            {Vj, Vk} <= {in_Vj, in_Vk};
            A <= in_A;
            busy <= 1'b1;
        end
        else begin
            // broadcast
            if (newest_data_rob_tag == Qj) begin
                Qj <= `ZERO_ROB;
                Vj <= newest_data;
            end
            if (newest_data_rob_tag == Qk) begin
                Qk <= `ZERO_ROB;
                Vk <= newest_data;
            end
        end
    end
endmodule : reservation : reservationEntry
*/


