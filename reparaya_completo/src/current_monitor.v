`timescale 1ns / 1ps
// current_monitor: compara la corriente (12 bits) contra el rango configurado.
// I_MIN / I_MAX son valores de EJEMPLO en cuentas de ADC, NO limites universales.
module current_monitor #(
    parameter [11:0] I_MIN = 12'h200,
    parameter [11:0] I_MAX = 12'hAFF
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] value,
    output reg         too_low,
    output reg         too_high,
    output reg         in_range
);
    always @(posedge clk) begin
        if (rst) begin too_low <= 1'b0; too_high <= 1'b0; in_range <= 1'b0; end
        else begin
            too_low  <= (value < I_MIN);
            too_high <= (value > I_MAX);
            in_range <= (value >= I_MIN) && (value <= I_MAX);
        end
    end
endmodule
