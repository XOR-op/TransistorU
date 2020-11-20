`include "constant.v"
module regFile(
    input clk, input rst, input ena,
    // misbranch
    input in_rollback,
    // decoder read value
    input [`REG_WIDTH ] read1, input [`REG_WIDTH ] read2,
    output reg [`DATA_WIDTH ] value1, output reg [`DATA_WIDTH ] value2,
    output reg [`ROB_WIDTH ] rob_tag1, output reg [`ROB_WIDTH ] rob_tag2,
    output reg busy1, output reg busy2,
    // set rd's rob_tag by decoder
    input in_assignment_ena,
    input [`REG_WIDTH ] in_occupied_reg, input [`ROB_WIDTH ] in_occupied_rob_tag,
    // set value by rob
    input [`REG_WIDTH ] in_rob_reg_index, input [`ROB_WIDTH ] in_rob_entry_tag,
    input [`DATA_WIDTH ] in_new_value
);
    reg [`DATA_WIDTH ] datas [`REG_SIZE -1:0];
    reg [`ROB_WIDTH ] rob_tags [`REG_SIZE -1:0];
    reg busy [`REG_SIZE -1:0];

    always @(posedge clk) begin
        if (rst) begin
            datas[`ZERO_REG ] <= `ZERO_DATA;
            rob_tags[`ZERO_REG ] <= `ZERO_ROB;
            busy[`ZERO_REG ] <= `FALSE;
        end
    end
    generate
        genvar regi;
        // reg[0] is always 0
        for (regi = 1;regi < `REG_SIZE;regi = regi+1) begin : genreg
            always @(posedge clk) begin
                if (rst) begin
                    datas[regi] <= `ZERO_DATA;
                    rob_tags[regi] <= `ZERO_ROB;
                    busy[regi] <= `FALSE;
                end else if (in_rollback) begin
                    rob_tags[regi]<=`ZERO_ROB ;
                    busy[regi] <= `FALSE;
                end else if (ena) begin
                    if (in_rob_reg_index == regi) begin
                        // set by rob
                        datas[regi] <= in_new_value;
                        if (in_rob_entry_tag == rob_tags[regi]) begin
                            // not busy
                            rob_tags[regi] <= `ZERO_ROB;
                            busy[regi] <= `FALSE;
                        end
                    end
                    if (in_assignment_ena&&in_occupied_reg == regi) begin
                        rob_tags[regi] <= in_occupied_rob_tag;
                        busy[regi] <= `TRUE;
                    end
                end
            end
        end
    endgenerate
    always @(*) begin
        // for reg0 is always 0, read1 and read2 are always available
        value1 = datas[read1];
        value2 = datas[read2];
        rob_tag1 = rob_tags[read1];
        rob_tag2 = rob_tags[read2];
        busy1 = busy[read1];
        busy2 = busy[read2];
    end

endmodule: regFile
