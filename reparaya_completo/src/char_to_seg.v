`timescale 1ns / 1ps
// char_to_seg: codigo de caracter (5 bits) -> 7 segmentos {g,f,e,d,c,b,a}, logica positiva
// 0-15 = hexadecimal, 16+ = letras especiales
module char_to_seg (
    input  wire [4:0] ch,
    output reg  [6:0] seg
);
    always @(*) begin
        case (ch)
            5'd0:  seg = 7'b0111111;
            5'd1:  seg = 7'b0000110;
            5'd2:  seg = 7'b1011011;
            5'd3:  seg = 7'b1001111;
            5'd4:  seg = 7'b1100110;
            5'd5:  seg = 7'b1101101;
            5'd6:  seg = 7'b1111101;
            5'd7:  seg = 7'b0000111;
            5'd8:  seg = 7'b1111111;
            5'd9:  seg = 7'b1101111;
            5'd10: seg = 7'b1110111;  // A
            5'd11: seg = 7'b1111100;  // b
            5'd12: seg = 7'b0111001;  // C
            5'd13: seg = 7'b1011110;  // d
            5'd14: seg = 7'b1111001;  // E
            5'd15: seg = 7'b1110001;  // F
            5'd16: seg = 7'b0000000;  // (blanco)
            5'd17: seg = 7'b0110000;  // I
            5'd18: seg = 7'b1011110;  // d
            5'd19: seg = 7'b0111000;  // L
            5'd20: seg = 7'b1011100;  // o
            5'd21: seg = 7'b1010100;  // n
            5'd22: seg = 7'b1111000;  // t
            5'd23: seg = 7'b1101101;  // S
            5'd24: seg = 7'b1110011;  // P
            5'd25: seg = 7'b0111110;  // U
            5'd26: seg = 7'b1010000;  // r
            5'd27: seg = 7'b1000000;  // -
            default: seg = 7'b0000000;
        endcase
    end
endmodule
