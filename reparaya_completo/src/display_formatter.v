`timescale 1ns / 1ps
// display_formatter: arma el texto de los 8 displays
//   [7..4] mensaje de estado   [3]='U' [2]=codigo voltaje  [1]='A' [0]=codigo corriente
module display_formatter (
    input  wire [2:0]  state,
    input  wire        no_conn,
    input  wire        fail,
    input  wire [3:0]  v_code,
    input  wire [3:0]  i_code,
    input  wire        connected,
    input  wire        adc_sel,
    input  wire        tx_busy,
    output wire [55:0] seg_data,
    output wire [7:0]  dp_data
);
    localparam [4:0] K_BLANK = 5'd16, K_I = 5'd17, K_D = 5'd18, K_L = 5'd19,
                     K_O = 5'd20, K_N = 5'd21, K_T = 5'd22, K_S = 5'd23,
                     K_P = 5'd24, K_U = 5'd25, K_R = 5'd26, K_DASH = 5'd27,
                     K_C = 5'd12, K_E = 5'd14, K_A = 5'd10, K_F = 5'd15;

    reg [19:0] msg;   // {char7, char6, char5, char4}
    always @(*) begin
        if (no_conn && state == 3'd0) msg = {K_N, K_O, K_DASH, K_C};   // no-C
        else begin
            case (state)
                3'd0:    msg = {K_I, K_D, K_L, K_E};   // IdLE
                3'd1:    msg = {K_C, K_O, K_N, K_N};   // Conn
                3'd2:    msg = {K_T, K_E, K_S, K_T};   // tESt
                3'd3:    msg = {K_U, K_O, K_L, K_T};   // UoLt
                3'd4:    msg = {K_C, K_U, K_R, K_R};   // CUrr
                3'd5:    msg = {K_P, K_A, K_S, K_S};   // PASS
                3'd6:    msg = {K_F, K_A, K_I, K_L};   // FAIL
                3'd7:    msg = fail ? {K_F, K_A, K_I, K_L} : {K_P, K_A, K_S, K_S};
                default: msg = {K_BLANK, K_BLANK, K_BLANK, K_BLANK};
            endcase
        end
    end

    wire [39:0] chars = {msg, K_U, {1'b0, v_code}, K_A, {1'b0, i_code}};

    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : g_ch
            char_to_seg u_c (.ch(chars[5*g +: 5]), .seg(seg_data[7*g +: 7]));
        end
    endgenerate

    // puntos decimales: [7]=conectado  [6]=fuente ADC  [0]=UART transmitiendo
    assign dp_data = {connected, adc_sel, 5'b00000, tx_busy};
endmodule
