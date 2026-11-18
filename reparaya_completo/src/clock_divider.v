`timescale 1ns / 1ps
// clock_divider: tick de 1 ms (para temporizar la FSM) y parpadeo de 2 Hz
// MS_CYCLES = ciclos de reloj por milisegundo (100_000 a 100 MHz)
module clock_divider #(
    parameter integer MS_CYCLES = 100_000,
    parameter integer BLINK_MS  = 250
)(
    input  wire clk,
    input  wire rst,
    output reg  tick_1ms,
    output reg  blink
);
    reg [31:0] c;
    reg [31:0] b;
    always @(posedge clk) begin
        if (rst) begin c <= 0; b <= 0; tick_1ms <= 1'b0; blink <= 1'b0; end
        else begin
            tick_1ms <= 1'b0;
            if (c >= MS_CYCLES - 1) begin
                c <= 0;
                tick_1ms <= 1'b1;
                if (b >= BLINK_MS - 1) begin b <= 0; blink <= ~blink; end
                else b <= b + 1;
            end else c <= c + 1;
        end
    end
endmodule
