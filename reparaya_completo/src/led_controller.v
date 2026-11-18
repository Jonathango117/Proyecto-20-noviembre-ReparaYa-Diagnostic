`timescale 1ns / 1ps
// led_controller
//   LED[7:0]  estado (one-hot)   LED8 conectado   LED9 V en rango   LED10 I en rango
//   LED11 resultado OK   LED12 FALLA (parpadea)   LED13 UART   LED[15:14] modo
module led_controller (
    input  wire [2:0]  state,
    input  wire        connected,
    input  wire        v_in_range,
    input  wire        i_in_range,
    input  wire        fail,
    input  wire        blink,
    input  wire        tx_busy,
    input  wire [1:0]  mode,
    output reg  [15:0] led
);
    always @(*) begin
        led         = 16'b0;
        led[7:0]    = 8'b0000_0001 << state;
        led[8]      = connected;
        led[9]      = v_in_range;
        led[10]     = i_in_range;
        led[11]     = (state == 3'd5) || ((state == 3'd7) && !fail);
        led[12]     = ((state == 3'd6) || ((state == 3'd7) && fail)) && blink;
        led[13]     = tx_busy;
        led[15:14]  = mode;
    end
endmodule
