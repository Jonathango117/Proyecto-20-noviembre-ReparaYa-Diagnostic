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
