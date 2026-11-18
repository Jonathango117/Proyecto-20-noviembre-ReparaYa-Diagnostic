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
