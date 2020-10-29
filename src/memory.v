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
    input in_ls_ena, input in_ls_is_write, input [`DATA_WIDTH ] in_ls_addr, input [2:0] in_ls_size,
    input [`DATA_WIDTH ] in_ls_data,
    output [`DATA_WIDTH ] out_ls_data, output out_ls_ok,
);
    reg [`DATA_WIDTH ] buffered_data;
    reg [`DATA_WIDTH ] buffered_addr;
    // status from IDLE to LS_WRITE (0 to 3)
    parameter IDLE=0, ICACHE_READ=1, LS_READ=2, LS_WRITE=3;
    reg [1:0] status;
    reg [1:0] cur_bytes;
    reg [2:0] where_to_stop; // cur_bytes==where_to_stop then break

    assign busy = status != IDLE;
    always @(posedge clk) begin
        out_ram_ena <= `FALSE;
        out_icache_ok <= `FALSE;
        out_ls_ok <= `FALSE;
        out_icache_data <= `ZERO_DATA;
        out_ls_data <= `ZERO_DATA;
        if (rst) begin
            status<=IDLE;
        end else begin
            if (status == IDLE) begin
                // check queries
                if(in_icache_ena)begin
                    where_to_stop<=2'b11;
                    cur_bytes<=2'b00;
                    status<=ICACHE_READ;
                    buffered_addr<=in_icache_addr+1;
                    buffered_data<=`ZERO_DATA ;
                    out_ram_ena=`TRUE ;
                    out_ram_addr<=in_icache_addr;
                    out_ram_rd_wt_flag<=`RAM_RD ;
                end else if (in_ls_ena)begin
                    if(in_ls_is_write)begin
                        // write
                        where_to_stop<=in_ls_size-1;
                        cur_bytes<=2'b01;
                        status<=LS_WRITE;
                        buffered_addr<=in_ls_addr+1;
                        buffered_data<=in_ls_data;
                        out_ram_ena=`TRUE ;
                        out_ram_addr<=in_ls_addr;
                        out_ram_rd_wt_flag<=`RAM_WT ;
                        out_ram_data<=in_ls_data[7:0];
                    end else begin
                        // read
                        where_to_stop<=in_ls_size-1;
                        cur_bytes<=2'b00;
                        status<=LS_READ;
                        buffered_addr<=in_ls_addr+1;
                        buffered_data<=`ZERO_DATA ;
                        out_ram_ena=`TRUE ;
                        out_ram_addr<=in_ls_addr;
                        out_ram_rd_wt_flag<=`RAM_RD ;
                    end
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
                        endcase
                        if (cur_bytes == 2'b11) begin
                            // finish
                            out_icache_data <= {in_ram_data, buffered_data[23:0]};
                            out_icache_ok <= `TRUE;
                            status <= IDLE;
                            out_ram_ena <= `FALSE ;
                        end
                    end
                    LS_READ: begin
                        // read data
                        case (cur_bytes)
                            2'b00: buffered_data[7:0] <= in_ram_data;
                            2'b01: buffered_data[15:8] <= in_ram_data;
                            2'b10: buffered_data[23:16] <= in_ram_data;
                        endcase
                        if (cur_bytes == where_to_stop) begin
                            // finish
                            case (where_to_stop)
                                2'b00:out_icache_data <= {24'b0,in_ram_data};
                                2'b01:out_icache_data <= {16'b0,in_ram_data,buffered_data[7:0]};
                                2'b11:out_icache_data <= {in_ram_data,buffered_data[23:0]};
                            endcase
                            out_ram_ena <= `FALSE ;
                            out_icache_ok <= `TRUE;
                            status <= IDLE;
                        end
                    end
                    LS_WRITE: begin
                        // write data
                        case (cur_bytes)
                            // one clock ahead
                            2'b01: out_ram_data<=buffered_data[15:8];
                            2'b10: out_ram_data<=buffered_data[23:15];
                            2'b11: out_ram_data<=buffered_data[31:24];
                        endcase
                        if (cur_bytes == where_to_stop) begin
                            // finish
                            // leave out_ram_ena true
                            status <= IDLE;
                        end
                    end
                endcase
            end
        end
    end
endmodule : memory