#!/usr/bin/env python3
"""Generate note/soc_full.drawio: block diagram of the KLTN SoC in the style of
the QSOC reference diagram (black boxes, bold arrows, bus bars with port labels).

AXI4 system bus (CPU/DMA masters, memories) -> AXI2APB -> APB peripheral bus,
with the DMA controller (rtl_dma/avalon_simple_dma.sv) on both buses.
"""
import os
import xml.etree.ElementTree as ET

BOX = "rounded=0;whiteSpace=wrap;html=1;strokeWidth=2;fillColor=#FFFFFF;strokeColor=#000000;fontSize=16;"
NEW = "rounded=0;whiteSpace=wrap;html=1;strokeWidth=3;fillColor=#FFF2CC;strokeColor=#D6B656;fontSize=16;fontStyle=1;"
BUS = "rounded=0;whiteSpace=wrap;html=1;strokeWidth=3;fillColor=#FFFFFF;strokeColor=#000000;"
TXT = "text;html=1;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;whiteSpace=wrap;fontSize=15;"
TXTB = TXT + "fontStyle=1;"
ARROW = "edgeStyle=none;html=1;endArrow=block;endFill=1;strokeWidth=3;strokeColor=#000000;"
ARROW2 = ARROW + "startArrow=block;startFill=1;"
DASH = "edgeStyle=orthogonalEdgeStyle;html=1;endArrow=none;strokeWidth=2;dashed=1;strokeColor=#000000;rounded=0;"
DASH_NEW = DASH.replace("#000000", "#B85450")


def norm(style):
    """Drop repeated style keys (last value wins) so every renderer agrees."""
    kv = {}
    for part in style.split(";"):
        if not part:
            continue
        k, _, v = part.partition("=")
        kv.pop(k, None)
        kv[k] = v
    return ";".join(f"{k}={v}" if v != "" or k in ("html",) else k for k, v in kv.items()) + ";"


class Page:
    def __init__(self, name):
        self.name = name
        self.n = 1
        self.cells = []
        self.geo = {}

    def _id(self):
        self.n += 1
        return f"c{self.n}"

    def v(self, value, x, y, w, h, style=BOX):
        i = self._id()
        self.cells.append(("v", i, value, style, x, y, w, h, None, None))
        self.geo[i] = (x, y, w, h)
        return i

    def e(self, src, sx, sy, dst, tx, ty, style=ARROW, value=""):
        """Edge between two cells, anchored at fractional points (sx,sy) / (tx,ty)."""
        i = self._id()
        st = style + f"exitX={sx:.4f};exitY={sy:.4f};exitDx=0;exitDy=0;entryX={tx:.4f};entryY={ty:.4f};entryDx=0;entryDy=0;"
        self.cells.append(("e", i, value, st, 0, 0, 0, 0, src, dst))
        return i

    def at(self, cid, x, side):
        """Fractional anchor on top/bottom edge of cell `cid` at absolute x."""
        gx, gy, gw, gh = self.geo[cid]
        return ((x - gx) / gw, 0 if side == "top" else 1)

    def vlink(self, a, b, x, style=ARROW, value=""):
        """Vertical arrow at absolute x from a to b (a above b or below b)."""
        ay = self.geo[a][1]
        by = self.geo[b][1]
        a_side, b_side = ("bottom", "top") if ay < by else ("top", "bottom")
        sx, sy = self.at(a, x, a_side)
        tx, ty = self.at(b, x, b_side)
        return self.e(a, sx, sy, b, tx, ty, style, value)

    def xml(self):
        diagram = ET.Element("diagram", id=self.name.lower().replace(" ", "_"), name=self.name)
        m = ET.SubElement(diagram, "mxGraphModel", dx="1400", dy="1000", grid="1", gridSize="10",
                          guides="1", tooltips="1", connect="1", arrows="1", fold="1", page="0",
                          pageScale="1", pageWidth="1900", pageHeight="1400", math="0", shadow="0")
        root = ET.SubElement(m, "root")
        ET.SubElement(root, "mxCell", id="0")
        ET.SubElement(root, "mxCell", id="1", parent="0")
        for kind, i, value, style, x, y, w, h, src, dst in self.cells:
            if kind == "v":
                c = ET.SubElement(root, "mxCell", id=i, value=value, style=norm(style), vertex="1", parent="1")
                ET.SubElement(c, "mxGeometry", x=str(x), y=str(y), width=str(w), height=str(h),
                              **{"as": "geometry"})
            else:
                c = ET.SubElement(root, "mxCell", id=i, value=value, style=norm(style), edge="1",
                                  parent="1", source=src, target=dst)
                ET.SubElement(c, "mxGeometry", relative="1", **{"as": "geometry"})
        return diagram


def pin(p, x, y, label=None, label_dx=0):
    cid = p.v("&#10005;", x, y, 30, 30, BOX + "fontSize=14;")
    return cid


# ============================================================================
# Single page: AXI4 system bus (AXI_BUS) + AXI2APB + APB peripheral bus (APB_BUS)
# ============================================================================
ADAPT = BOX + "dashed=1;fillColor=#F5F5F5;"
RED = ARROW.replace("#000000", "#B85450")


def page_soc():
    p = Page("KLTN SoC")
    OX, OY, OW, OH = 110, 30, 1760, 1370
    p.v("", OX, OY, OW, OH, "rounded=0;whiteSpace=wrap;html=1;strokeWidth=3;fillColor=none;strokeColor=#000000;")
    p.v("KLTN_SOC", OX + 10, OY + OH - 40, 300, 30, TXTB + "align=left;fontSize=18;")

    p.v("<b>Address map</b><br>"
        "SDRAM &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;0x0000_0000 &nbsp;32 MB<br>"
        "ONCHIP &nbsp;&nbsp;&nbsp;0x0200_0000 &nbsp;~30 KB<br>"
        "APB window 0x0200_8000 &nbsp;4 KB:<br>"
        "&nbsp;SHA256 &nbsp;&nbsp;&nbsp;+0x00<br>"
        "&nbsp;TIMER0 &nbsp;&nbsp;&nbsp;+0x80<br>"
        "&nbsp;JTAG_UART +0xA0<br>"
        "<font color=\"#B85450\"><b>&nbsp;DMA CSR &nbsp;&nbsp;+0xC0 (proposed)</b></font>",
        OX + 20, OY + 20, 380, 220,
        "rounded=0;whiteSpace=wrap;html=1;strokeWidth=1;dashed=1;fillColor=none;align=left;"
        "verticalAlign=top;spacingLeft=10;fontSize=14;fontFamily=Courier New;")

    # ---- CPU (group) ----
    grp = p.v("axi_4_wrapper_riscv", 520, 55, 450, 200,
              "rounded=0;whiteSpace=wrap;html=1;strokeWidth=2;fillColor=none;verticalAlign=top;fontStyle=1;fontSize=15;dashed=1;")
    cpu = p.v("RISC-V CPU<br><font style=\"font-size:12px\">(riscv_top, RV32)</font>", 535, 105, 170, 100)
    imem = p.v("IMEM<br><font style=\"font-size:12px\">(firmware.hex)</font>", 795, 105, 170, 100)
    p.e(cpu, 1, 0.5, imem, 0, 0.5, ARROW2)
    dbg = p.v("DEBUG<br><font style=\"font-size:12px\">out_pc, out_alu_result</font>", 1030, 105, 200, 100)
    p.e(grp, 1.0, 0.5, dbg, 0, 0.5, ARROW)
    axm = p.v("AXI4 master<br><font style=\"font-size:12px\">(AW/W/B/AR/R)</font>", 630, 300, 230, 110)
    S1X = 745
    p.vlink(grp, axm, S1X)

    jm = p.v("JTAG-to-AXI<br>Master", 250, 300, 230, 110, ADAPT)
    pin_jtag = pin(p, OX - 15, 340)
    p.v("JTAG", 20, 340, 60, 30, TXT + "align=right;fontSize=16;")
    p.e(pin_jtag, 1, 0.5, jm, 0, 0.5, ARROW)
    S0X = 365

    # ---- AXI_BUS: AXI4 full crossbar ----
    BX, BY, BW, BH = 250, 470, 1350, 170
    sbus = p.v("", BX, BY, BW, BH, BUS)
    p.v("AXI_BUS<br><font style=\"font-size:12px\">AXI4 full crossbar (axi_4_full.sv), 3 masters x 3 slaves</font>",
        BX + 10, BY + 62, 640, 46, TXTB + "align=left;fontSize=17;")

    def lab(txt, x, y, color="#000000"):
        p.v(txt, x - 55, y, 110, 30, TXT + f"fontColor={color};")

    # masters (top)
    lab("AXI_S0", S0X, BY + 6)
    lab("AXI_S1", S1X, BY + 6)
    p.vlink(jm, sbus, S0X)
    p.vlink(axm, sbus, S1X)

    # slaves on top: ONCHIP, SDRAM
    M0X, M1X = 1130, 1410
    onchip = p.v("ONCHIP RAM<br><font style=\"font-size:12px\">(axi_ram)</font>", M0X - 100, 300, 200, 110)
    sdram = p.v("SDRAM<br>CTRL", M1X - 100, 300, 200, 110, ADAPT)
    chip = p.v("SDRAM chip<br><font style=\"font-size:12px\">MT48LC4M32B2, 16-bit</font>", M1X - 110, 105, 220, 100)
    p.e(sdram, 0.5, 0, chip, 0.5, 1, ARROW2)
    lab("AXI_M0", M0X, BY + 6)
    lab("AXI_M1", M1X, BY + 6)
    p.vlink(sbus, onchip, M0X)
    p.vlink(sbus, sdram, M1X)

    # ---- AXI2APB bridge + DMA (row 2) ----
    R2Y, R2H = 720, 110
    A2X = 400
    bridge = p.v("AXI2APB", A2X - 100, R2Y, 200, R2H, ADAPT)
    lab("AXI_M2", A2X, BY + BH - 36)
    p.vlink(sbus, bridge, A2X)

    DX = 1120
    dma = p.v("DMA<br><font style=\"font-size:12px\">(avalon_simple_dma core)</font>", DX - 120, R2Y, 240, R2H, NEW)
    lab("AXI_S2", DX, BY + BH - 36, "#B85450")
    p.vlink(dma, sbus, DX, RED)

    # ---- APB_BUS: APB ----
    PX, PY, PW, PH = 250, 900, 1350, 150
    pbus = p.v("", PX, PY, PW, PH, BUS)
    p.v("APB_BUS<br><font style=\"font-size:12px\">APB4 router, subtracts base address</font>",
        PX + 10, PY + 62, 540, 46, TXTB + "align=left;fontSize=17;")
    lab("APB_S0", A2X, PY + 6)
    p.vlink(bridge, pbus, A2X)
    lab("APB_M3", DX, PY + 6, "#B85450")
    p.vlink(pbus, dma, DX, RED)

    # ---- peripherals (row 3) ----
    R3Y, R3H = 1130, 100
    per = [("TIMER0", 425, "APB_M0"), ("JTAG<br>UART", 925, "APB_M1"), ("SHA256", 1425, "APB_M2")]
    blocks = {}
    for nm, cx, port in per:
        b = p.v(nm, cx - 100, R3Y, 200, R3H, ADAPT)
        blocks[nm] = b
        lab(port, cx, PY + PH - 36)
        p.vlink(pbus, b, cx)

    # ---- interrupts ----
    irq = p.v("IRQ EXPORT<br><font style=\"font-size:12px\">sha_irq, dma_irq</font>", 1650, 330, 190, 100, BOX)
    p.e(dma, 1, 0.5, irq, 0.3, 1, DASH_NEW)
    p.e(blocks["SHA256"], 1, 0.5, irq, 0.7, 1, DASH)
    p.v("TIMER0 / JTAG_UART irq: not wired", 1275, 1240, 300, 30, TXT + "fontSize=12;fontStyle=2;")

    # ---- clock/reset bar (replaces IO MUX) ----
    p.v("CLK_0 (50 MHz) &nbsp;|&nbsp; RESET_N &nbsp;&rarr;&nbsp; all blocks", 250, 1290, 1350, 60, BOX + "fontStyle=1;")

    # ---- legend ----
    lx, ly = 250, OY + OH + 30
    p.v("", lx, ly, 36, 24, BOX)
    p.v("RTL exists", lx + 46, ly - 4, 140, 32, TXT + "align=left;")
    p.v("", lx + 210, ly, 36, 24, ADAPT)
    p.v("to add / adapt to AXI4 or APB", lx + 256, ly - 4, 300, 32, TXT + "align=left;")
    p.v("", lx + 590, ly, 36, 24, NEW)
    p.v("NEW - DMA controller", lx + 636, ly - 4, 240, 32, TXT + "align=left;")
    p.v("", lx + 900, ly + 11, 50, 2, "line;strokeWidth=2;dashed=1;html=1;")
    p.v("interrupt", lx + 960, ly - 4, 140, 32, TXT + "align=left;")
    return p


def main():
    mx = ET.Element("mxfile", host="app.diagrams.net", agent="gen_soc_drawio.py", version="22.0.0")
    for pg in (page_soc(),):
        mx.append(pg.xml())
    tree = ET.ElementTree(mx)
    ET.indent(tree, space="  ")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "note", "soc_full.drawio")
    out = os.path.normpath(out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tree.write(out, encoding="utf-8", xml_declaration=False)
    print("wrote", out)


if __name__ == "__main__":
    main()
