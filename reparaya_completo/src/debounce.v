`timescale 1ns / 1ps
// debounce: sincronizador + antirrebote + pulso de un ciclo para UN boton
module debounce #(
    parameter integer DEBOUNCE_CYCLES = 1_000_000   // 10 ms a 100 MHz
)(
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output reg  btn_clean,
    output wire btn_pulse
);
    reg        s0, s1;
    reg [31:0] cnt;
    reg        prev;

    always @(posedge clk) begin
        s0 <= btn_in;
        s1 <= s0;
        if (rst) begin
            cnt <= 32'd0; btn_clean <= 1'b0; prev <= 1'b0;
        end else begin
            prev <= btn_clean;
            if (s1 == btn_clean)                  cnt <= 32'd0;
            else if (cnt == DEBOUNCE_CYCLES - 1) begin btn_clean <= s1; cnt <= 32'd0; end
            else                                  cnt <= cnt + 32'd1;
        end
    end
    assign btn_pulse = btn_clean & ~prev;
endmodule
