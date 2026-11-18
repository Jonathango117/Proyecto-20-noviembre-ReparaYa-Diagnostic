# ReparaYa Diagnostic (FPGA + Verilog)

Proyecto académico de un sistema de diagnóstico electrónico descrito en Verilog, con la tarjeta **Digilent Nexys A7** como hardware objetivo. El sistema evalúa parámetros de voltaje y corriente de un dispositivo conectado, muestra el resultado en el display de siete segmentos y los LEDs, y envía un mensaje de diagnóstico por UART.

> **Estado actual:** simulación RTL funcional con Icarus Verilog (0 errores en las pruebas del testbench). **No** se ha sintetizado en Vivado ni validado en hardware físico.

---

## 1. Funcionalidades

- Verificar si existe conexión con el dispositivo.
- Evaluar voltaje y corriente (valor normal, bajo o alto).
- Diferenciar fallas por voltaje y por corriente.
- Tres modos de diagnóstico: completo, solo voltaje y solo corriente.
- Mostrar resultados en display de siete segmentos y LEDs.
- Enviar el reporte por UART.
- Control mediante switches y botones.

## 2. Hardware y herramientas

| Elemento | Detalle |
|---|---|
| Tarjeta | Digilent Nexys A7 |
| Reloj de la tarjeta | 100 MHz |
| Lenguaje | Verilog |
| Simulación | Icarus Verilog 12.0 (`iverilog`, `vvp`) en GitHub Codespaces (Ubuntu 24.04) |
| Visualización de ondas | Script Python con matplotlib (`sim/ver_ondas.py`) |
| Síntesis (prevista) | AMD Xilinx Vivado |

## 3. Estructura del repositorio

```text
reparaya_completo/
├── build/                  Archivos generados (ejecutable de simulación e imágenes de ondas)
├── constraints/
│   └── nexys_a7.xdc        Restricciones de pines (aún sin revisar)
├── sim/
│   ├── tb_reparaya.v       Testbench
│   └── ver_ondas.py        Genera imágenes PNG de las ondas desde dump.vcd
├── src/
├── reparaya_all.v          Todos los módulos del diseño en un solo archivo
├── dump.vcd                Ondas generadas por la simulación
└── README.md
```

## 4. Módulos del diseño (`reparaya_all.v`)

El módulo principal es **`top_reparaya`**, que en el testbench se instancia como `dut`.

| Módulo | Módulo | Módulo |
|---|---|---|
| `char_to_seg` | `led_controller` | `top_reparaya` (principal) |
| `debounce` | `uart_tx` | |
| `seven_segment` | `uart_reporter` | |
| `clock_divider` | `adc_ad1` | |
| `input_controller` | `voltage_monitor` | |
| `diagnostic_fsm` | `current_monitor` | |
| `display_formatter` | | |

Total: 14 módulos, 807 líneas.

`display_formatter` arma el texto de los 8 displays: los dígitos 7 a 4 muestran el mensaje de estado, el dígito 3 es `U`, el 2 es el código de voltaje, el 1 es `A` y el 0 es el código de corriente.

## 5. Máquina de estados (`diagnostic_fsm`)

Parámetros por defecto: `STATE_MS = 1000` (permanencia en cada estado, en ms) y `NOCONN_MS = 2000` (duración del aviso de "sin conexión").

| `state` | Nombre | Descripción |
|---|---|---|
| 0 | `S_IDLE` | Espera. Con `start_pulse` y conexión pasa a `S_CONNECTED`; sin conexión activa `no_conn`. |
| 1 | `S_CONNECTED` | Permanece `STATE_MS` y pasa a `S_ANALYZING`. |
| 2 | `S_ANALYZING` | Permanece `STATE_MS`. Va a `S_CURRENT` si `mode == 2`; en otro caso va a `S_VOLTAGE`. |
| 3 | `S_VOLTAGE` | Guarda `v_res` (1 = OK, 2 = falla). Con `mode == 1` termina en `S_OK` o `S_FAIL`; si no, va a `S_CURRENT`. |
| 4 | `S_CURRENT` | Guarda `i_res` y `fail`. Va a `S_FAIL` si hay falla y a `S_OK` si no. |
| 5 | `S_OK` | Permanece `STATE_MS`, pasa a `S_FINISHED` y genera `report_pulse`. |
| 6 | `S_FAIL` | Igual que `S_OK`. |
| 7 | `S_FINISHED` | Espera. `start_pulse` inicia otro diagnóstico y `resend_pulse` reenvía el reporte. |

Secuencias esperadas por modo:

- `mode 0` (completo): 0 → 1 → 2 → 3 → 4 → 5 o 6 → 7
- `mode 1` (solo voltaje): 0 → 1 → 2 → 3 → 5 o 6 → 7
- `mode 2` (solo corriente): 0 → 1 → 2 → 4 → 5 o 6 → 7

Otras reglas:

- `mode` cambia con `select_pulse`, solo en los estados 0 y 7, y recorre 0 → 1 → 2 → 0.
- Si `connected` baja durante los estados 1, 2, 3 o 4, la FSM vuelve a `S_IDLE` y activa `no_conn`.
- `fail` es 1 si el voltaje es defectuoso o la corriente no es OK.
- `restart_pulse` lleva a `S_IDLE` y limpia `v_res`, `i_res` y `fail`, pero no reinicia `mode`.

## 6. Cómo simular

Desde la carpeta `reparaya_completo`:

```bash
mkdir -p build
iverilog -g2012 -Wall -s tb_reparaya -o build/reparaya.vvp reparaya_all.v sim/tb_reparaya.v
vvp build/reparaya.vvp
```

Instalación de Icarus Verilog en Codespaces:

```bash
sudo apt-get update
sudo apt-get install -y iverilog
```

## 7. Resultados del testbench

Todas las comprobaciones actuales pasan:

```text
[OK] T1: estado inicial IDLE
[OK] T2: sin conexion -> sigue en IDLE
[OK] T2: sin conexion -> aviso no_conn
[OK] T3: FINISHED sin falla
[OK] T3: voltaje OK
[OK] T3: corriente OK
[OK] mensaje UART correcto
[OK] T4: falla por voltaje
[OK] mensaje UART correcto
[OK] T5: falla por corriente
[OK] mensaje UART correcto
[OK] T6: modo = 1 (solo voltaje)
[OK] mensaje UART correcto
[OK] T7: modo = 2 (solo corriente)
[OK] mensaje UART correcto
[OK] T8: desconexion -> aborta a IDLE
[OK] T9: BTND -> IDLE
---- Simulacion terminada: 0 errores ----
```

La simulación termina a los 3 572 655 000 ps (unos 3.57 ms).

> Esto confirma únicamente los escenarios que cubre el testbench actual. No equivale a validar el diseño en hardware.

## 8. Visualización de ondas

### Reducción del archivo VCD

El volcado original (`$dumpvars(0, tb_reparaya)`) guardaba todo el diseño: 359 señales y unos 25 MB. Se reemplazó por un volcado selectivo en `sim/tb_reparaya.v`, que excluye el reloj de 100 MHz, las líneas seriales del ADC (`AD_SCLK`, `AD_CS_N`, `AD_D0`, `AD_D1`) y los contadores internos. El archivo pasó a unos **195 KB**, sin cambiar los resultados del testbench.

Señales guardadas:

| Grupo | Señales |
|---|---|
| Entradas y salidas del testbench | `SW`, `btn`, `LED`, `UART_RXD_OUT`, `msg_ready`, `rx_byte`, `msg_line` |
| Control y FSM | `state`, `connected`, `no_conn`, `fail`, `mode`, `start_pulse`, `select_pulse`, `restart_pulse`, `resend_pulse`, `report_pulse`, `rep_busy` |
| ADC | `adc_valid`, `adc_sel`, `adc_v`, `adc_i` |
| Voltaje | `v_val`, `v_res`, `v_ok`, `v_low`, `v_high`, `v_code` |
| Corriente | `i_val`, `i_res`, `i_ok`, `i_low`, `i_high`, `i_code` |
| UART | `tx_start`, `tx_data`, `tx_busy` |
| Display | `seg_data`, `dp_data` |

### Imágenes con `sim/ver_ondas.py`

La extensión Waveform Viewer de VS Code no permitió agregar señales de forma práctica, así que se usa un script en Python que lee `dump.vcd` y guarda imágenes PNG agrupadas en `build/`.

```bash
pip install matplotlib        # solo la primera vez
python3 sim/ver_ondas.py
```

Genera cinco imágenes:

| Archivo | Contenido |
|---|---|
| `build/ondas_1_control.png` | FSM, conexión, falla, modo y pulsos |
| `build/ondas_2_voltaje.png` | Lectura ADC y evaluación de voltaje |
| `build/ondas_3_corriente.png` | Lectura ADC y evaluación de corriente |
| `build/ondas_4_uart.png` | Transmisión UART |
| `build/ondas_5_salidas.png` | Estado, LEDs y display |

Para acercar a una ventana de tiempo, pasar inicio y fin en milisegundos:

```bash
python3 sim/ver_ondas.py 0 0.02     # arranque del primer diagnóstico
python3 sim/ver_ondas.py 3.4 3.58   # final de la simulación
```

La imagen se guarda con el rango en el nombre, por ejemplo `ondas_1_control_0_0.02ms.png`.

### Qué se observa en `ondas_1_control.png`

- `state` queda en 7 (`S_FINISHED`) al terminar cada diagnóstico.
- `mode` vale 0 hasta unos 2.2 ms, pasa a 1 hasta unos 2.9 ms y luego a 2, en los mismos instantes en que aparece `select_pulse`.
- `fail` está en alto entre unos 0.7 y 2.2 ms, con una caída breve cerca de 1.45 ms, cuando comienza un nuevo diagnóstico.
- Hay cinco pulsos de `start_pulse` y cinco de `report_pulse`.

## 9. Pendiente

- [ ] Documentar cómo se acelera el tiempo en simulación (`STATE_MS` es 1000 ms por defecto, pero la simulación completa dura 3.57 ms).
- [ ] Revisar `voltage_monitor`, `current_monitor`, `adc_ad1`, `uart_reporter` y `uart_tx`.
- [ ] Añadir pruebas para `resend_pulse` y `restart_pulse`, que no se activan en las gráficas actuales.
- [ ] Probar la desconexión durante los estados 5 y 6, donde la FSM no vuelve a `S_IDLE`.
- [ ] Probar valores límite de voltaje y corriente.
- [ ] Revisar `constraints/nexys_a7.xdc` (pines, reloj, botones, switches, LEDs, display).
- [ ] Sintetizar en Vivado y revisar advertencias.
- [ ] Validar en la Nexys A7 física.

## 10. Alcance y limitaciones

- Todo lo validado hasta ahora es **simulación RTL** con las pruebas del testbench actual.
- No hay evidencia de síntesis, implementación ni funcionamiento en la tarjeta física.
- La sección 9 lista lo que aún no se ha revisado ni probado.
