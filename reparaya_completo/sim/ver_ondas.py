#!/usr/bin/env python3
# Dibuja grupos de señales de dump.vcd y guarda PNG en build/
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

VCD = "dump.vcd"
SALIDA = "build"
TB = "tb_reparaya"
DUT = "tb_reparaya.dut"

GRUPOS = {
    "1_control": [
        (DUT + ".state", "dec"), (DUT + ".connected", "bin"),
        (DUT + ".no_conn", "bin"), (DUT + ".fail", "bin"),
        (DUT + ".mode", "dec"), (DUT + ".start_pulse", "bin"),
        (DUT + ".select_pulse", "bin"), (DUT + ".restart_pulse", "bin"),
        (DUT + ".resend_pulse", "bin"), (DUT + ".report_pulse", "bin"),
    ],
    "2_voltaje": [
        (DUT + ".adc_valid", "bin"), (DUT + ".adc_sel", "bin"),
        (DUT + ".adc_v", "dec"), (DUT + ".v_val", "dec"),
        (DUT + ".v_ok", "bin"), (DUT + ".v_low", "bin"),
        (DUT + ".v_high", "bin"), (DUT + ".v_code", "hex"),
    ],
    "3_corriente": [
        (DUT + ".adc_valid", "bin"), (DUT + ".adc_sel", "bin"),
        (DUT + ".adc_i", "dec"), (DUT + ".i_val", "dec"),
        (DUT + ".i_ok", "bin"), (DUT + ".i_low", "bin"),
        (DUT + ".i_high", "bin"), (DUT + ".i_code", "hex"),
    ],
    "4_uart": [
        (DUT + ".report_pulse", "bin"), (DUT + ".tx_start", "bin"),
        (DUT + ".tx_busy", "bin"), (DUT + ".tx_data", "hex"),
        (TB + ".rx_byte", "hex"), (TB + ".msg_ready", "bin"),
    ],
    "5_salidas": [
        (DUT + ".state", "dec"), (TB + ".LED", "hex"),
        (DUT + ".dp_data", "hex"),
    ],
}


def leer_vcd(ruta):
    scope, nombres, cambios, ancho = [], {}, {}, {}
    t, en_def = 0, True
    with open(ruta) as f:
        for linea in f:
            p = linea.split()
            if not p:
                continue
            if en_def:
                if p[0] == "$scope":
                    scope.append(p[2])
                elif p[0] == "$upscope":
                    scope.pop()
                elif p[0] == "$var":
                    ident = p[3]
                    nombres[".".join(scope + [p[4]])] = ident
                    ancho[ident] = int(p[2])
                    cambios.setdefault(ident, [])
                elif p[0] == "$enddefinitions":
                    en_def = False
                continue
            c = p[0]
            if c[0] == "#":
                t = int(c[1:])
            elif c[0] in "bB":
                cambios[p[1]].append((t, c[1:]))
            elif c[0] in "01xXzZ":
                cambios[c[1:]].append((t, c[0]))
    return nombres, cambios, ancho


def segmentos(lista, t0, t1):
    val = None
    for t, v in lista:
        if t <= t0:
            val = v
        else:
            break
    seg, ini = [], t0
    for t, v in lista:
        if t0 < t < t1:
            seg.append((ini, t, val))
            ini, val = t, v
    seg.append((ini, t1, val))
    return seg


def texto(v, fmt, n):
    if v is None or any(ch in v for ch in "xXzZ"):
        return "x"
    x = int(v, 2)
    if fmt == "dec":
        return str(x)
    if fmt == "hex":
        return "%0*X" % ((n + 3) // 4, x)
    return v


def dibujar(nombre, senales, nombres, cambios, ancho, t0, t1):
    filas = [(r, f) for r, f in senales if r in nombres]
    for r, f in senales:
        if r not in nombres:
            print("  aviso: no existe", r)
    fig, ax = plt.subplots(figsize=(14, 0.8 * len(filas) + 1.5))
    for i, (ruta, fmt) in enumerate(filas):
        ident = nombres[ruta]
        n = ancho[ident]
        y = -i * 1.5
        seg = segmentos(cambios[ident], t0, t1)
        for a, b, v in seg:
            a, b = a / 1e9, b / 1e9
            if n == 1:
                nivel = 1 if v == "1" else 0
                ax.plot([a, b], [y + nivel] * 2, color="tab:blue")
                ax.plot([a, a], [y, y + 1], color="tab:blue", lw=0.6)
            else:
                ax.add_patch(Rectangle((a, y), b - a, 1, fill=False,
                                       edgecolor="tab:green"))
                if (b - a) > 0.03 * (t1 - t0) / 1e9:
                    ax.text((a + b) / 2, y + 0.5, texto(v, fmt, n),
                            ha="center", va="center", fontsize=8)
    ax.set_yticks([-i * 1.5 + 0.5 for i in range(len(filas))])
    ax.set_yticklabels([r.split(".")[-1] for r, _ in filas])
    ax.set_xlim(t0 / 1e9, t1 / 1e9)
    ax.set_ylim(-len(filas) * 1.5 + 0.8, 1.5)
    ax.set_xlabel("tiempo (ms)")
    ax.set_title(nombre)
    ax.grid(axis="x", alpha=0.3)
    sufijo = "" if len(sys.argv) < 3 else "_%s_%sms" % (sys.argv[1], sys.argv[2])
    archivo = "%s/ondas_%s%s.png" % (SALIDA, nombre, sufijo)
    fig.tight_layout()
    fig.savefig(archivo, dpi=150)
    plt.close(fig)
    print("guardado", archivo)


nombres, cambios, ancho = leer_vcd(VCD)
tmax = max(c[-1][0] for c in cambios.values() if c)
if len(sys.argv) >= 3:
    t0, t1 = float(sys.argv[1]) * 1e9, float(sys.argv[2]) * 1e9
else:
    t0, t1 = 0, tmax
for nom, sen in GRUPOS.items():
    dibujar(nom, sen, nombres, cambios, ancho, t0, t1)
