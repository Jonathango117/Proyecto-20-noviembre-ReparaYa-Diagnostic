`timescale 1ns / 1ps
// uart_tx: transmisor 8N1. BAUD configurable (9600 por defecto)
module uart_tx #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD   = 9600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       start,      // pulso de 1 ciclo
    input  wire [7:0] data,
    output reg        busy,
    output reg        tx
);
    localparam integer CLKS = CLK_HZ / BAUD;
    localparam [1:0] U_IDLE = 2'd0, U_START = 2'd1, U_DATA = 2'd2, U_STOP = 2'd3;

    reg [1:0]  st;
    reg [31:0] cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  sh;

    always @(posedge clk) begin
        if (rst) begin
            st <= U_IDLE; tx <= 1'b1; busy <= 1'b0; cnt <= 32'd0; bit_idx <= 3'd0; sh <= 8'd0;
        end else begin
            case (st)
                U_IDLE: begin
                    tx <= 1'b1; busy <= 1'b0;
                    if (start) begin
                        sh <= data; busy <= 1'b1; cnt <= 32'd0; tx <= 1'b0; st <= U_START;
                    end
                end
                U_START: begin
                    if (cnt == CLKS - 1) begin
                        cnt <= 32'd0; tx <= sh[0]; sh <= {1'b0, sh[7:1]}; bit_idx <= 3'd0; st <= U_DATA;
                    end else cnt <= cnt + 32'd1;
                end
                U_DATA: begin
                    if (cnt == CLKS - 1) begin
                        cnt <= 32'd0;
                        if (bit_idx == 3'd7) begin tx <= 1'b1; st <= U_STOP; end
                        else begin tx <= sh[0]; sh <= {1'b0, sh[7:1]}; bit_idx <= bit_idx + 3'd1; end
                    end else cnt <= cnt + 32'd1;
                end
                U_STOP: begin
                    if (cnt == CLKS - 1) begin cnt <= 32'd0; st <= U_IDLE; busy <= 1'b0; end
                    else cnt <= cnt + 32'd1;
                end
                default: st <= U_IDLE;
            endcase
        end
    end
endmodule
