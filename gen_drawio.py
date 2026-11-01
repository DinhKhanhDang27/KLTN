import xml.etree.ElementTree as ET

def create_vertex(root, id, value, x, y, width, height, style="rounded=0;whiteSpace=wrap;html=1;"):
    cell = ET.SubElement(root, "mxCell", id=id, value=value, style=style, vertex="1", parent="1")
    ET.SubElement(cell, "mxGeometry", x=str(x), y=str(y), width=str(width), height=str(height), **{"as": "geometry"})

def create_edge(root, id, source, target, style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;", value=""):
    cell = ET.SubElement(root, "mxCell", id=id, value=value, style=style, edge="1", parent="1", source=source, target=target)
    ET.SubElement(cell, "mxGeometry", relative="1", **{"as": "geometry"})

mxfile = ET.Element("mxfile")
diagram = ET.SubElement(mxfile, "diagram", id="riscv_datapath", name="Page-1")
mxGraphModel = ET.SubElement(diagram, "mxGraphModel", dx="1000", dy="1000", grid="1", gridSize="10", guides="1", tooltips="1", connect="1", arrows="1", fold="1", page="1", pageScale="1", pageWidth="1169", pageHeight="827", math="0", shadow="0")
root = ET.SubElement(mxGraphModel, "root")
ET.SubElement(root, "mxCell", id="0")
ET.SubElement(root, "mxCell", id="1", parent="0")

# Nodes
create_vertex(root, "PC", "PC Register", 100, 300, 80, 120, "rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;")
create_vertex(root, "PC_ADD4", "PC + 4\nAdder", 100, 100, 80, 60, "shape=trapezoid;perimeter=trapezoidPerimeter;whiteSpace=wrap;html=1;fixedSize=1;direction=south;")
create_vertex(root, "IMEM", "Instruction\nMemory", 250, 300, 100, 120, "shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#fff2cc;strokeColor=#d6b656;")
create_vertex(root, "CTRL", "Control\nUnit", 250, 100, 100, 120, "rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;")
create_vertex(root, "REGFILE", "Register\nFile", 450, 300, 100, 140, "rounded=0;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;")
create_vertex(root, "IMMGEN", "Imm\nGen", 450, 500, 100, 60, "ellipse;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;")
create_vertex(root, "ALU_MUX", "ALU MUX", 600, 420, 40, 80, "shape=trapezoid;perimeter=trapezoidPerimeter;whiteSpace=wrap;html=1;fixedSize=1;direction=south;")
create_vertex(root, "ALU", "ALU", 700, 300, 100, 140, "shape=trapezoid;perimeter=trapezoidPerimeter;whiteSpace=wrap;html=1;fixedSize=1;direction=south;fillColor=#f8cecc;strokeColor=#b85450;")
create_vertex(root, "BRANCH_CTRL", "Branch\nControl", 700, 100, 100, 80, "rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;")
create_vertex(root, "PC_ADD_IMM", "Branch/JAL\nAdder", 700, 500, 80, 60, "shape=trapezoid;perimeter=trapezoidPerimeter;whiteSpace=wrap;html=1;fixedSize=1;direction=south;")
create_vertex(root, "DMEM", "Data Memory\n(or Avalon I/O)", 850, 300, 100, 120, "shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#fff2cc;strokeColor=#d6b656;")
create_vertex(root, "WB_MUX", "WB MUX", 1000, 300, 40, 120, "shape=trapezoid;perimeter=trapezoidPerimeter;whiteSpace=wrap;html=1;fixedSize=1;direction=south;")

# Edges
create_edge(root, "E1", "PC", "IMEM", value="PC")
create_edge(root, "E2", "PC", "PC_ADD4")
create_edge(root, "E3", "IMEM", "CTRL", value="Opcode,\nFunct3, Funct7")
create_edge(root, "E4", "IMEM", "REGFILE", value="rs1, rs2, rd")
create_edge(root, "E5", "IMEM", "IMMGEN", value="Instruction")
create_edge(root, "E6", "REGFILE", "ALU", value="Read Data 1")
create_edge(root, "E7", "REGFILE", "ALU_MUX", value="Read Data 2")
create_edge(root, "E8", "IMMGEN", "ALU_MUX", value="Imm")
create_edge(root, "E9", "ALU_MUX", "ALU", value="B")
create_edge(root, "E10", "ALU", "DMEM", value="ALU Result\n(Addr)")
create_edge(root, "E11", "ALU", "BRANCH_CTRL", value="Zero")
create_edge(root, "E12", "REGFILE", "DMEM", value="Write Data")
create_edge(root, "E13", "DMEM", "WB_MUX", value="Mem Read Data")
create_edge(root, "E14", "ALU", "WB_MUX", value="ALU Result")
create_edge(root, "E15", "PC_ADD4", "WB_MUX", value="PC+4")
create_edge(root, "E16", "WB_MUX", "REGFILE", value="Write Back Data", style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;entryX=0.5;entryY=1;entryDx=0;entryDy=0;")
create_edge(root, "E17", "PC", "PC_ADD_IMM", value="PC")
create_edge(root, "E18", "IMMGEN", "PC_ADD_IMM", value="Imm")
create_edge(root, "E19", "PC_ADD_IMM", "PC", value="Branch Target", style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;entryX=0;entryY=0.75;entryDx=0;entryDy=0;")
create_edge(root, "E20", "PC_ADD4", "PC", value="Next PC", style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;entryX=0;entryY=0.25;entryDx=0;entryDy=0;")

tree = ET.ElementTree(mxfile)
ET.indent(tree, space="  ", level=0)
tree.write("note/riscv_datapath_drawio.xml", encoding="utf-8", xml_declaration=False)
