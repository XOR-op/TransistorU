`include "constant.v"

module reservation(
    input clk, input rst, input ena,
    // assignment
    input assignment_ena,
    input [`DATA_WIDTH ] in_imm,
    input [`OPERATION_BUS ] in_op,
    input [`ROB_WIDTH ] in_Qj, input [`ROB_WIDTH ] in_Qk,
    input [`DATA_WIDTH ] in_Vj, input [`DATA_WIDTH ] in_Vk,
    input [`DATA_WIDTH ] in_pc,
    input [`ROB_WIDTH ] in_rd_rob,
    input in_has_rd_dest,
    // CDB broadcast
    input [`ROB_WIDTH ] in_alu_cdb_rob_tag, input [`DATA_WIDTH ] in_alu_cdb_data,
    input [`ROB_WIDTH ] in_ls_cdb_rob_tag, input [`DATA_WIDTH ] in_ls_cdb_data,
    // pass to alu
    output reg [`OPERATION_BUS ] out_op,
    output reg [`DATA_WIDTH ] out_Vj, output reg [`DATA_WIDTH ] out_Vk,
    output reg [`ROB_WIDTH ] out_rob_tag, output reg [`DATA_WIDTH ] out_pc,
    output reg [`DATA_WIDTH ] out_imm,
    // return to decoder
    output has_capacity
);
    // inner storage
    reg [`OPERATION_BUS ] op [`RS_SIZE :0];
    reg [`ROB_WIDTH ] Qj [`RS_SIZE :0];
    reg [`ROB_WIDTH ] Qk [`RS_SIZE :0];
    reg [`DATA_WIDTH ] Vj [`RS_SIZE :0];
    reg [`DATA_WIDTH ] Vk [`RS_SIZE :0];
    reg [`DATA_WIDTH ] A [`RS_SIZE :0];
    reg busy [`RS_SIZE :0];
    reg [`ROB_WIDTH ] rob_tag [`RS_SIZE :0];
    reg [`DATA_WIDTH ] PCs [`RS_SIZE :0];
    reg [`DATA_WIDTH ] imms [`RS_SIZE :0];
    // control variable
    wire [`RS_WIDTH ] free_rs_tag;
    wire ready_to_issue [`RS_SIZE :1];
    wire [`RS_WIDTH ] what_to_issue;
    assign has_capacity = free_rs_tag!=`ZERO_RS ;

    // broadcast
    integer ii;
    always @(posedge clk) begin
        if (rst) begin
            for (ii = 0; ii <= `RS_SIZE;ii = ii+1)
                busy[ii] <= `FALSE;
        end
    end
    generate
        genvar i;
        for (i = 0;i <= `RS_SIZE;i = i+1) begin : broadcast_update
            always @(posedge clk) begin
                if (~rst && ena && Qj[i] == in_alu_cdb_rob_tag) begin
                    Qj[i] <= `ZERO_ROB;
                    Vj[i] <= in_alu_cdb_data;
                end
                if (~rst && ena && Qk[i] == in_alu_cdb_rob_tag) begin
                    Qk[i] <= `ZERO_ROB;
                    Vk[i] <= in_alu_cdb_data;
                end
                if (~rst && ena && Qj[i] == in_ls_cdb_rob_tag) begin
                    Qj[i] <= `ZERO_ROB;
                    Vj[i] <= in_ls_cdb_data;
                end
                if (~rst && ena && Qk[i] == in_ls_cdb_rob_tag) begin
                    Qk[i] <= `ZERO_ROB;
                    Vk[i] <= in_ls_cdb_data;
                end
            end
        end : broadcast_update
    endgenerate
    // assignment
    always @(posedge clk) begin
        if (~rst && ena && assignment_ena) begin
            // assignment
            op[free_rs_tag] <= in_op;
            {Qj[free_rs_tag], Qk[free_rs_tag]} <= {in_Qj, in_Qk};
            {Vj[free_rs_tag], Vk[free_rs_tag]} <= {in_Vj, in_Vk};
            busy[free_rs_tag] <= `TRUE;
            PCs[free_rs_tag] <= in_pc;
            imms[free_rs_tag] <= in_imm;
            rob_tag[free_rs_tag] <= in_has_rd_dest ? in_rd_rob:`ZERO_ROB;
        end
    end

    // choose op to ALU
    generate
        for (i = 1;i <= `RS_SIZE;i = i+1) begin : gen_ready_sig
            assign ready_to_issue[i] = busy[i] &(Qj[i] == `ZERO_ROB) &(Qk[i] == `ZERO_ROB);
        end
    endgenerate

    // priority encoder-like
    assign free_rs_tag=~busy[1]?1:
        ~busy[2]?2:
            ~busy[3]?3:
                ~busy[4]?4:
                    ~busy[5]?5:
                        ~busy[6]?6:
                            ~busy[7]?7:
                                ~busy[8]?8:
                                    ~busy[9]?9:
                                        ~busy[10]?10:
                                            ~busy[11]?11:
                                                ~busy[12]?12:
                                                    ~busy[13]?13:
                                                        ~busy[14]?14:
                                                            ~busy[15]?15:
                                                                `ZERO_RS ;
    always @(posedge clk) begin
        // issue to alu
        if (~rst && ena) begin
            // when what_to_issue =0, op==NOP
            out_op <= op[what_to_issue];
            out_Vk <= Vk[what_to_issue];
            out_Vj <= Vj[what_to_issue];
            out_rob_tag <= rob_tag[what_to_issue];
            out_pc <= PCs[what_to_issue];
            out_imm <= imms[what_to_issue];
            if (what_to_issue != `ZERO_RS) begin
                busy[what_to_issue] <= `FALSE;
            end
        end
    end


    assign what_to_issue=ready_to_issue[1]?1:
        ready_to_issue[2]?2:
            ready_to_issue[3]?3:
                ready_to_issue[4]?4:
                    ready_to_issue[5]?5:
                        ready_to_issue[6]?6:
                            ready_to_issue[7]?7:
                                ready_to_issue[8]?8:
                                    ready_to_issue[9]?9:
                                        ready_to_issue[10]?10:
                                            ready_to_issue[11]?11:
                                                ready_to_issue[12]?12:
                                                    ready_to_issue[13]?13:
                                                        ready_to_issue[14]?14:
                                                            ready_to_issue[15]?15:
                                                                `ZERO_RS ;
endmodule : reservation

