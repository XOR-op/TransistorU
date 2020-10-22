`include "constant.v"

module reservation(
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
    // pass to alu
    output reg [`OPERATION_BUS ] op,
    output reg [`DATA_WIDTH ] Vj, output reg [`DATA_WIDTH ] Vk, output reg [`DATA_WIDTH ] A,
    output reg [`ROB_WIDTH ] rob_tag,
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
    // control variable
    reg [`DATA_WIDTH ] size;
    assign has_capacity = size == `RS_COUNT;
    reg [`RS_WIDTH ] free_rs_tag;
    wire ready_to_issue [`RS_COUNT :1];
    reg issue_
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
        end
    end

    // *todo* choose op to ALU
    generate
        genvar i;
        for (i = 1;i <= `RS_COUNT;i++) begin : gen_ready_sig
            assign ready_to_issue[i]=busy[i]&(Qj[i]==`ZERO_ROB )&(Qk[i]==`ZERO_ROB );
        end
    endgenerate


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


