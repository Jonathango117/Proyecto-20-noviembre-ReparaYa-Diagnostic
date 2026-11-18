// reparaya_all.v - todos los modulos en un solo archivo (para EDA Playground: panel design.sv)

//==================== char_to_seg.v ====================
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

//==================== debounce.v ====================
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

//==================== seven_segment.v ====================
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

//==================== clock_divider.v ====================
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

//==================== input_controller.v ====================
`timescale 1ns / 1ps
// input_controller: sincroniza switches y filtra botones
module input_controller #(
    parameter integer DEBOUNCE_CYCLES = 1_000_000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] sw,
    input  wire        btnc,
    input  wire        btnu,
    input  wire        btnd,
    input  wire        btnr,
    output wire        start_pulse,     // BTNC
    output wire        select_pulse,    // BTNU
    output wire        restart_pulse,   // BTND
    output wire        resend_pulse,    // BTNR
    output wire        connected,       // SW0
    output wire [3:0]  v_code,          // SW[7:4]
    output wire [3:0]  i_code,          // SW[11:8]
    output wire        adc_sel          // SW15
);
    reg [15:0] s0, s1;
    always @(posedge clk) begin s0 <= sw; s1 <= s0; end

    assign connected = s1[0];
    assign v_code    = s1[7:4];
    assign i_code    = s1[11:8];
    assign adc_sel   = s1[15];

    debounce #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) d_c (.clk(clk), .rst(rst), .btn_in(btnc), .btn_clean(), .btn_pulse(start_pulse));
    debounce #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) d_u (.clk(clk), .rst(rst), .btn_in(btnu), .btn_clean(), .btn_pulse(select_pulse));
    debounce #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) d_d (.clk(clk), .rst(rst), .btn_in(btnd), .btn_clean(), .btn_pulse(restart_pulse));
    debounce #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) d_r (.clk(clk), .rst(rst), .btn_in(btnr), .btn_clean(), .btn_pulse(resend_pulse));
endmodule

//==================== voltage_monitor.v ====================
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

//==================== current_monitor.v ====================
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

//==================== diagnostic_fsm.v ====================
`timescale 1ns / 1ps
// diagnostic_fsm: maquina de estados del diagnostico
//   0 IDLE  1 CONNECTED  2 ANALYZING  3 VOLTAGE_CHECK  4 CURRENT_CHECK
//   5 RESULT_OK  6 RESULT_FAIL  7 FINISHED
// mode: 0 = completa (V+I), 1 = solo voltaje, 2 = solo corriente
// v_res / i_res: 0 = no ejecutada (NA), 1 = OK, 2 = FAIL
module diagnostic_fsm #(
    parameter integer STATE_MS  = 1000,   // permanencia en cada estado (ms)
    parameter integer NOCONN_MS = 2000    // duracion del aviso "no-C"
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_1ms,
    input  wire       connected,
    input  wire       start_pulse,
    input  wire       select_pulse,
    input  wire       restart_pulse,
    input  wire       resend_pulse,
    input  wire       v_ok,
    input  wire       i_ok,
    output reg  [2:0] state,
    output reg  [1:0] mode,
    output reg  [1:0] v_res,
    output reg  [1:0] i_res,
    output reg        fail,
    output reg        no_conn,
    output reg        report_pulse
);
    localparam [2:0] S_IDLE      = 3'd0,
                     S_CONNECTED = 3'd1,
                     S_ANALYZING = 3'd2,
                     S_VOLTAGE   = 3'd3,
                     S_CURRENT   = 3'd4,
                     S_OK        = 3'd5,
                     S_FAIL      = 3'd6,
                     S_FINISHED  = 3'd7;

    reg [15:0] t_ms;
    reg [15:0] nc_t;
    wire dwell_done = (t_ms >= STATE_MS);
    wire fail_i     = (v_res == 2'd2) || !i_ok;

    always @(posedge clk) begin
        report_pulse <= 1'b0;
        if (rst) begin
            state <= S_IDLE; mode <= 2'd0; v_res <= 2'd0; i_res <= 2'd0;
            fail <= 1'b0; no_conn <= 1'b0; t_ms <= 16'd0; nc_t <= 16'd0;
        end else begin
            if (tick_1ms && (t_ms != 16'hFFFF)) t_ms <= t_ms + 16'd1;

            // aviso "sin conexion"
            if (no_conn) begin
                if (connected) no_conn <= 1'b0;
                else if (tick_1ms) begin
                    if (nc_t >= NOCONN_MS) no_conn <= 1'b0;
                    else nc_t <= nc_t + 16'd1;
                end
            end

            if (restart_pulse) begin
                state <= S_IDLE; t_ms <= 16'd0;
                v_res <= 2'd0; i_res <= 2'd0; fail <= 1'b0;
            end else begin
                case (state)
                    S_IDLE: begin
                        if (select_pulse) mode <= (mode == 2'd2) ? 2'd0 : mode + 2'd1;
                        if (start_pulse) begin
                            if (connected) begin
                                state <= S_CONNECTED; t_ms <= 16'd0;
                                v_res <= 2'd0; i_res <= 2'd0; fail <= 1'b0; no_conn <= 1'b0;
                            end else begin
                                no_conn <= 1'b1; nc_t <= 16'd0;
                            end
                        end
                    end

                    S_CONNECTED: begin
                        if (!connected) begin
                            state <= S_IDLE; t_ms <= 16'd0; no_conn <= 1'b1; nc_t <= 16'd0;
                        end else if (dwell_done) begin
                            state <= S_ANALYZING; t_ms <= 16'd0;
                        end
                    end

                    S_ANALYZING: begin
                        if (!connected) begin
                            state <= S_IDLE; t_ms <= 16'd0; no_conn <= 1'b1; nc_t <= 16'd0;
                        end else if (dwell_done) begin
                            t_ms  <= 16'd0;
                            state <= (mode == 2'd2) ? S_CURRENT : S_VOLTAGE;
                        end
                    end

                    S_VOLTAGE: begin
                        if (!connected) begin
                            state <= S_IDLE; t_ms <= 16'd0; no_conn <= 1'b1; nc_t <= 16'd0;
                        end else if (dwell_done) begin
                            v_res <= v_ok ? 2'd1 : 2'd2;
                            t_ms  <= 16'd0;
                            if (mode == 2'd1) begin       // solo voltaje: termina aqui
                                fail  <= !v_ok;
                                state <= v_ok ? S_OK : S_FAIL;
                            end else begin
                                state <= S_CURRENT;
                            end
                        end
                    end

                    S_CURRENT: begin
                        if (!connected) begin
                            state <= S_IDLE; t_ms <= 16'd0; no_conn <= 1'b1; nc_t <= 16'd0;
                        end else if (dwell_done) begin
                            i_res <= i_ok ? 2'd1 : 2'd2;
                            fail  <= fail_i;
                            t_ms  <= 16'd0;
                            state <= fail_i ? S_FAIL : S_OK;
                        end
                    end

                    S_OK, S_FAIL: begin
                        if (dwell_done) begin
                            state <= S_FINISHED; t_ms <= 16'd0; report_pulse <= 1'b1;
                        end
                    end

                    S_FINISHED: begin
                        if (select_pulse) mode <= (mode == 2'd2) ? 2'd0 : mode + 2'd1;
                        if (resend_pulse) report_pulse <= 1'b1;
                        if (start_pulse) begin
                            v_res <= 2'd0; i_res <= 2'd0; fail <= 1'b0; t_ms <= 16'd0;
                            if (connected) state <= S_CONNECTED;
                            else begin state <= S_IDLE; no_conn <= 1'b1; nc_t <= 16'd0; end
                        end
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end
endmodule

//==================== display_formatter.v ====================
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

//==================== led_controller.v ====================
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

//==================== uart_tx.v ====================
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

//==================== uart_reporter.v ====================
`timescale 1ns / 1ps
// uart_reporter: envia
//  REPARAYA;EQUIPO=CELULAR;VOLTAJE=<OK|FAIL|NA>;CORRIENTE=<OK|FAIL|NA>;RESULTADO=<NORMAL|POSIBLE_FALLA>\r\n
module uart_reporter (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,        // pulso: enviar reporte
    input  wire [1:0] v_res,        // 0=NA 1=OK 2=FAIL
    input  wire [1:0] i_res,
    input  wire       fail,
    input  wire       tx_busy,
    output reg  [7:0] tx_data,
    output reg        tx_start,
    output reg        busy
);
    localparam [8*32-1:0] STR_A      = "REPARAYA;EQUIPO=CELULAR;VOLTAJE=";
    localparam [8*11-1:0] STR_B      = ";CORRIENTE=";
    localparam [8*11-1:0] STR_C      = ";RESULTADO=";
    localparam [8*13-1:0] STR_FALLA  = "POSIBLE_FALLA";
    localparam [8*6-1:0]  STR_NORMAL = "NORMAL";
    localparam [8*2-1:0]  STR_OK     = "OK";
    localparam [8*2-1:0]  STR_NA     = "NA";
    localparam [8*4-1:0]  STR_FAIL   = "FAIL";

    wire [8*32-1:0] wA  = STR_A;
    wire [8*11-1:0] wB  = STR_B;
    wire [8*11-1:0] wC  = STR_C;
    wire [8*13-1:0] wFA = STR_FALLA;
    wire [8*6-1:0]  wNO = STR_NORMAL;
    wire [8*2-1:0]  wOK = STR_OK;
    wire [8*2-1:0]  wNA = STR_NA;
    wire [8*4-1:0]  wFL = STR_FAIL;

    // byte i del texto de un resultado de prueba
    function [7:0] res_byte(input [1:0] r, input [6:0] i);
        begin
            case (r)
                2'd1:    res_byte = wOK[8*(1-i) +: 8];
                2'd2:    res_byte = wFL[8*(3-i) +: 8];
                default: res_byte = wNA[8*(1-i) +: 8];
            endcase
        end
    endfunction

    // byte i del segmento s del mensaje
    function [7:0] get_byte(input [2:0] s, input [6:0] i,
                            input [1:0] vr, input [1:0] ir, input f);
        begin
            case (s)
                3'd0:    get_byte = wA[8*(31-i) +: 8];
                3'd1:    get_byte = res_byte(vr, i);
                3'd2:    get_byte = wB[8*(10-i) +: 8];
                3'd3:    get_byte = res_byte(ir, i);
                3'd4:    get_byte = wC[8*(10-i) +: 8];
                3'd5:    get_byte = f ? wFA[8*(12-i) +: 8] : wNO[8*(5-i) +: 8];
                default: get_byte = (i == 7'd0) ? 8'h0D : 8'h0A;   // CR LF
            endcase
        end
    endfunction

    // longitud del segmento s
    function [6:0] seg_len(input [2:0] s, input [1:0] vr, input [1:0] ir, input f);
        begin
            case (s)
                3'd0:    seg_len = 7'd32;
                3'd1:    seg_len = (vr == 2'd2) ? 7'd4 : 7'd2;
                3'd2:    seg_len = 7'd11;
                3'd3:    seg_len = (ir == 2'd2) ? 7'd4 : 7'd2;
                3'd4:    seg_len = 7'd11;
                3'd5:    seg_len = f ? 7'd13 : 7'd6;
                default: seg_len = 7'd2;
            endcase
        end
    endfunction

    localparam [1:0] R_IDLE = 2'd0, R_SEND = 2'd1, R_WBUSY = 2'd2, R_WDONE = 2'd3;
    reg [1:0] st;
    reg [2:0] sg;
    reg [6:0] idx;
    reg [1:0] vr_l, ir_l;
    reg       f_l;

    always @(posedge clk) begin
        tx_start <= 1'b0;
        if (rst) begin
            st <= R_IDLE; sg <= 3'd0; idx <= 7'd0; busy <= 1'b0; tx_data <= 8'd0;
            vr_l <= 2'd0; ir_l <= 2'd0; f_l <= 1'b0;
        end else begin
            case (st)
                R_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        vr_l <= v_res; ir_l <= i_res; f_l <= fail;
                        sg <= 3'd0; idx <= 7'd0; busy <= 1'b1; st <= R_SEND;
                    end
                end
                R_SEND: begin
                    if (!tx_busy) begin
                        tx_data  <= get_byte(sg, idx, vr_l, ir_l, f_l);
                        tx_start <= 1'b1;
                        st <= R_WBUSY;
                    end
                end
                R_WBUSY: if (tx_busy) st <= R_WDONE;
                R_WDONE: begin
                    if (!tx_busy) begin
                        if (idx == seg_len(sg, vr_l, ir_l, f_l) - 1) begin
                            idx <= 7'd0;
                            if (sg == 3'd6) st <= R_IDLE;
                            else begin sg <= sg + 3'd1; st <= R_SEND; end
                        end else begin
                            idx <= idx + 7'd1; st <= R_SEND;
                        end
                    end
                end
            endcase
        end
    end
endmodule

//==================== adc_ad1.v ====================
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

//==================== top_reparaya.v ====================
`timescale 1ns / 1ps
// top_reparaya: modulo principal. Conecta todos los bloques.
// Las entradas de voltaje/corriente son SIMULADAS con switches (SW15=0) o vienen
// de un ADC externo (SW15=1). Limites configurables: V_MIN, V_MAX, I_MIN, I_MAX.
module top_reparaya #(
    parameter integer CLK_HZ          = 100_000_000,
    parameter integer DEBOUNCE_CYCLES = 1_000_000,
    parameter integer REFRESH_HZ      = 1000,
    parameter integer MS_CYCLES       = CLK_HZ / 1000,
    parameter integer STATE_MS        = 1000,
    parameter integer BAUD            = 9600,
    // ---- LIMITES CONFIGURABLES (cuentas de 12 bits; valores de EJEMPLO) ----
    parameter [11:0]  V_MIN = 12'h400,
    parameter [11:0]  V_MAX = 12'hBFF,
    parameter [11:0]  I_MIN = 12'h200,
    parameter [11:0]  I_MAX = 12'hAFF
)(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire [15:0] SW,
    input  wire        BTNC,
    input  wire        BTNU,
    input  wire        BTND,
    input  wire        BTNR,
    output wire [15:0] LED,
    output wire [6:0]  SEG,
    output wire        DP,
    output wire [7:0]  AN,
    output wire        UART_RXD_OUT,   // FPGA TX -> PC
    output wire        AD_CS_N,        // Pmod AD1 en JA
    output wire        AD_SCLK,
    input  wire        AD_D0,
    input  wire        AD_D1
);
    // ---- reset sincronizado ----
    reg [1:0] rst_sync = 2'b11;
    always @(posedge CLK100MHZ) rst_sync <= {rst_sync[0], ~CPU_RESETN};
    wire rst = rst_sync[1];

    // ---- tiempos ----
    wire tick_1ms, blink;
    clock_divider #(.MS_CYCLES(MS_CYCLES)) u_clk (
        .clk(CLK100MHZ), .rst(rst), .tick_1ms(tick_1ms), .blink(blink));

    // ---- entradas ----
    wire start_pulse, select_pulse, restart_pulse, resend_pulse, connected, adc_sel;
    wire [3:0] v_code, i_code;
    input_controller #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_in (
        .clk(CLK100MHZ), .rst(rst), .sw(SW),
        .btnc(BTNC), .btnu(BTNU), .btnd(BTND), .btnr(BTNR),
        .start_pulse(start_pulse), .select_pulse(select_pulse),
        .restart_pulse(restart_pulse), .resend_pulse(resend_pulse),
        .connected(connected), .v_code(v_code), .i_code(i_code), .adc_sel(adc_sel));

    // ---- fuente de medicion: simulada (switches) o ADC externo ----
    wire [11:0] adc_v, adc_i;
    wire        adc_valid;
    adc_ad1 u_adc (
        .clk(CLK100MHZ), .rst(rst), .cs_n(AD_CS_N), .sclk(AD_SCLK),
        .d0(AD_D0), .d1(AD_D1), .ch0(adc_v), .ch1(adc_i), .valid(adc_valid));

    wire [11:0] v_val = adc_sel ? adc_v : {v_code, 8'h00};
    wire [11:0] i_val = adc_sel ? adc_i : {i_code, 8'h00};

    // ---- monitores ----
    wire v_low, v_high, v_ok, i_low, i_high, i_ok;
    voltage_monitor #(.V_MIN(V_MIN), .V_MAX(V_MAX)) u_vmon (
        .clk(CLK100MHZ), .rst(rst), .value(v_val),
        .too_low(v_low), .too_high(v_high), .in_range(v_ok));
    current_monitor #(.I_MIN(I_MIN), .I_MAX(I_MAX)) u_imon (
        .clk(CLK100MHZ), .rst(rst), .value(i_val),
        .too_low(i_low), .too_high(i_high), .in_range(i_ok));

    // ---- FSM ----
    wire [2:0] state;
    wire [1:0] mode, v_res, i_res;
    wire       fail, no_conn, report_pulse;
    diagnostic_fsm #(.STATE_MS(STATE_MS)) u_fsm (
        .clk(CLK100MHZ), .rst(rst), .tick_1ms(tick_1ms),
        .connected(connected), .start_pulse(start_pulse), .select_pulse(select_pulse),
        .restart_pulse(restart_pulse), .resend_pulse(resend_pulse),
        .v_ok(v_ok), .i_ok(i_ok),
        .state(state), .mode(mode), .v_res(v_res), .i_res(i_res),
        .fail(fail), .no_conn(no_conn), .report_pulse(report_pulse));

    // ---- UART ----
    wire [7:0] tx_data;
    wire       tx_start, tx_busy, rep_busy;
    uart_reporter u_rep (
        .clk(CLK100MHZ), .rst(rst), .start(report_pulse),
        .v_res(v_res), .i_res(i_res), .fail(fail), .tx_busy(tx_busy),
        .tx_data(tx_data), .tx_start(tx_start), .busy(rep_busy));
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(CLK100MHZ), .rst(rst), .start(tx_start), .data(tx_data),
        .busy(tx_busy), .tx(UART_RXD_OUT));

    // ---- LEDs ----
    led_controller u_led (
        .state(state), .connected(connected), .v_in_range(v_ok), .i_in_range(i_ok),
        .fail(fail), .blink(blink), .tx_busy(tx_busy | rep_busy), .mode(mode), .led(LED));

    // ---- displays ----
    wire [55:0] seg_data;
    wire [7:0]  dp_data;
    display_formatter u_fmt (
        .state(state), .no_conn(no_conn), .fail(fail),
        .v_code(v_val[11:8]), .i_code(i_val[11:8]),
        .connected(connected), .adc_sel(adc_sel), .tx_busy(tx_busy | rep_busy),
        .seg_data(seg_data), .dp_data(dp_data));
    seven_segment #(.CLK_HZ(CLK_HZ), .REFRESH_HZ(REFRESH_HZ)) u_disp (
        .clk(CLK100MHZ), .rst(rst), .seg_data(seg_data), .dp_data(dp_data),
        .an(AN), .seg(SEG), .dp(DP));
endmodule
