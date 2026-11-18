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
