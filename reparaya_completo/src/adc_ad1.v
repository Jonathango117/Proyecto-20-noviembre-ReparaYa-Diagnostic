`timescale 1ns / 1ps
// adc_ad1: lector del Pmod AD1 (2 x AD7476A, 12 bits, SPI de solo lectura)
//   ch0 <- D0 (voltaje)    ch1 <- D1 (corriente)
//   SCLK = 100 MHz / (2*SCLK_DIV) = 2.5 MHz con SCLK_DIV=20
// SIN VERIFICAR EN HARDWARE: comprobar con 3.3 V -> ~FFF y con GND -> ~000.
module adc_ad1 #(
    parameter integer SCLK_DIV   = 20,
    parameter integer GAP_CYCLES = 100
)(
    input  wire        clk,
    input  wire        rst,
    output reg         cs_n,
    output reg         sclk,
    input  wire        d0,
    input  wire        d1,
    output reg  [11:0] ch0,
    output reg  [11:0] ch1,
    output reg         valid
);
    localparam [1:0] A_GAP = 2'd0, A_HI = 2'd1, A_LO = 2'd2, A_DONE = 2'd3;
    reg [1:0]  st;
    reg [31:0] c;
    reg [4:0]  n;
    reg [15:0] sh0, sh1;
    reg d0_a, d0_b, d1_a, d1_b;

    always @(posedge clk) begin
        d0_a <= d0; d0_b <= d0_a;
        d1_a <= d1; d1_b <= d1_a;
        valid <= 1'b0;
        if (rst) begin
            st <= A_GAP; cs_n <= 1'b1; sclk <= 1'b1; c <= 32'd0; n <= 5'd0;
            ch0 <= 12'd0; ch1 <= 12'd0; sh0 <= 16'd0; sh1 <= 16'd0;
        end else begin
            case (st)
                A_GAP: begin
                    cs_n <= 1'b1; sclk <= 1'b1;
                    if (c >= GAP_CYCLES - 1) begin c <= 32'd0; n <= 5'd0; cs_n <= 1'b0; st <= A_HI; end
                    else c <= c + 32'd1;
                end
                A_HI: begin
                    if (c >= SCLK_DIV - 1) begin c <= 32'd0; sclk <= 1'b0; st <= A_LO; end
                    else c <= c + 32'd1;
                end
                A_LO: begin
                    if (c >= SCLK_DIV - 1) begin
                        c <= 32'd0; sclk <= 1'b1;
                        sh0 <= {sh0[14:0], d0_b};
                        sh1 <= {sh1[14:0], d1_b};
                        n   <= n + 5'd1;
                        if (n == 5'd15) st <= A_DONE; else st <= A_HI;
                    end else c <= c + 32'd1;
                end
                A_DONE: begin
                    cs_n <= 1'b1;
                    ch0 <= sh0[12:1];
                    ch1 <= sh1[12:1];
                    valid <= 1'b1;
                    c <= 32'd0; st <= A_GAP;
                end
            endcase
        end
    end
endmodule
