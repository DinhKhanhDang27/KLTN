#!/usr/bin/env python3
"""Generate soc_full.drawio (KLTN SoC block diagram).

Layout rules
  * AXI_BUS and APB_BUS share the same x-extent, so both are symmetric
    around CX (the bus centre line).
  * Every block is a real vertex with a visible border; port labels are
    the only text-only cells.
  * Edges are anchored with fractions computed from absolute x, so moving
    a block only needs its centre x to be changed here.

Usage: python3 gen_soc_drawio.py [output.drawio]
"""
import sys
from xml.sax.saxutils import escape

# ---------------------------------------------------------------- geometry
BUS_X, BUS_W = 250, 1350
CX = BUS_X + BUS_W // 2            # 925, centre line of both buses

AXI_Y, AXI_H = 470, 170
APB_Y, APB_H = 900, 150
ROW_TOP_Y, ROW_TOP_H = 300, 110    # blocks above AXI_BUS
ROW_MID_Y, ROW_MID_H = 720, 110    # AXI2APB / DMA between the buses
ROW_BOT_Y, ROW_BOT_H = 1130, 100   # APB slaves

# centre x of every port, mirrored around CX
AXI_TOP = {"S0": CX - 525, "S1": CX - 225, "M0": CX + 225, "M1": CX + 525}
AXI_BOT = {"M2": CX - 300, "S2": CX + 300}
APB_TOP = {"S0": CX - 300, "M3": CX + 300}
APB_BOT = {"M0": CX - 500, "M1": CX, "M2": CX + 500}

# ------------------------------------------------------------------ styles
BLACK, RED, GREY, YELLOW, YELLOW_LN = "#000000", "#B85450", "#F5F5F5", "#FFF2CC", "#D6B656"

ST_BLOCK = f"rounded=0;whiteSpace=wrap;html=1;strokeWidth=2;fillColor=#FFFFFF;strokeColor={BLACK};fontSize=16;"
ST_TODO = f"rounded=0;whiteSpace=wrap;html=1;strokeWidth=2;fillColor={GREY};strokeColor={BLACK};fontSize=16;dashed=1;"
ST_NEW = f"rounded=0;whiteSpace=wrap;html=1;strokeWidth=3;fillColor={YELLOW};strokeColor={YELLOW_LN};fontSize=16;fontStyle=1;"
ST_BUS = f"rounded=0;whiteSpace=wrap;html=1;strokeWidth=3;fillColor=#FFFFFF;strokeColor={BLACK};"
ST_GROUP = f"rounded=0;whiteSpace=wrap;html=1;strokeWidth=2;fillColor=none;strokeColor={BLACK};verticalAlign=top;fontStyle=1;fontSize=15;dashed=1;"
ST_FRAME = f"rounded=0;whiteSpace=wrap;html=1;strokeWidth=3;fillColor=none;strokeColor={BLACK};"
ST_MAP = (f"rounded=0;whiteSpace=wrap;html=1;strokeWidth=1;dashed=1;fillColor=none;strokeColor={BLACK};"
          "align=left;verticalAlign=top;spacingLeft=10;fontSize=14;fontFamily=Courier New;")
ST_TEXT = "text;html=1;strokeColor=none;fillColor=none;verticalAlign=middle;whiteSpace=wrap;"


def edge_style(color=BLACK, both=False, dashed=False, ortho=False):
    s = "html=1;rounded=0;"
    s += "edgeStyle=orthogonalEdgeStyle;endArrow=none;strokeWidth=2;" if dashed else \
         "edgeStyle=none;endArrow=block;endFill=1;strokeWidth=3;"
    if both:
        s += "startArrow=block;startFill=1;"
    if dashed:
        s += "dashed=1;"
    return s + f"strokeColor={color};"


# --------------------------------------------------------------- emit cells
cells, ids, geom = [], {}, {}


def _id(name):
    ids.setdefault(name, f"c{len(ids) + 2}")
    return ids[name]


def vertex(name, value, style, x, y, w, h):
    geom[name] = (x, y, w, h)
    cells.append(
        f'        <mxCell id="{_id(name)}" value="{escape(value, {chr(34): "&quot;"})}" '
        f'style="{style}" vertex="1" parent="1">\n'
        f'          <mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry" />\n'
        f'        </mxCell>')


def block(name, title, sub, x_centre, y, w, h, style=ST_BLOCK):
    value = title + (f'<br><font style="font-size:12px">{sub}</font>' if sub else "")
    vertex(name, value, style, x_centre - w // 2, y, w, h)


def label(name, text, x_centre, y, w=110, h=30, color=BLACK, size=15, align="center", extra=""):
    vertex(name, text, f"{ST_TEXT}align={align};fontSize={size};fontColor={color};{extra}",
           x_centre - w // 2, y, w, h)


def frac(name, x):
    """fraction along a block's width for an absolute x."""
    gx, _, gw, _ = geom[name]
    return round((x - gx) / gw, 5)


def edge(name, src, tgt, style, exit_=(0.5, 1), entry=(0.5, 0)):
    cells.append(
        f'        <mxCell id="{_id(name)}" value="" style="{style}'
        f'exitX={exit_[0]};exitY={exit_[1]};exitDx=0;exitDy=0;'
        f'entryX={entry[0]};entryY={entry[1]};entryDx=0;entryDy=0;" '
        f'edge="1" parent="1" source="{_id(src)}" target="{_id(tgt)}">\n'
        f'          <mxGeometry relative="1" as="geometry" />\n'
        f'        </mxCell>')


# ------------------------------------------------------------------- frame
vertex("frame", "", ST_FRAME, 110, 30, 1760, 1370)
label("soc_name", "KLTN_SOC", 270, 1360, w=300, h=30, size=18, align="left", extra="fontStyle=1;")

# address map (top-left, kept clear of the CPU wrapper)
vertex("addrmap",
       "<b>Address map</b><br>"
       "SDRAM &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;0x0000_0000 &nbsp;32 MB<br>"
       "ONCHIP &nbsp;&nbsp;&nbsp;0x0200_0000 &nbsp;~30 KB<br>"
       "APB window 0x0200_8000 &nbsp;4 KB:<br>"
       "&nbsp;SHA256 &nbsp;&nbsp;&nbsp;+0x00<br>"
       "&nbsp;TIMER0 &nbsp;&nbsp;&nbsp;+0x80<br>"
       "&nbsp;JTAG_UART +0xA0<br>"
       f'<font color="{RED}"><b>&nbsp;DMA CSR &nbsp;&nbsp;+0xC0 (proposed)</b></font>',
       ST_MAP, 130, 50, 320, 220)

# ------------------------------------------------------- CPU wrapper (S1)
WRAP_W = 440
vertex("wrapper", "axi_4_wrapper_riscv", ST_GROUP, AXI_TOP["S1"] - WRAP_W // 2, 55, WRAP_W, 200)
block("cpu", "RISC-V CPU", "(riscv_top, RV32)", AXI_TOP["S1"] - 125, 105, 160, 100)
block("imem", "IMEM", "(firmware.hex)", AXI_TOP["S1"] + 125, 105, 160, 100)
block("debug", "DEBUG", "out_pc, out_alu_result", AXI_TOP["S1"] + WRAP_W // 2 + 180, 105, 200, 100)
edge("e_cpu_imem", "cpu", "imem", edge_style(both=True), exit_=(1, 0.5), entry=(0, 0.5))
edge("e_wrap_debug", "wrapper", "debug", edge_style(), exit_=(1, 0.5), entry=(0, 0.5))

# --------------------------------------------------- row above the AXI bus
block("jtag_axi", "JTAG-to-AXI<br>Master", None, AXI_TOP["S0"], ROW_TOP_Y, 230, ROW_TOP_H, ST_TODO)
block("axi_master", "AXI4 master", "(AW/W/B/AR/R)", AXI_TOP["S1"], ROW_TOP_Y, 230, ROW_TOP_H)
block("onchip", "ONCHIP RAM", "(axi_ram)", AXI_TOP["M0"], ROW_TOP_Y, 230, ROW_TOP_H)
block("sdram_ctrl", "SDRAM<br>CTRL", None, AXI_TOP["M1"], ROW_TOP_Y, 230, ROW_TOP_H, ST_TODO)
block("sdram_chip", "SDRAM chip", "MT48LC4M32B2, 16-bit", AXI_TOP["M1"], 105, 230, 100)
edge("e_wrap_master", "wrapper", "axi_master", edge_style())
edge("e_sdram", "sdram_ctrl", "sdram_chip", edge_style(both=True), exit_=(0.5, 0), entry=(0.5, 1))

# JTAG pin
vertex("jtag_pin", "&#10005;", f"rounded=0;whiteSpace=wrap;html=1;strokeWidth=2;fillColor=#FFFFFF;strokeColor={BLACK};fontSize=14;",
       95, ROW_TOP_Y + 40, 30, 30)
label("jtag_pin_lbl", "JTAG", 50, ROW_TOP_Y + 40, w=60, h=30, size=16, align="right")
edge("e_jtag_pin", "jtag_pin", "jtag_axi", edge_style(), exit_=(1, 0.5), entry=(0, 0.5))

# --------------------------------------------------------------- AXI_BUS
vertex("axi_bus", "", ST_BUS, BUS_X, AXI_Y, BUS_W, AXI_H)
label("axi_bus_title",
      'AXI_BUS<br><font style="font-size:12px">AXI4 full crossbar (axi_4_full.sv), 3 masters x 3 slaves</font>',
      CX, AXI_Y + 62, w=640, h=46, size=17, extra="fontStyle=1;")
for k, x in AXI_TOP.items():
    label(f"axi_lbl_{k}", f"AXI_{k}", x, AXI_Y + 6)
label("axi_lbl_M2", "AXI_M2", AXI_BOT["M2"], AXI_Y + AXI_H - 36)
label("axi_lbl_S2", "AXI_S2", AXI_BOT["S2"], AXI_Y + AXI_H - 36, color=RED)

for k, src in (("S0", "jtag_axi"), ("S1", "axi_master")):
    edge(f"e_axi_{k}", src, "axi_bus", edge_style(), entry=(frac("axi_bus", AXI_TOP[k]), 0))
for k, tgt in (("M0", "onchip"), ("M1", "sdram_ctrl")):
    edge(f"e_axi_{k}", "axi_bus", tgt, edge_style(), exit_=(frac("axi_bus", AXI_TOP[k]), 0), entry=(0.5, 1))

# ------------------------------------------------ AXI2APB and DMA (middle)
block("axi2apb", "AXI2APB", None, AXI_BOT["M2"], ROW_MID_Y, 200, ROW_MID_H, ST_TODO)
block("dma", "DMA", "(avalon_simple_dma core)", AXI_BOT["S2"], ROW_MID_Y, 240, ROW_MID_H, ST_NEW)
edge("e_axi_M2", "axi_bus", "axi2apb", edge_style(), exit_=(frac("axi_bus", AXI_BOT["M2"]), 1), entry=(0.5, 0))
edge("e_axi_S2", "dma", "axi_bus", edge_style(RED), exit_=(0.5, 0), entry=(frac("axi_bus", AXI_BOT["S2"]), 1))

# --------------------------------------------------------------- APB_BUS
vertex("apb_bus", "", ST_BUS, BUS_X, APB_Y, BUS_W, APB_H)
label("apb_bus_title",
      'APB_BUS<br><font style="font-size:12px">APB4 router, subtracts base address</font>',
      CX, APB_Y + 55, w=540, h=40, size=17, extra="fontStyle=1;")
label("apb_lbl_S0", "APB_S0", APB_TOP["S0"], APB_Y + 6)
label("apb_lbl_M3", "APB_M3", APB_TOP["M3"], APB_Y + 6, color=RED)
edge("e_apb_S0", "axi2apb", "apb_bus", edge_style(), entry=(frac("apb_bus", APB_TOP["S0"]), 0))
edge("e_apb_M3", "apb_bus", "dma", edge_style(RED), exit_=(frac("apb_bus", APB_TOP["M3"]), 0), entry=(0.5, 1))

slaves = (("M0", "timer0", "TIMER0"), ("M1", "jtag_uart", "JTAG<br>UART"), ("M2", "sha256", "SHA256"))
for k, name, title in slaves:
    block(name, title, None, APB_BOT[k], ROW_BOT_Y, 200, ROW_BOT_H, ST_TODO)
    label(f"apb_lbl_{k}", f"APB_{k}", APB_BOT[k], APB_Y + APB_H - 36)
    edge(f"e_apb_{k}", "apb_bus", name, edge_style(), exit_=(frac("apb_bus", APB_BOT[k]), 1), entry=(0.5, 0))

# ------------------------------------------------------------------- IRQ
IRQ_X = 1650
block("irq", "IRQ EXPORT", "sha_irq, dma_irq", IRQ_X + 95, 330, 190, 100)
edge("e_irq_dma", "dma", "irq", edge_style(RED, dashed=True), exit_=(1, 0.5), entry=(0.3, 1))
edge("e_irq_sha", "sha256", "irq", edge_style(BLACK, dashed=True), exit_=(1, 0.5), entry=(0.7, 1))
label("irq_note", "TIMER0 / JTAG_UART irq: not wired", APB_BOT["M2"], ROW_BOT_Y + ROW_BOT_H + 10,
      w=300, h=30, size=12, extra="fontStyle=2;")

# ------------------------------------------------------- clock / reset bar
vertex("clk", "CLK_0 (50 MHz) &nbsp;|&nbsp; RESET_N &nbsp;&rarr;&nbsp; all blocks",
       f"rounded=0;whiteSpace=wrap;html=1;strokeWidth=2;fillColor=#FFFFFF;strokeColor={BLACK};fontSize=16;fontStyle=1;",
       BUS_X, 1290, BUS_W, 60)

# ------------------------------------------------------------------ legend
LEG_Y, SW_W, SW_H, GAP = 1430, 36, 24, 40
items = (("RTL exists", 100, "swatch_rtl", ST_BLOCK),
         ("to add / adapt to AXI4 or APB", 260, "swatch_todo", ST_TODO),
         ("NEW - DMA controller", 200, "swatch_new", ST_NEW),
         ("interrupt", 90, "swatch_irq", None))
total = sum(SW_W + 10 + w for _, w, _, _ in items) + GAP * (len(items) - 1)
x = CX - total // 2
for text, w, name, style in items:
    if style:
        vertex(name, "", style, x, LEG_Y, SW_W, SW_H)
    else:
        vertex(name, "", "line;strokeWidth=2;dashed=1;html=1;", x, LEG_Y + SW_H // 2 - 1, SW_W, 2)
    label(f"{name}_txt", text, x + SW_W + 10 + w // 2, LEG_Y - 4, w=w, h=32, align="left")
    x += SW_W + 10 + w + GAP

# ------------------------------------------------------------------ output
HEADER = ('<mxfile host="app.diagrams.net" agent="gen_soc_drawio.py" version="22.0.0">\n'
          '  <diagram id="kltn_soc" name="KLTN SoC">\n'
          '    <mxGraphModel dx="1400" dy="1000" grid="1" gridSize="10" guides="1" tooltips="1" '
          'connect="1" arrows="1" fold="1" page="0" pageScale="1" pageWidth="1900" pageHeight="1400" '
          'math="0" shadow="0">\n'
          '      <root>\n'
          '        <mxCell id="0" />\n'
          '        <mxCell id="1" parent="0" />\n')
FOOTER = '      </root>\n    </mxGraphModel>\n  </diagram>\n</mxfile>\n'

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "soc_full.drawio"
    with open(out, "w", encoding="utf-8") as f:
        f.write(HEADER + "\n".join(cells) + "\n" + FOOTER)
    print(f"wrote {out}: {len(cells)} cells")
