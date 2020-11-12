`include "constant.v"
module memory(
    input clk, input rst, output reg busy,
    // ram
    output out_ram_ena, output out_ram_rd_wt_flag, output [`DATA_WIDTH ] out_ram_addr,
    output [`RAM_WIDTH ] out_ram_data, input [`RAM_WIDTH ] in_ram_data,
    // icache
    input in_icache_ena, input [`DATA_WIDTH ] in_icache_addr,
    output out_icache_ok, output [`DATA_WIDTH ] out_icache_data,
    // LS
    input in_ls_ena, input in_ls_iswrite, input [`DATA_WIDTH ] in_ls_addr, input [2:0] in_ls_size,
    input [`DATA_WIDTH ] in_ls_data,
    output [`DATA_WIDTH ] out_ls_data, output out_ls_ok,
);
    // waiting buffer
    reg reg_fetch_ena;
    reg [`DATA_WIDTH ] reg_fetch_addr;
    reg reg_ls_ena;
    reg [`DATA_WIDTH ] reg_ls_addr;
    reg [`DATA_WIDTH ] reg_ls_data;
    reg [2:0] reg_ls_size;
    reg reg_ls_iswrite;
    // status
    parameter IDLE=0, ICACHE_READ=1, LS_READ=2, LS_WRITE=3;
    reg [1:0] status;
    reg [`DATA_WIDTH ] buffered_addr;
    reg [`DATA_WIDTH ] buffered_data;
    always @(posedge clk) begin
        if (rst) begin
            status <= IDLE;
            reg_fetch_ena <= `FALSE;
            reg_ls_iswrite <= `FALSE;
        end else begin
            // buffer queries
            if (in_icache_ena) begin
                reg_fetch_ena <= `TRUE;
                reg_fetch_addr = in_icache_addr;
            end
            if (in_ls_ena) begin
                reg_ls_ena <= `TRUE;
                reg_ls_iswrite <= in_ls_iswrite;
                reg_ls_addr <= in_ls_addr;
                reg_ls_data <= in_ls_data;
                reg_ls_size <= in_ls_size;
            end
            if (status == IDLE) begin
                // check queries and LS first
                if (in_ls_ena || reg_ls_ena) begin
                    if (in_ls_iswrite) begin
                        // write
                        if (in_ls_iswrite) begin
                            where_to_stop <= in_ls_size-1;
                            buffered_addr <= in_ls_addr+1;
                            buffered_data <= in_ls_data;
                            out_ram_data <= in_ls_data[7:0];
                            out_ram_addr <= in_ls_addr;
                        end else begin
                            where_to_stop <= reg_ls_size-1;
                            buffered_addr <= reg_ls_addr+1;
                            buffered_data <= reg_ls_data;
                            out_ram_data <= reg_ls_data[7:0];
                            out_ram_addr <= reg_ls_addr;

                        end
                        out_ram_rd_wt_flag <= `RAM_WT;
                        cur_bytes <= 2'b01;
                        status <= LS_WRITE;
                        out_ram_ena <= `TRUE;
                    end else begin
                        // read
                        if (in_ls_iswrite) begin
                            where_to_stop <= in_ls_size-1;
                            buffered_addr <= in_ls_addr+1;
                            out_ram_addr <= in_ls_addr;
                        end else begin
                            where_to_stop <= reg_ls_size-1;
                            buffered_addr <= reg_ls_addr+1;
                            out_ram_addr <= reg_ls_addr;
                        end
                        cur_bytes <= 2'b00;
                        status <= LS_READ;
                        buffered_data <= `ZERO_DATA;
                        out_ram_ena <= `TRUE;
                        out_ram_rd_wt_flag <= `RAM_RD;
                    end
                end else if (in_icache_ena || reg_ls_ena) begin
                    buffered_addr <= in_icache_ena ? in_icache_addr+1:reg_fetch_addr+1;
                    out_ram_addr <= in_icache_ena ? in_icache_addr:reg_fetch_addr;
                    where_to_stop <= 2'b11;
                    cur_bytes <= 2'b00;
                    status <= ICACHE_READ;
                    buffered_data <= `ZERO_DATA;
                    out_ram_ena <= `TRUE;
                    out_ram_rd_wt_flag <= `RAM_RD;
                end
            end else begin
                // running
                out_ram_ena <= `TRUE;
                out_ram_addr <= buffered_addr;
                out_ram_rd_wt_flag <= status != LS_WRITE;
                buffered_addr <= buffered_addr+1;
                cur_bytes <= cur_bytes+1;
                case (status)
                    ICACHE_READ: begin
                        // read data
                        case (cur_bytes)
                            2'b00: buffered_data[7:0] <= in_ram_data;
                            2'b01: buffered_data[15:8] <= in_ram_data;
                            2'b10: buffered_data[23:16] <= in_ram_data;
                            2'b11: buffered_data[31:24] <= in_ram_data;
                        endcase
                        if (cur_bytes == 2'b11) begin
                            // finish
                            out_icache_ok <= `TRUE;
                            status <= IDLE;
                            out_ram_ena <= `FALSE;
                            reg_fetch_ena <= `FALSE;
                        end
                    end
                    LS_READ: begin
                        // read data
                        case (cur_bytes)
                            2'b00: buffered_data[7:0] <= in_ram_data;
                            2'b01: buffered_data[15:8] <= in_ram_data;
                            2'b10: buffered_data[23:16] <= in_ram_data;
                            2'b11: buffered_data[31:24] <= in_ram_data;
                        endcase
                        if (cur_bytes == where_to_stop) begin
                            // finish
                            out_ram_ena <= `FALSE;
                            out_ls_ok <= `TRUE;
                            status <= IDLE;
                            reg_ls_ena <= `FALSE;
                        end
                    end
                    LS_WRITE: begin
                        // write data
                        case (cur_bytes)
                            // one clock ahead
                            2'b01: out_ram_data <= buffered_data[15:8];
                            2'b10: out_ram_data <= buffered_data[23:15];
                            2'b11: out_ram_data <= buffered_data[31:24];
                        endcase
                        if (cur_bytes == where_to_stop) begin
                            // finish
                            // leave out_ram_ena true
                            status <= IDLE;
                            reg_ls_ena <= `FALSE;
                        end
                    end
                endcase
            end
        end
    end


endmodule : memory