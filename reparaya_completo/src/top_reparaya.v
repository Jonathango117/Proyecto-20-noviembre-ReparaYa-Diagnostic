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
