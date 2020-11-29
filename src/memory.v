`include "constant.v"
module memory(
    input clk, input rst, input ena, input uart_full,
    // misbranch
    input in_rollback,
    // ram
    output reg out_ram_rd_wt_flag,
    output reg [`DATA_WIDTH ] out_ram_addr,
    output reg [`RAM_WIDTH ] out_ram_data, input [`RAM_WIDTH ] in_ram_data,
    // fetcher
    input in_fetcher_ena, input [`DATA_WIDTH ] in_fetcher_addr,
    output reg out_fetcher_ok, output [`DATA_WIDTH ] out_fetcher_data,
    // LS
    input in_ls_ena, input in_ls_iswrite, input [`DATA_WIDTH ] in_ls_addr, input [2:0] in_ls_size,
    input [`DATA_WIDTH ] in_ls_data,
    output [`DATA_WIDTH ] out_ls_data, output reg out_ls_ok
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
    reg [2:0] stop_stage, cur_stage;
    reg uart_stall, is_to_uart, uart_flip;

    assign out_fetcher_data = buffered_data;
    assign out_ls_data = buffered_data;


    always @(posedge clk) begin
        out_ls_ok <= `FALSE;
        out_fetcher_ok <= `FALSE;
        out_ram_rd_wt_flag <= `RAM_RD;
        uart_stall <= `FALSE;
        if (rst) begin
            status <= IDLE;
            reg_fetch_ena <= `FALSE;
            reg_ls_ena <= `FALSE;
            out_ls_ok <= `FALSE;
            out_fetcher_ok <= `FALSE;
            uart_stall <= `FALSE;
            is_to_uart <= `FALSE;
        end else if (in_rollback) begin
            if (status != LS_WRITE)
                status <= IDLE;
            if (reg_ls_iswrite != `RAM_WT)
                reg_ls_ena <= `FALSE;
            if (in_ls_ena && in_ls_iswrite == `RAM_WT) begin
                reg_ls_ena <= `TRUE;
                reg_ls_iswrite <= in_ls_iswrite;
                reg_ls_addr <= in_ls_addr;
                reg_ls_data <= in_ls_data;
                reg_ls_size <= in_ls_size;
            end
            reg_fetch_ena <= `FALSE;
        end else if (ena) begin
            // buffer queries
            if (in_fetcher_ena) begin
                reg_fetch_ena <= `TRUE;
                reg_fetch_addr <= in_fetcher_addr;
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
                        if (!uart_full) begin
                            if (in_ls_ena) begin
                                stop_stage <= in_ls_size;
                                buffered_addr <= in_ls_addr+1;
                                buffered_data <= in_ls_data;
                                out_ram_data <= in_ls_data[7:0];
                                out_ram_addr <= (uart_stall && in_ls_addr == `PERI_ADDR) ?`ZERO_DATA :in_ls_addr;
                                is_to_uart <= in_ls_addr == `PERI_ADDR;
                                out_ram_rd_wt_flag <= (uart_stall && in_ls_addr == `PERI_ADDR) ?`RAM_RD :`RAM_WT;
                                cur_stage <= (uart_stall && in_ls_addr == `PERI_ADDR) ? 3'b000:3'b001;
                            end else begin
                                stop_stage <= reg_ls_size;
                                buffered_addr <= reg_ls_addr+1;
                                buffered_data <= reg_ls_data;
                                out_ram_data <= reg_ls_data[7:0];
                                out_ram_addr <= (uart_stall && reg_ls_addr == `PERI_ADDR) ?`ZERO_DATA :reg_ls_addr;
                                is_to_uart <= reg_ls_addr == `PERI_ADDR;
                                out_ram_rd_wt_flag <= (uart_stall && reg_ls_addr == `PERI_ADDR) ?`RAM_RD :`RAM_WT;
                                cur_stage <= (uart_stall && reg_ls_addr == `PERI_ADDR) ? 3'b000:3'b001;
                            end
                            uart_flip <= 1;
                            status <= LS_WRITE;
                        end
                    end else begin
                        // read
                        if (in_ls_ena) begin
                            stop_stage <= in_ls_size;
                            buffered_addr <= in_ls_addr+1;
                            out_ram_addr <= in_ls_addr;
                        end else begin
                            stop_stage <= reg_ls_size;
                            buffered_addr <= reg_ls_addr+1;
                            out_ram_addr <= reg_ls_addr;
                        end
                        cur_stage <= 3'b000;
                        status <= LS_READ;
                        buffered_data <= `ZERO_DATA;
                        out_ram_rd_wt_flag <= `RAM_RD;
                    end
                end else if (in_fetcher_ena || reg_fetch_ena) begin
                    // fetch instructions
                    buffered_addr <= in_fetcher_ena ? in_fetcher_addr+1:reg_fetch_addr+1;
                    out_ram_addr <= in_fetcher_ena ? in_fetcher_addr:reg_fetch_addr;
                    stop_stage <= 3'b100;
                    cur_stage <= 3'b000;
                    status <= ICACHE_READ;
                    buffered_data <= `ZERO_DATA;
                    out_ram_rd_wt_flag <= `RAM_RD;
                end else begin
                    // no income query
                    out_ram_rd_wt_flag <= `RAM_RD;
                    out_ram_addr <= `ZERO_DATA;
                end
            end else if (status != LS_WRITE || !uart_full) begin
                // running
                out_ram_addr <= buffered_addr;
                out_ram_rd_wt_flag <= status != LS_WRITE ?`RAM_RD :`RAM_WT;
                // may overflow
                buffered_addr <= buffered_addr+1;
                cur_stage <= cur_stage+1;
                case (status)
                    ICACHE_READ: begin
                        // read data
                        case (cur_stage)
                            // due to mysterious ram logic, read takes two cycles
                            3'b001: buffered_data[7:0] <= in_ram_data;
                            3'b010: buffered_data[15:8] <= in_ram_data;
                            3'b011: buffered_data[23:16] <= in_ram_data;
                            3'b100: buffered_data[31:24] <= in_ram_data;
                        endcase
                        if (cur_stage == 3'b011) begin
                            out_ram_addr <= `ZERO_DATA;
                        end
                        if (cur_stage == 3'b100) begin
                            // finish
                            out_fetcher_ok <= `TRUE;
                            status <= IDLE;
                            reg_fetch_ena <= `FALSE;
                            out_ram_addr <= `ZERO_DATA;
                            cur_stage <= 0;
                        end
                    end
                    LS_READ: begin
                        // read data
                        case (cur_stage)
                            3'b001: buffered_data[7:0] <= in_ram_data;
                            3'b010: buffered_data[15:8] <= in_ram_data;
                            3'b011: buffered_data[23:16] <= in_ram_data;
                            3'b100: buffered_data[31:24] <= in_ram_data;
                        endcase
                        if (cur_stage == stop_stage-1) begin
                            out_ram_addr <= `ZERO_DATA;
                        end
                        if (cur_stage == stop_stage) begin
                            // finish
                            out_ls_ok <= `TRUE;
                            status <= IDLE;
                            reg_ls_ena <= `FALSE;
                            out_ram_addr <= `ZERO_DATA;
                            cur_stage <= 0;
                        end
                    end
                    LS_WRITE: begin
                        // write data
                        if (!is_to_uart || uart_flip) begin
                            uart_flip <= 0;
                            case (cur_stage)
                                3'b000: begin
                                    // stall one cycle
                                    out_ram_data <= buffered_data[7:0];
                                    out_ram_addr <= buffered_addr-1;
                                    out_ram_rd_wt_flag <= `RAM_WT;
                                    buffered_addr <= buffered_addr;
                                end
                                // one clock ahead
                                3'b001: out_ram_data <= buffered_data[15:8];
                                3'b010: out_ram_data <= buffered_data[23:16];
                                3'b011: out_ram_data <= buffered_data[31:24];
                                default: out_ram_data <= `ZERO_DATA;
                            endcase
                            if (cur_stage == stop_stage) begin
                                // finish
                                out_ram_rd_wt_flag <= `RAM_RD;
                                out_ram_addr <= `ZERO_DATA;
                                out_ls_ok <= `TRUE;
                                status <= IDLE;
                                reg_ls_ena <= `FALSE;
                                uart_stall <= is_to_uart;
                            end
                        end else begin
                            uart_flip <= 1;
                            // restore
                            out_ram_addr <= `ZERO_DATA;
                            out_ram_rd_wt_flag <= `RAM_RD;
                            buffered_addr <= buffered_addr;
                            cur_stage <= cur_stage;
                        end
                    end
                endcase
            end
        end
    end


endmodule : memory