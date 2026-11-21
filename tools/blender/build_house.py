"""Her house (candidate): a bright two-storey family home with a pitched
roof, a porch over the big front door, a chimney, window boxes and a picket
fence. Bevelled blocks (crisp but soft edges), coloured with vertex colours.
Units: game metres at scale 1 (her character is 5 m tall). Blender Z up,
the front faces -Y. Run:
  flatpak run org.blender.Blender -b --factory-startup -P build_house.py -- out.glb
"""
import bpy, bmesh, math, sys
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1]

W, D = 30.0, 20.0          # footprint (x, y)
FLOOR = 9.0                # storey height
WALLS = FLOOR * 2.0
ROOF_H = 11.0


def hexc(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [(v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c] + [1.0]


parts = []  # (bmesh, colour)


def box(c, size, colour, bevel=0.25):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(Vector(c)) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=min(bevel, min(size) * 0.3), segments=2, affect="EDGES")
    parts.append((bm, colour))


def prism_roof(c, w, d, h, overhang, colour):
    """A gable roof along X (ridge along X), as a closed prism."""
    bm = bmesh.new()
    x0, x1 = c[0] - w / 2 - overhang, c[0] + w / 2 + overhang
    y0, y1 = c[1] - d / 2 - overhang, c[1] + d / 2 + overhang
    z0, z1 = c[2], c[2] + h
    v = [bm.verts.new(p) for p in [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, c[1], z1), (x1, c[1], z1)]]
    for f in [(v[0], v[1], v[5], v[4]), (v[2], v[3], v[4], v[5]), (v[0], v[4], v[3]), (v[1], v[2], v[5]), (v[0], v[3], v[2], v[1])]:
        bm.faces.new(f)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    parts.append((bm, colour))


def gable(x, d, z, h, colour, t=0.6):
    """A triangle of wall filling the roof end at x."""
    bm = bmesh.new()
    a = [bm.verts.new((x - t / 2, -d / 2, z)), bm.verts.new((x - t / 2, d / 2, z)), bm.verts.new((x - t / 2, 0, z + h))]
    b = [bm.verts.new((x + t / 2, -d / 2, z)), bm.verts.new((x + t / 2, d / 2, z)), bm.verts.new((x + t / 2, 0, z + h))]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new((a[i], b[i], b[j], a[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    parts.append((bm, colour))


def window(x, z, w=4.2, h=4.6, front=True):
    y = -D / 2 - 0.15 if front else D / 2 + 0.15
    s = -1 if front else 1
    box((x, y, z), (w + 0.9, 0.5, h + 0.9), "ffffff", 0.15)              # frame
    box((x, y + s * 0.2, z), (w, 0.3, h), "8fd3ff", 0.05)                # glass
    box((x, y + s * 0.35, z), (0.35, 0.3, h), "ffffff", 0.05)            # cross bars
    box((x, y + s * 0.35, z), (w, 0.3, 0.35), "ffffff", 0.05)


# --- The house ------------------------------------------------------------------
box((0, 0, 0.6), (W + 2, D + 2, 1.2), "c9c3b6", 0.3)                       # plinth
box((0, 0, 1.2 + WALLS / 2), (W, D, WALLS), "fff1d6", 0.35)                 # walls (cream)
box((0, 0, 1.2 + FLOOR), (W + 0.6, D + 0.6, 0.7), "ffffff", 0.2)            # band between floors
prism_roof((0, 0, 1.2 + WALLS), W, D, ROOF_H, 1.6, "ff6b8b")               # roof (pink)
gable(-W / 2 + 0.3, D, 1.2 + WALLS, ROOF_H - 0.2, "fff1d6")
gable(W / 2 - 0.3, D, 1.2 + WALLS, ROOF_H - 0.2, "fff1d6")
box((W * 0.28, 3.0, 1.2 + WALLS + ROOF_H * 0.75), (3.2, 3.2, 9.0), "b5533c", 0.2)   # chimney
box((W * 0.28, 3.0, 1.2 + WALLS + ROOF_H * 0.75 + 4.7), (3.8, 3.8, 0.8), "8f3f2c", 0.15)
# Round attic window in the front of the roof.
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=2.0, radius2=2.0, depth=0.6,
                      matrix=Matrix.Translation(Vector((0, -D / 2 - 1.2, 1.2 + WALLS + 3.6))) @ Matrix.Rotation(math.radians(90), 4, "X"))
parts.append((bm, "ffd23f"))
# Front door (big: she's 5 m tall) with a frame, a porch roof on posts and steps.
box((0, -D / 2 - 0.2, 1.2 + 3.9), (5.6, 0.6, 7.8), "ffffff", 0.15)
box((0, -D / 2 - 0.45, 1.2 + 3.6), (4.4, 0.4, 7.2), "2f6fdb", 0.1)
box((1.4, -D / 2 - 0.75, 1.2 + 3.6), (0.5, 0.4, 0.5), "ffd23f", 0.1)       # knob
box((0, -D / 2 - 3.0, 1.2 + 8.6), (11.0, 6.0, 0.7), "ff6b8b", 0.2)         # porch roof
for sx in (-1, 1):
    box((sx * 4.8, -D / 2 - 5.4, 1.2 + 4.2), (0.8, 0.8, 8.4), "ffffff", 0.15)
box((0, -D / 2 - 3.0, 0.7), (11.0, 6.0, 1.4), "c9c3b6", 0.2)               # porch floor / steps
box((0, -D / 2 - 6.6, 0.35), (7.0, 1.6, 0.7), "c9c3b6", 0.15)
# Windows: ground floor either side of the door, four upstairs (the bedrooms).
for x in (-9.5, 9.5):
    window(x, 1.2 + FLOOR * 0.5)
    box((x, -D / 2 - 0.9, 1.2 + FLOOR * 0.5 - 3.0), (5.2, 1.2, 1.0), "8b5a2b", 0.15)   # window box
    for k in range(4):
        box((x - 1.8 + k * 1.2, -D / 2 - 1.0, 1.2 + FLOOR * 0.5 - 2.3), (0.8, 0.8, 0.8), ["ff5a5f", "ffd23f", "ff9fd2", "ffffff"][k], 0.3)
for x in (-11.0, -3.8, 3.8, 11.0):
    window(x, 1.2 + FLOOR * 1.5, 3.6, 4.2)
for x in (-9.0, 0.0, 9.0):
    window(x, 1.2 + FLOOR * 0.5, front=False)
    window(x, 1.2 + FLOOR * 1.5, 3.6, 4.2, front=False)
for side in (-1, 1):
    for y in (-4.0, 4.0):
        bm_x = side * (W / 2 + 0.15)
        box((bm_x, y, 1.2 + FLOOR * 0.5), (0.5, 4.9, 5.4), "ffffff", 0.15)
        box((bm_x + side * 0.2, y, 1.2 + FLOOR * 0.5), (0.3, 4.0, 4.6), "8fd3ff", 0.05)
        box((bm_x, y, 1.2 + FLOOR * 1.5), (0.5, 4.5, 5.0), "ffffff", 0.15)
        box((bm_x + side * 0.2, y, 1.2 + FLOOR * 1.5), (0.3, 3.6, 4.2), "8fd3ff", 0.05)
# A white picket fence round the front garden, with a gap for the path.
gx, gy = W / 2 + 6.0, D / 2 + 14.0
for x in [i * 2.5 - gx for i in range(int(gx * 2 / 2.5) + 1)]:
    if abs(x) > 3.5:
        box((x, -gy, 1.5), (0.5, 0.4, 3.0), "ffffff", 0.12)
for side in (-1, 1):
    for y in [-gy + i * 2.5 for i in range(int((gy - D / 2) / 2.5) + 1)]:
        box((side * gx, y, 1.5), (0.4, 0.5, 3.0), "ffffff", 0.12)
for side in (-1, 1):
    box((side * (gx + 3.5) / 2, -gy, 2.2), ((gx - 3.5), 0.3, 0.4), "ffffff", 0.1)
box((0, -D / 2 - 11.0, 0.08), (5.0, 14.0, 0.16), "e2d6b8", 0.05)          # garden path

# --- Build one mesh with vertex colours ---------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
mesh = bpy.data.meshes.new("Her_House")
all_bm = bmesh.new()
cols = []
for bm, colour in parts:
    tmp = bpy.data.meshes.new("tmp")
    bm.to_mesh(tmp)
    n = len(all_bm.faces)
    all_bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    cols += [hexc(colour)] * (len(all_bm.faces) - n)
    bm.free()
all_bm.to_mesh(mesh)
attr = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
for poly, c in zip(mesh.polygons, cols):
    for li in poly.loop_indices:
        attr.data[li].color = c
mesh.color_attributes.active_color = attr
obj = bpy.data.objects.new("Her_House", mesh)
bpy.context.collection.objects.link(obj)
m = bpy.data.materials.new("HouseColours")
m.use_nodes = True
vc = m.node_tree.nodes.new("ShaderNodeVertexColor")
vc.layer_name = "Col"
m.node_tree.links.new(vc.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
mesh.materials.append(m)
print("HOUSE tris", sum(len(p.vertices) - 2 for p in mesh.polygons))
kwargs = dict(filepath=OUT, export_format="GLB", export_yup=True)
try:
    bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kwargs)
except TypeError:
    bpy.ops.export_scene.gltf(export_colors=True, **kwargs)
print("BUILT", OUT)
