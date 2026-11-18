`timescale 1ns / 1ps
// voltage_monitor: compara el voltaje (12 bits) contra el rango configurado.
// V_MIN / V_MAX son valores de EJEMPLO en cuentas de ADC, NO limites universales.
module voltage_monitor #(
    parameter [11:0] V_MIN = 12'h400,
    parameter [11:0] V_MAX = 12'hBFF
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
            too_low  <= (value < V_MIN);
            too_high <= (value > V_MAX);
            in_range <= (value >= V_MIN) && (value <= V_MAX);
        end
    end
endmodule
