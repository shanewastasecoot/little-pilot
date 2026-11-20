"""Build the player character's outfit props in Blender, from code.

Run (from the project root):  ./dev.sh props
which runs
    flatpak run org.blender.Blender -b --factory-startup \
        -P tools/blender/build_props.py -- assets/characters/props/props.glb

Each prop starts as a few rough primitives, then becomes ONE smooth merged
mesh: Voxel Remesh -> Subdivision Surface -> Decimate (to a triangle
budget). The primitives' colours are then copied onto the smooth mesh as
vertex colours (nearest face), so there are no stacked spheres or seams.

Props are modelled in the KayKit character's own space (metres, ~2.2 m
tall, feet at the origin; Blender Z up, character facing -Y), so the game
can hang them on a bone and they sit where they were made. Key places:
head bone 1.24 m, head mesh about 1.17-2.31 m tall and 0.54 m wide,
chest bone 0.97 m, hips bone 0.41 m, body about 0.39 m deep.
"""

import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "props.glb"
HEAD = Vector((0.0, 0.0, 1.72))  # middle of the head


def hexc(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return Vector([(v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c] + [1.0])


class Piece:
    """A rough shape and its colour (a closed bmesh)."""

    def __init__(self, bm, colour):
        self.bm = bm
        self.colour = hexc(colour)


def sphere(c, r, colour, segs=24, rings=16, rot=None):
    bm = bmesh.new()
    m = Matrix.Translation(c) @ (rot.to_4x4() if rot else Matrix.Identity(4)) @ Matrix.Diagonal((r[0], r[1], r[2], 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0, matrix=m)
    return Piece(bm, colour)


def cone(base, tip, r0, r1, colour, segs=16):
    bm = bmesh.new()
    d = tip - base
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    m = Matrix.Translation((base + tip) * 0.5) @ q.to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r0, radius2=r1, depth=d.length, matrix=m)
    return Piece(bm, colour)


def box(c, size, colour, rot=None):
    bm = bmesh.new()
    m = Matrix.Translation(c) @ (rot.to_4x4() if rot else Matrix.Identity(4)) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    return Piece(bm, colour)


def torus(c, major, minor, colour, axis=Vector((0, 0, 1)), arc=(0.0, 2 * math.pi), segs=32, tube=10, squash=1.0):
    """A torus (or an arc of one, capped) round `axis`."""
    bm = bmesh.new()
    q = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix()
    full = abs(arc[1] - arc[0] - 2 * math.pi) < 1e-6
    n = segs if full else segs + 1
    loops = []
    for i in range(n):
        a = arc[0] + (arc[1] - arc[0]) * i / (segs if not full else segs)
        ring_c = Vector((math.cos(a) * major, math.sin(a) * major, 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        loop = []
        for j in range(tube):
            b = 2 * math.pi * j / tube
            p = ring_c + out * math.cos(b) * minor + Vector((0, 0, 1)) * math.sin(b) * minor * squash
            loop.append(bm.verts.new(c + q @ p))
        loops.append(loop)
    for i in range(n if full else n - 1):
        a, b = loops[i], loops[(i + 1) % n]
        for j in range(tube):
            k = (j + 1) % tube
            bm.faces.new([a[j], a[k], b[k], b[j]])
    if not full:
        for loop in (loops[0], list(reversed(loops[-1]))):
            bm.faces.new(loop)
    return Piece(bm, colour)


def loft(rings, colour, segs=24, wobble=None):
    """Closed tube through rings of (centre, half width, half depth, z-up?)
    — each ring lies flat (horizontal) at its centre."""
    bm = bmesh.new()
    loops = []
    for ri, (c, rx, ry) in enumerate(rings):
        loop = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            k = wobble(ri, a) if wobble else 1.0
            loop.append(bm.verts.new(c + Vector((math.cos(a) * rx * k, math.sin(a) * ry * k, 0))))
        loops.append(loop)
    for r in range(len(loops) - 1):
        a, b = loops[r], loops[r + 1]
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new([a[i], a[j], b[j], b[i]])
    bm.faces.new(list(reversed(loops[0])))
    bm.faces.new(loops[-1])
    return Piece(bm, colour)


def shell(c, r, colour, keep, thickness=0.05, segs=40, rings=28):
    """A thick shell of an ellipsoid: only the faces where keep(local point)
    is true, thickened inwards (so it can be voxel-remeshed)."""
    bm = bmesh.new()
    m = Matrix.Translation(c) @ Matrix.Diagonal((r[0], r[1], r[2], 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0, matrix=m)
    gone = [f for f in bm.faces if not keep(f.calc_center_median() - c)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    # Thicken: duplicate inwards and bridge the rims.
    ret = bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thickness)
    return Piece(bm, colour)


def star(c, outer, inner, depth, colour, points=5, facing=Vector((0, -1, 0))):
    bm = bmesh.new()
    q = Vector((0, 0, 1)).rotation_difference(facing).to_matrix()
    front, back = [], []
    for i in range(points * 2):
        a = math.pi / 2 + math.pi * i / points
        r = outer if i % 2 == 0 else inner
        p = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        front.append(bm.verts.new(c + q @ (p + Vector((0, 0, depth * 0.5)))))
        back.append(bm.verts.new(c + q @ (p - Vector((0, 0, depth * 0.5)))))
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(front)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[j], front[i], back[i], back[j]])
    return Piece(bm, colour)


def finish(name, pieces, voxel=0.018, target_tris=1500):
    """Merge pieces into one smooth mesh: voxel remesh, subdivide, decimate,
    then paint each vertex with the colour of the nearest original piece."""
    # The colour source: all pieces in one bmesh, remembering each face's colour.
    src = bmesh.new()
    face_colours = []
    for p in pieces:
        before = len(src.faces)
        mesh = bpy.data.meshes.new("tmp")
        p.bm.to_mesh(mesh)
        src.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        face_colours += [p.colour] * (len(src.faces) - before)
        p.bm.free()
    src.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(src)
    # The smooth mesh.
    mesh = bpy.data.meshes.new(name)
    src.to_mesh(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    remesh = obj.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0.0
    remesh.use_smooth_shade = True
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
        bpy.ops.object.modifier_apply(modifier="Remesh")
        bpy.ops.object.modifier_apply(modifier="Subsurf")
    tris_now = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, target_tris / max(tris_now, 1))
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
        bpy.ops.object.modifier_apply(modifier="Decimate")
    # Colours from the nearest original face.
    attr = obj.data.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    for v in obj.data.vertices:
        hit = tree.find_nearest(v.co)
        col = face_colours[hit[2]] if hit[2] is not None else Vector((1, 1, 1, 1))
        attr.data[v.index].color = col
    obj.data.color_attributes.active_color = attr
    for poly in obj.data.polygons:
        poly.use_smooth = True
    m = bpy.data.materials.new("VertexColour_" + name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    vc = nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    m.node_tree.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    obj.data.materials.append(m)
    src.free()
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("  %-16s %5d tris" % (name, tris))
    return obj


# --- The props -----------------------------------------------------------------

def pilot_cap():
    leather, rim, lens, strap = "6b4226", "c9a14a", "9fd8ff", "4a2e18"
    # Front edge up on the forehead (eyes clear), lower at the sides and back.
    cap = shell(HEAD + Vector((0, 0.03, 0.06)), (0.65, 0.64, 0.64), leather,
                lambda p: (p.z > 0.08 if p.y < -0.25 else p.z > -0.14) or (abs(p.x) > 0.45 and p.z > -0.44 and abs(p.y) < 0.25),
                thickness=0.06)
    parts = [cap]
    for s in (1, -1):  # ear flaps
        parts.append(sphere(HEAD + Vector((0.65 * s, 0.0, -0.32)), (0.07, 0.17, 0.17), leather, segs=16, rings=10))
        # goggles up on the forehead: rim and lens
        g = HEAD + Vector((0.2 * s, -0.53, 0.38))
        parts.append(torus(g, 0.12, 0.045, rim, axis=Vector((0, -1, 0.35)), segs=24, tube=10))
        parts.append(sphere(g + Vector((0, 0.02, 0)), (0.11, 0.05, 0.11), lens, segs=16, rings=10,
                            rot=Vector((0, -1, 0)).rotation_difference(Vector((0, -1, 0.35))).to_matrix()))
    parts.append(box(HEAD + Vector((0, -0.58, 0.41)), (0.12, 0.08, 0.07), rim))  # bridge
    parts.append(torus(HEAD + Vector((0, 0.03, 0.32)), 0.64, 0.035, strap, segs=40, tube=8))  # strap round
    return finish("Pilot_Cap", parts, voxel=0.016, target_tris=1800)


def pilot_scarf():
    scarf = "f4ead5"
    parts = [torus(Vector((0, 0.0, 1.22)), 0.31, 0.085, scarf, segs=36, tube=12, squash=0.9)]
    # the tail, flying back over the shoulder
    parts.append(loft([(Vector((0.16, 0.3, 1.2)), 0.1, 0.05), (Vector((0.24, 0.42, 1.05)), 0.11, 0.045),
                       (Vector((0.3, 0.52, 0.9)), 0.12, 0.04)], scarf, segs=16))
    return finish("Pilot_Scarf", parts, voxel=0.016, target_tris=700)


def princess_tiara():
    gold, gem, pearl = "ffcf5a", "ff5fa2", "fff3f8"
    z0 = 2.03
    parts = [torus(Vector((0, 0.06, z0)), 0.46, 0.05, gold, axis=Vector((0, 0.35, 1)),
                   arc=(math.pi * 1.04, math.pi * 1.96), segs=30, tube=10)]
    for i, a in enumerate([-0.95, -0.48, 0.0, 0.48, 0.95]):
        x, y = math.sin(a) * 0.46, -math.cos(a) * 0.46 + 0.06
        tall = 0.26 if i == 2 else (0.18 if i in (1, 3) else 0.12)
        base = Vector((x, y, z0 + 0.02))
        parts.append(cone(base, base + Vector((0, -0.04, tall)), 0.075, 0.02, gold, segs=12))
        parts.append(sphere(base + Vector((0, -0.06, tall * 0.42)), (0.055, 0.04, 0.06),
                            gem if i % 2 == 0 else pearl, segs=14, rings=10))
        parts.append(sphere(base + Vector((0, -0.04, tall + 0.02)), (0.035, 0.035, 0.035), pearl, segs=10, rings=6))
    return finish("Princess_Tiara", parts, voxel=0.012, target_tris=1200)


def princess_gown():
    lilac, mint, deep = "c9a0f0", "6fd6c4", "a77ee0"
    rings = []
    for z, r in [(0.66, 0.46), (0.58, 0.5), (0.46, 0.58), (0.32, 0.67), (0.18, 0.74), (0.06, 0.79), (0.02, 0.79)]:
        rings.append((Vector((0, 0, z)), r, r * 0.92))
    parts = [loft(rings, lilac, segs=40, wobble=lambda ri, a: 1.0 + (0.035 * math.cos(a * 9) if ri >= 4 else 0.0))]
    parts.append(torus(Vector((0, 0, 0.07)), 0.79, 0.05, deep, segs=48, tube=10))   # hem ruffle
    parts.append(torus(Vector((0, 0, 0.62)), 0.47, 0.05, mint, segs=40, tube=10))   # sash
    for s in (1, -1):  # bow at the back
        parts.append(sphere(Vector((0.13 * s, 0.5, 0.62)), (0.13, 0.06, 0.08), mint, segs=16, rings=10,
                            rot=Matrix.Rotation(0.4 * s, 3, "Y")))
        parts.append(loft([(Vector((0.06 * s, 0.5, 0.58)), 0.04, 0.02), (Vector((0.11 * s, 0.58, 0.35)), 0.05, 0.02)], mint, segs=10))
    parts.append(sphere(Vector((0, 0.5, 0.62)), (0.06, 0.06, 0.06), mint, segs=12, rings=8))
    # A swag of little flowers round the skirt.
    for k in range(10):
        a = 2 * math.pi * k / 10
        parts.append(sphere(Vector((math.cos(a) * 0.62, math.sin(a) * 0.57, 0.36)), (0.05, 0.05, 0.05), mint, segs=10, rings=6))
    return finish("Princess_Gown", parts, voxel=0.02, target_tris=2200)


def astro_helmet():
    white, rim, orange = "dfe5ec", "8d99a8", "ff8c2a"
    window = lambda p: not (p.y < -0.2 and abs(p.x) < 0.44 and -0.42 < p.z < 0.3)
    parts = [shell(HEAD + Vector((0, 0.02, 0.0)), (0.7, 0.7, 0.68), white,
                   lambda p: window(p) and p.z > -0.55, thickness=0.06)]
    parts.append(torus(HEAD + Vector((0, -0.55, -0.06)), 0.4, 0.05, rim, axis=Vector((0, -1, 0.1)), segs=36, tube=10, squash=1.0))
    parts.append(torus(Vector((0, 0.02, 1.2)), 0.46, 0.07, rim, segs=36, tube=10))  # neck ring
    for s in (1, -1):  # side lights
        parts.append(sphere(HEAD + Vector((0.68 * s, 0.05, 0.05)), (0.06, 0.1, 0.1), orange, segs=12, rings=8))
    return finish("Astro_Helmet", parts, voxel=0.018, target_tris=2000)


def astro_pack():
    white, grey, orange = "e8ecf0", "9aa6b4", "ff8c2a"
    parts = [box(Vector((0, 0.5, 0.95)), (0.56, 0.22, 0.5), white)]
    for s in (1, -1):
        parts.append(cone(Vector((0.17 * s, 0.66, 0.72)), Vector((0.17 * s, 0.66, 1.18)), 0.09, 0.09, grey, segs=16))
        parts.append(sphere(Vector((0.17 * s, 0.66, 1.18)), (0.09, 0.09, 0.06), grey, segs=12, rings=8))
    parts.append(box(Vector((0, 0.62, 1.05)), (0.18, 0.06, 0.12), orange))
    return finish("Astro_Pack", parts, voxel=0.018, target_tris=900)


def hero_cape():
    red, collar = "e63946", "b8202d"
    rings = []
    # A curved slab: wide at the hem, gathered at the shoulders.
    for z, w, y in [(1.2, 0.4, 0.36), (0.95, 0.5, 0.44), (0.7, 0.6, 0.52), (0.45, 0.68, 0.6), (0.22, 0.74, 0.66)]:
        rings.append((Vector((0, y, z)), w, 0.04))
    parts = [loft(rings, red, segs=28, wobble=lambda ri, a: 1.0 + (0.05 * math.cos(a * 6) if ri == 4 else 0.0))]
    parts.append(torus(Vector((0, 0.06, 1.24)), 0.3, 0.06, collar, arc=(0.15 * math.pi, 0.85 * math.pi), segs=20, tube=10))
    return finish("Hero_Cape", parts, voxel=0.016, target_tris=900)


def hero_emblem():
    gold, red = "ffd23f", "e63946"
    parts = [sphere(Vector((0, -0.4, 0.95)), (0.17, 0.04, 0.17), red, segs=20, rings=10),
             star(Vector((0, -0.43, 0.95)), 0.14, 0.06, 0.05, gold)]
    return finish("Hero_Emblem", parts, voxel=0.01, target_tris=500)


def dino_hood():
    green, spike, white, black, belly = "5cbf45", "ff9f1c", "ffffff", "1c1a24", "f6e7a8"
    face = lambda p: not (p.y < -0.18 and abs(p.x) < 0.43 and -0.48 < p.z < 0.28)
    parts = [shell(HEAD + Vector((0, 0.03, 0.03)), (0.66, 0.68, 0.64), green, lambda p: face(p) and p.z > -0.5, thickness=0.07)]
    # Spikes down the middle, from the forehead over the top and down the back.
    for k in range(6):
        a = -0.2 + k * 0.42
        d = Vector((0, math.sin(a), math.cos(a)))
        base = HEAD + Vector((0, 0.03, 0.03)) + Vector((0, d.y * 0.66, d.z * 0.64))
        parts.append(cone(base - d * 0.04, base + d * (0.2 - k * 0.015), 0.1, 0.01, spike, segs=10))
    # Eyes on top of the snout rim, and a row of soft teeth.
    for s in (1, -1):
        e = HEAD + Vector((0.24 * s, -0.48, 0.42))
        parts.append(sphere(e, (0.1, 0.1, 0.1), white, segs=14, rings=10))
        parts.append(sphere(e + Vector((0, -0.07, 0.01)), (0.05, 0.04, 0.05), black, segs=10, rings=6))
    for k in range(7):
        x = (k - 3) * 0.12
        parts.append(cone(HEAD + Vector((x, -0.6, 0.27)), HEAD + Vector((x, -0.62, 0.17)), 0.04, 0.008, white, segs=8))
    return finish("Dino_Hood", parts, voxel=0.016, target_tris=2200)


def dino_tail():
    green, spike = "5cbf45", "ff9f1c"
    pts = [(Vector((0, 0.3, 0.48)), 0.2), (Vector((0, 0.55, 0.38)), 0.16), (Vector((0, 0.8, 0.3)), 0.12),
           (Vector((0, 1.02, 0.28)), 0.08), (Vector((0, 1.2, 0.33)), 0.035)]
    parts = []
    for i in range(len(pts) - 1):
        parts.append(cone(pts[i][0], pts[i + 1][0], pts[i][1], pts[i + 1][1], green, segs=16))
        parts.append(sphere(pts[i][0], (pts[i][1],) * 3, green, segs=16, rings=10))
    for i in range(4):
        c = pts[i][0].lerp(pts[i + 1][0], 0.5)
        r = (pts[i][1] + pts[i + 1][1]) * 0.5
        parts.append(cone(c + Vector((0, 0, r * 0.7)), c + Vector((0, 0.02, r + 0.11 - i * 0.015)), 0.06, 0.008, spike, segs=8))
    return finish("Dino_Tail", parts, voxel=0.016, target_tris=900)


def tube(points, r, colour, tube_segs=10):
    """A closed tube through `points` (Vector list), radius r."""
    bm = bmesh.new()
    loops = []
    for i, c in enumerate(points):
        d = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        x = d.cross(ref).normalized()
        y = d.cross(x).normalized()
        loops.append([bm.verts.new(c + (x * math.cos(t) + y * math.sin(t)) * r)
                      for t in [2 * math.pi * k / tube_segs for k in range(tube_segs)]])
    for i in range(len(loops) - 1):
        a, b = loops[i], loops[i + 1]
        for k in range(tube_segs):
            j = (k + 1) % tube_segs
            bm.faces.new([a[k], a[j], b[j], b[k]])
    bm.faces.new(list(reversed(loops[0])))
    bm.faces.new(loops[-1])
    return Piece(bm, colour)


def face_smile():
    """A small smile for every KayKit head: an arc that follows the face's
    curve just in front of the mouth line (face surface ~0.44 m forward at
    the middle, ~0.41 at the corners; Blender -Y is forward)."""
    pts = []
    for k in range(13):
        a = math.radians(205 + 130 * k / 12)
        x = math.cos(a) * 0.075
        z = 1.415 + math.sin(a) * 0.045
        forward = 0.452 - 5.0 * x * x
        pts.append(Vector((x, -forward, z)))
    return finish("Face_Smile", [tube(pts, 0.013, "8a3b3b")], voxel=0.004, target_tris=300)


# --- Delivery props (packages, and what the people you deliver to wear) ----------

def package():
    """A parcel with a red ribbon and bow, centred on the origin (the game
    places it in arms, on the plane and on the post office pad)."""
    kraft, ribbon = "d9a066", "e63946"
    w, d, h = 0.62, 0.52, 0.46
    parts = [box(Vector((0, 0, 0)), (w, d, h), kraft)]
    parts.append(box(Vector((0, 0, 0)), (w + 0.03, 0.1, h + 0.03), ribbon))
    parts.append(box(Vector((0, 0, 0)), (0.1, d + 0.03, h + 0.03), ribbon))
    top = Vector((0, 0, h * 0.5 + 0.02))
    for s in (1, -1):  # bow loops
        parts.append(torus(top + Vector((0.11 * s, 0, 0.06)), 0.09, 0.035, ribbon, axis=Vector((0, 1, 0)), segs=20, tube=8))
    parts.append(sphere(top + Vector((0, 0, 0.03)), (0.06, 0.06, 0.05), ribbon, segs=12, rings=8))
    return finish("Package", parts, voxel=0.012, target_tris=900)


def _brim_hat(name, crown, band, brim_major, brim_minor, flower=None):
    parts = [shell(HEAD + Vector((0, 0.02, 0.26)), (0.6, 0.6, 0.48), crown, lambda p: p.z > -0.02, thickness=0.06)]
    parts.append(torus(HEAD + Vector((0, 0.02, 0.27)), brim_major, brim_minor, crown, segs=40, tube=10, squash=0.14))
    parts.append(torus(HEAD + Vector((0, 0.02, 0.31)), 0.6, 0.05, band, segs=40, tube=8))
    if flower:
        c = HEAD + Vector((0.5, -0.32, 0.36))
        for k in range(5):
            a = 2 * math.pi * k / 5
            parts.append(sphere(c + Vector((math.cos(a) * 0.08, -0.02, math.sin(a) * 0.08)), (0.07, 0.04, 0.07), flower[0], segs=12, rings=8))
        parts.append(sphere(c + Vector((0, -0.05, 0)), (0.05, 0.04, 0.05), flower[1], segs=10, rings=6))
    return finish(name, parts, voxel=0.016, target_tris=1300)


def straw_hat():
    return _brim_hat("Straw_Hat", "e9c46a", "d64545", 0.78, 0.3)


def sun_hat():
    return _brim_hat("Sun_Hat", "f7a8c4", "ffffff", 0.74, 0.32, flower=("ffffff", "ffd23f"))


def flat_cap():
    """A mechanic's peaked cap."""
    red, peak = "e63946", "b8232f"
    parts = [shell(HEAD + Vector((0, 0.03, 0.08)), (0.64, 0.64, 0.62), red, lambda p: p.z > 0.14, thickness=0.06)]
    parts.append(sphere(HEAD + Vector((0, -0.55, 0.3)), (0.36, 0.26, 0.045), peak, segs=20, rings=10))
    parts.append(sphere(HEAD + Vector((0, 0.03, 0.7)), (0.06, 0.06, 0.04), peak, segs=10, rings=6))
    return finish("Flat_Cap", parts, voxel=0.016, target_tris=1000)


def beanie():
    """A lighthouse keeper's woolly hat with a bobble."""
    navy, cuff, bobble = "1d4e89", "2a63a8", "ffffff"
    parts = [shell(HEAD + Vector((0, 0.02, 0.06)), (0.65, 0.64, 0.66), navy, lambda p: p.z > 0.12, thickness=0.07)]
    parts.append(torus(HEAD + Vector((0, 0.02, 0.2)), 0.62, 0.075, cuff, segs=40, tube=10))
    parts.append(sphere(HEAD + Vector((0, 0.02, 0.76)), (0.16, 0.16, 0.15), bobble, segs=16, rings=10))
    return finish("Beanie", parts, voxel=0.016, target_tris=1100)


def postie_cap():
    """The post office's peaked cap with a gold badge."""
    blue, peak, gold = "2f6fdb", "1b2440", "ffd23f"
    parts = [shell(HEAD + Vector((0, 0.03, 0.08)), (0.64, 0.64, 0.62), blue, lambda p: p.z > 0.14, thickness=0.06)]
    parts.append(loft([(HEAD + Vector((0, 0.03, 0.42)), 0.6, 0.6), (HEAD + Vector((0, 0.03, 0.62)), 0.7, 0.7),
                       (HEAD + Vector((0, 0.03, 0.66)), 0.68, 0.68)], blue, segs=32))
    parts.append(sphere(HEAD + Vector((0, -0.55, 0.3)), (0.36, 0.26, 0.045), peak, segs=20, rings=10))
    parts.append(star(HEAD + Vector((0, -0.66, 0.5)), 0.1, 0.045, 0.04, gold))
    return finish("Postie_Cap", parts, voxel=0.016, target_tris=1300)


def mail_bag():
    """A satchel on the right hip, its strap over the left shoulder."""
    leather, flap, red = "8b5a2b", "a86f3a", "e63946"
    bag = Vector((-0.5, -0.06, 0.82))
    parts = [box(bag, (0.2, 0.42, 0.34), leather)]
    parts.append(box(bag + Vector((-0.02, 0, 0.1)), (0.2, 0.44, 0.16), flap))
    parts.append(box(bag + Vector((-0.12, 0, 0.02)), (0.04, 0.2, 0.12), red))  # envelope badge
    pts = [Vector((-0.44, -0.06, 0.98)), Vector((-0.2, -0.36, 1.16)), Vector((0.2, -0.33, 1.4)),
           Vector((0.33, -0.05, 1.5)), Vector((0.26, 0.28, 1.36)), Vector((-0.12, 0.33, 1.12)), Vector((-0.44, 0.12, 0.98))]
    parts.append(tube(pts, 0.04, leather))
    return finish("Mail_Bag", parts, voxel=0.016, target_tris=900)


def balloon():
    """A red balloon floating above the right hand (hung on the root bone)."""
    red, string = "ff4d6d", "ffffff"
    top = Vector((-0.95, 0.15, 3.55))
    parts = [sphere(top, (0.4, 0.4, 0.48), red, segs=24, rings=16)]
    parts.append(cone(top + Vector((0, 0, -0.5)), top + Vector((0, 0, -0.42)), 0.07, 0.02, red, segs=10))
    pts = [top + Vector((0, 0, -0.52)), Vector((-0.92, 0.1, 2.6)), Vector((-0.86, 0.04, 1.8)), Vector((-0.78, 0.0, 1.05))]
    parts.append(tube(pts, 0.015, string, tube_segs=6))
    return finish("Balloon", parts, voxel=0.012, target_tris=900)


def chef_hat():
    """A baker's tall puffy white hat."""
    white, band = "ffffff", "eef1f5"
    parts = [shell(HEAD + Vector((0, 0.03, 0.1)), (0.63, 0.63, 0.6), band, lambda p: p.z > 0.16, thickness=0.06)]
    parts.append(loft([(HEAD + Vector((0, 0.03, 0.4)), 0.56, 0.56), (HEAD + Vector((0, 0.03, 0.7)), 0.6, 0.6)], white, segs=32))
    for k in range(6):
        a = 2 * math.pi * k / 6
        parts.append(sphere(HEAD + Vector((math.cos(a) * 0.34, 0.03 + math.sin(a) * 0.34, 0.88)), (0.3, 0.3, 0.26), white, segs=16, rings=10))
    parts.append(sphere(HEAD + Vector((0, 0.03, 0.95)), (0.36, 0.36, 0.3), white, segs=18, rings=12))
    return finish("Chef_Hat", parts, voxel=0.016, target_tris=1300)


def ranger_hat():
    return _brim_hat("Ranger_Hat", "c2a36b", "6b4e2e", 0.76, 0.26)


def beret():
    """A painter's floppy beret, tipped to one side."""
    red, stalk = "d64545", "a83232"
    parts = [shell(HEAD + Vector((0, 0.03, 0.1)), (0.63, 0.63, 0.6), red, lambda p: p.z > 0.2, thickness=0.06)]
    parts.append(sphere(HEAD + Vector((0.12, 0.03, 0.58)), (0.72, 0.68, 0.16), red, segs=24, rings=12))
    parts.append(cone(HEAD + Vector((0.12, 0.03, 0.7)), HEAD + Vector((0.12, 0.03, 0.82)), 0.04, 0.02, stalk, segs=8))
    return finish("Beret", parts, voxel=0.016, target_tris=1000)


def heart_marker():
    """A big puffy heart: floats over whoever a parcel is for (a destination
    marker, deliberately not parcel-shaped). Centred on the origin, ~1 m."""
    pink, shine = "ff4d6d", "ffd1dc"
    parts = [sphere(Vector((-0.24, 0, 0.18)), (0.3, 0.2, 0.3), pink, segs=24, rings=16),
             sphere(Vector((0.24, 0, 0.18)), (0.3, 0.2, 0.3), pink, segs=24, rings=16)]
    parts.append(cone(Vector((0, 0, 0.12)), Vector((0, 0, -0.5)), 0.5, 0.03, pink, segs=24))
    parts.append(sphere(Vector((-0.3, -0.17, 0.3)), (0.08, 0.04, 0.08), shine, segs=12, rings=8))
    return finish("Heart_Marker", parts, voxel=0.014, target_tris=900)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    print("PROPS")
    for build in (pilot_cap, pilot_scarf, princess_tiara, princess_gown, astro_helmet, astro_pack,
                  hero_cape, hero_emblem, dino_hood, dino_tail, face_smile,
                  package, straw_hat, sun_hat, flat_cap, beanie, postie_cap, mail_bag, balloon,
                  chef_hat, ranger_hat, beret, heart_marker):
        build()
    for o in bpy.context.scene.objects:
        o.select_set(True)
    kwargs = dict(filepath=OUT, export_format="GLB", export_yup=True, export_apply=False)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(export_colors=True, **kwargs)
    print("BUILT", OUT)


main()
