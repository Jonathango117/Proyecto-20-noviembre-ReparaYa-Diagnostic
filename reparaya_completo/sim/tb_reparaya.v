`timescale 1ns / 1ps
// Testbench del sistema completo (parametros reducidos para simular rapido)
module tb_reparaya;
    reg         CLK100MHZ  = 0;
    reg         CPU_RESETN = 0;
    reg  [15:0] SW = 16'h0000;
    reg  [3:0]  btn = 4'b0000;          // {BTNR,BTND,BTNU,BTNC}
    reg         AD_D0 = 0, AD_D1 = 0;
    wire [15:0] LED;
    wire [6:0]  SEG;
    wire        DP;
    wire [7:0]  AN;
    wire        UART_RXD_OUT, AD_CS_N, AD_SCLK;

    top_reparaya #(
        .CLK_HZ(100_000_000),
        .DEBOUNCE_CYCLES(20),
        .REFRESH_HZ(1_000_000),
        .MS_CYCLES(100),          // "1 ms" = 100 ciclos = 1 us
        .STATE_MS(3),             // 3 "ms" por estado
        .BAUD(1_000_000)          // 1 Mbaud -> 100 ciclos por bit
    ) dut (
        .CLK100MHZ(CLK100MHZ), .CPU_RESETN(CPU_RESETN), .SW(SW),
        .BTNC(btn[0]), .BTNU(btn[1]), .BTND(btn[2]), .BTNR(btn[3]),
        .LED(LED), .SEG(SEG), .DP(DP), .AN(AN),
        .UART_RXD_OUT(UART_RXD_OUT),
        .AD_CS_N(AD_CS_N), .AD_SCLK(AD_SCLK), .AD_D0(AD_D0), .AD_D1(AD_D1)
    );

    always #5 CLK100MHZ = ~CLK100MHZ;

    integer errors = 0;

    task check(input [511:0] name, input condition);
        begin
            if (condition) $display("[OK]    %0s", name);
            else begin $display("[ERROR] %0s", name); errors = errors + 1; end
        end
    endtask

    // Presion de boton con rebotes
    task press(input integer n);
        begin
            btn[n] = 1; #40; btn[n] = 0; #30; btn[n] = 1; #40; btn[n] = 0; #30;
            btn[n] = 1; #1000;
            btn[n] = 0; #40; btn[n] = 1; #30; btn[n] = 0; #1000;
        end
    endtask

    // ---------- Receptor UART de prueba (1 Mbaud, 8N1) ----------
    localparam integer BIT_NS = 1000;
    reg [7:0]      rx_byte;
    reg [8*96-1:0] msg_line  = 0;
    reg            msg_ready = 0;
    integer        k;

    always @(negedge UART_RXD_OUT) begin
        #(BIT_NS/2);
        if (UART_RXD_OUT == 1'b0) begin
            for (k = 0; k < 8; k = k + 1) begin
                #(BIT_NS);
                rx_byte[k] = UART_RXD_OUT;
            end
            #(BIT_NS);                                  // bit de parada
            if (rx_byte == 8'h0A)      msg_ready = 1'b1;
            else if (rx_byte != 8'h0D) msg_line  = {msg_line[8*95-1:0], rx_byte};
        end
    end

    task expect_msg(input [8*96-1:0] expected);
        begin
            wait (msg_ready == 1'b1);
            msg_ready = 1'b0;
            if (msg_line == expected) $display("[OK]    mensaje UART correcto");
            else begin
                $display("[ERROR] mensaje UART distinto: %0s", msg_line);
                errors = errors + 1;
            end
            msg_line = 0;
        end
    endtask

    // Perro guardian
    initial begin
        #40_000_000;
        $display("[ERROR] TIMEOUT");
        $finish;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_reparaya.SW, tb_reparaya.btn,
             tb_reparaya.LED, tb_reparaya.UART_RXD_OUT,
             tb_reparaya.msg_ready, tb_reparaya.rx_byte,
             tb_reparaya.msg_line);
$dumpvars(0, tb_reparaya.dut.state,
             tb_reparaya.dut.connected, tb_reparaya.dut.no_conn,
             tb_reparaya.dut.fail,      tb_reparaya.dut.mode,
             tb_reparaya.dut.start_pulse,   tb_reparaya.dut.select_pulse,
             tb_reparaya.dut.restart_pulse, tb_reparaya.dut.resend_pulse,
             tb_reparaya.dut.report_pulse,  tb_reparaya.dut.rep_busy);
$dumpvars(0, tb_reparaya.dut.adc_valid, tb_reparaya.dut.adc_sel,
             tb_reparaya.dut.adc_v,     tb_reparaya.dut.adc_i);
$dumpvars(0, tb_reparaya.dut.v_val, tb_reparaya.dut.v_res,
             tb_reparaya.dut.v_ok,  tb_reparaya.dut.v_low,
             tb_reparaya.dut.v_high, tb_reparaya.dut.v_code);
$dumpvars(0, tb_reparaya.dut.i_val, tb_reparaya.dut.i_res,
             tb_reparaya.dut.i_ok,  tb_reparaya.dut.i_low,
             tb_reparaya.dut.i_high, tb_reparaya.dut.i_code);
$dumpvars(0, tb_reparaya.dut.tx_start, tb_reparaya.dut.tx_data,
             tb_reparaya.dut.tx_busy);
$dumpvars(0, tb_reparaya.dut.seg_data, tb_reparaya.dut.dp_data);

        #100 CPU_RESETN = 1;
        #200;
        check("T1: estado inicial IDLE", dut.state === 3'd0);

        // T2: iniciar SIN conexion
        SW = 16'h0000;
        press(0);
        check("T2: sin conexion -> sigue en IDLE", dut.state === 3'd0);
        check("T2: sin conexion -> aviso no_conn", dut.no_conn === 1'b1);

        // T3: todo normal (V=7, I=5, conectado)
        SW = {4'b0, 4'd5, 4'd7, 3'b000, 1'b1};
        press(0);
        wait (dut.state === 3'd7);
        #100;
        check("T3: FINISHED sin falla", dut.fail === 1'b0);
        check("T3: voltaje OK",   dut.v_res === 2'd1);
        check("T3: corriente OK", dut.i_res === 2'd1);
        expect_msg("REPARAYA;EQUIPO=CELULAR;VOLTAJE=OK;CORRIENTE=OK;RESULTADO=NORMAL");

        // T4: voltaje anormal (V=2)
        SW = {4'b0, 4'd5, 4'd2, 3'b000, 1'b1};
        press(0);
        wait (dut.state === 3'd7);
        #100;
        check("T4: falla por voltaje", dut.fail === 1'b1 && dut.v_res === 2'd2);
        expect_msg("REPARAYA;EQUIPO=CELULAR;VOLTAJE=FAIL;CORRIENTE=OK;RESULTADO=POSIBLE_FALLA");

        // T5: corriente anormal (I=12)
        SW = {4'b0, 4'd12, 4'd7, 3'b000, 1'b1};
        press(0);
        wait (dut.state === 3'd7);
        #100;
        check("T5: falla por corriente", dut.fail === 1'b1 && dut.i_res === 2'd2);
        expect_msg("REPARAYA;EQUIPO=CELULAR;VOLTAJE=OK;CORRIENTE=FAIL;RESULTADO=POSIBLE_FALLA");

        // T6: prueba SOLO voltaje (BTNU -> modo 1)
        SW = {4'b0, 4'd5, 4'd7, 3'b000, 1'b1};
        press(1);
        check("T6: modo = 1 (solo voltaje)", dut.mode === 2'd1);
        press(0);
        wait (dut.state === 3'd7);
        #100;
        expect_msg("REPARAYA;EQUIPO=CELULAR;VOLTAJE=OK;CORRIENTE=NA;RESULTADO=NORMAL");

        // T7: prueba SOLO corriente (BTNU -> modo 2)
        press(1);
        check("T7: modo = 2 (solo corriente)", dut.mode === 2'd2);
        press(0);
        wait (dut.state === 3'd7);
        #100;
        expect_msg("REPARAYA;EQUIPO=CELULAR;VOLTAJE=NA;CORRIENTE=OK;RESULTADO=NORMAL");

        // T8: desconexion a mitad de prueba
        press(1);                        // modo vuelve a 0
        press(0);                        // inicia prueba
        SW[0] = 1'b0;                    // se "desconecta" el telefono
        #200;
        check("T8: desconexion -> aborta a IDLE", dut.state === 3'd0);

        // T9: reinicio con BTND
        SW[0] = 1'b1;
        press(0);
        press(2);                        // BTND
        check("T9: BTND -> IDLE", dut.state === 3'd0);

        $display("---- Simulacion terminada: %0d errores ----", errors);
        $finish;
    end
endmodule
