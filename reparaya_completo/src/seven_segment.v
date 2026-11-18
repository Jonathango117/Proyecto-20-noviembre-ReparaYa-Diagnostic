`timescale 1ns / 1ps
// seven_segment: multiplexado de 8 displays (salidas activas en BAJO en la Nexys A7)
// seg_data[7*i +: 7] = segmentos del display i (i=0 es el de la DERECHA)
module seven_segment #(
    parameter integer CLK_HZ     = 100_000_000,
    parameter integer REFRESH_HZ = 1000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [55:0] seg_data,
    input  wire [7:0]  dp_data,
    output reg  [7:0]  an,
    output reg  [6:0]  seg,
    output reg         dp
);
    localparam integer TICKS = CLK_HZ / (REFRESH_HZ * 8);
    reg [31:0] cnt;
    reg [2:0]  sel;

    always @(posedge clk) begin
        if (rst) begin cnt <= 32'd0; sel <= 3'd0; end
        else if (cnt >= TICKS - 1) begin cnt <= 32'd0; sel <= sel + 3'd1; end
        else cnt <= cnt + 32'd1;
    end

    always @(posedge clk) begin
        if (rst) begin an <= 8'hFF; seg <= 7'h7F; dp <= 1'b1; end
        else begin
            an  <= ~(8'b0000_0001 << sel);
            seg <= ~seg_data[sel*7 +: 7];
            dp  <= ~dp_data[sel];
        end
    end
endmodule
