`include "constant.v"
module regFile(
    input clk, input rst,
    // decoder read value
    input [`REG_WIDTH ] read1, input [`REG_WIDTH ] read2,
    output reg [`DATA_WIDTH ] value1, output reg [`DATA_WIDTH ] value2,
    output reg [`ROB_WIDTH ] rob_tag1, output reg [`ROB_WIDTH ] rob_tag2,
    output reg busy1,output busy2,
    // set rd's rob_tag by decoder
    input [`REG_WIDTH ] occupied_reg1, input [`ROB_WIDTH ] occupied_rob_tag1,
    // input [`REG_WIDTH ] occupied_reg2, input [`ROB_WIDTH ] occupied_rob_tag2,
    // set value by rob
    input [`REG_WIDTH ] set_value, input [`ROB_WIDTH ] in_rob_entry_tag,
    input [`DATA_WIDTH ] in_new_value
);
    reg [`DATA_WIDTH ] datas [`REG_SIZE -1:0];
    reg [`ROB_WIDTH ] rob_tags [`REG_SIZE -1:0];
    reg busy [`REG_SIZE -1:0];
    generate
        genvar regi;
        for (regi = 0;regi < `REG_SIZE;regi = regi+1) begin : genreg
            always @(posedge clk) begin
                if (set_value != `ZERO_REG && set_value == regi) begin
                    // set by rob
                    datas[regi] <= in_new_value;
                    if (in_rob_entry_tag == rob_tags[regi]) begin
                        // not busy
                        rob_tags[regi] <= `ZERO_ROB;
                        busy[regi] <= `ZERO_ROB;
                    end
                end
                if (occupied_reg1 != `ZERO_REG && occupied_reg1 == regi) begin
                    rob_tags[regi] <= occupied_rob_tag1;
                    busy[regi] <= `TRUE;
                end
                // if (occupied_reg2 != `ZERO_REG && occupied_reg2 == regi) begin
                //     rob_tags[regi] <= occupied_rob_tag2;
                //     busy[regi] <= `TRUE;
                // end
            end
        end
    endgenerate
    always @(*) begin
        // for reg0 is always 0, read1 and read2 are always available
        value1 = datas[read1];
        value2 = datas[read2];
        rob_tag1 = rob_tags[read1];
        rob_tag2 = rob_tags[read2];
        busy1=busy[read1];
        busy2=busy[read2];
    end

endmodule : regFile
/*
module registerEntry(
    input clk, input rst,
    // set
    input set_value,  input set_rob_tag,
    input [`DATA_WIDTH ] newValue,  input [`ROB_WIDTH ] in_rob_tag,
    input reset_busy,
    // output
    output reg [`DATA_WIDTH ] value,  output reg rob_tag, output reg busy
);
    always @(posedge clk) begin
        if (set_value) begin
            value <= newValue;
        end
        if (set_rob_tag) begin
            rob_tag <= in_rob_tag;
            busy<=`TRUE ;
        end
        if (reset_busy)begin
            rob_tag<=`ZERO_ROB ;
            busy<=`FALSE ;
        end
    end
endmodule : registerEntry


module regFile(
    input clk, input rst,
    // decoder read value
    input [`REG_WIDTH  ] read1, input [`REG_WIDTH  ] read2,
    output [`DATA_WIDTH ] value1, output [`DATA_WIDTH ] value2,
    output [`ROB_WIDTH  ] rob_tag1, output [`ROB_WIDTH  ] rob_tag2,
    // set value by rob
    input [`REG_WIDTH  ] set_value, input [`DATA_WIDTH ] in_new_value,
);
    wire [`DATA_WIDTH ] datas [`REG_COUNT -1:0];
    wire [`ROB_WIDTH ] rob_tags [`REG_COUNT -1:0 ];
    wire set_flags[`REG_COUNT -1:0];
    generate
        genvar regi;
        for (regi = 0;regi < `REG_COUNT;regi++) begin : genreg
            register r(
                .clk(clk),
                .rst(rst),
                .set_value(set_flags[regi]),
                .set_rob_tag(),
                .newValue(in_new_value),
                .in_rob_tag(),
                .value(datas[regi]),
                .rob_tag(rob_tags[i])
            );
        end
    endgenerate
    always @(*) begin
        value1 = datas[read1];
        value2 = datas[read2];
        rob_tag1 = Qis[read1];
        rob_tag2 = Qis[read2];
    end

endmodule : regFile
*/