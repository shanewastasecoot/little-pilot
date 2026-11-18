"""Build Little Pilot's characters in Blender, from code: a cheerful,
rounded toy style (big round head, big glossy eyes, short soft body,
chunky shoes) with princess gowns, a pilot and an explorer.

Run (from the project root):
    ./dev.sh characters
which runs
    flatpak run org.blender.Blender -b --factory-startup \
        -P tools/blender/build_characters.py -- assets/characters/player/player.glb

Everything is generated: one armature ("Rig") shared by every part, two
bodies (Body_M, Body_F), four hair styles (Hair_1..4, one mesh fits both
heads) and four outfits, each made for both bodies from that body's own
measurements so nothing pokes through (Outfit_1_M .. Outfit_4_F):
    1 pink ball gown, gloves, gold crown
    2 blue ball gown, gloves, silver tiara
    3 pilot: fur-collared flight jacket, scarf, goggles, trousers, boots
    4 explorer: safari shirt, shorts, socks, boots, satchel
All parts are skinned to the same bones with explicit weights (long hair
and skirts follow the chest and hips), and four animations are keyframed:
Idle, Walk, Run (loops, in place) and Jump.

Units: metres, ~1.85 m tall, Blender Z-up facing -Y (glTF/Godot: Y-up
facing +Z). Flat colours, one material per colour (glossy, toy-like). The
game scales the character to storybook size (~5 m) like the townspeople.
"""

import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "player.glb"
## --crowd: the same characters at about a quarter of the detail (fewer
## segments round every shape) for the townspeople crowd.
DETAIL = 0.5 if "--crowd" in ARGS else 1.0
FPS = 24


def segs_of(n, least=6):
    return max(least, int(round(n * DETAIL)))

SKIN = "f7c9a8"
BLUSH = "f59a9a"
LIPS = "c2454e"
EYE_WHITE = "ffffff"
IRIS = "3a8fd9"
PUPIL = "1c1a24"
BROW = "6b4226"
LASH = "2a2024"

# --- Skeleton (toy proportions: about 2.6 heads tall) --------------------------
BONES = {
    "hips": ((0, 0, 0.50), (0, 0, 0.62), None),
    "spine": ((0, 0, 0.62), (0, 0, 0.80), "hips"),
    "chest": ((0, 0, 0.80), (0, 0, 0.98), "spine"),
    "neck": ((0, 0, 0.98), (0, 0, 1.06), "chest"),
    "head": ((0, 0, 1.06), (0, 0, 1.80), "neck"),
}
for side, s in (("L", 1), ("R", -1)):
    BONES["upperarm." + side] = ((0.20 * s, 0, 0.94), (0.31 * s, 0.01, 0.76), "chest")
    BONES["forearm." + side] = ((0.31 * s, 0.01, 0.76), (0.38 * s, 0, 0.59), "upperarm." + side)
    BONES["thigh." + side] = ((0.10 * s, 0, 0.53), (0.11 * s, 0, 0.30), "hips")
    BONES["shin." + side] = ((0.11 * s, 0, 0.30), (0.11 * s, 0.01, 0.09), "thigh." + side)
    BONES["foot." + side] = ((0.11 * s, 0.01, 0.09), (0.11 * s, -0.12, 0.03), "shin." + side)

# Torso rings (z, half width, half depth) from below the hips to the neck.
BODIES = {
    "M": {
        "torso": [(0.46, 0.15, 0.13), (0.54, 0.175, 0.15), (0.66, 0.18, 0.155), (0.78, 0.19, 0.155),
                  (0.90, 0.20, 0.15), (0.98, 0.17, 0.12), (1.03, 0.07, 0.065)],
        "arm": (0.068, 0.058, 0.052), "leg": (0.09, 0.075, 0.064), "hand": 0.072,
    },
    "F": {
        "torso": [(0.46, 0.16, 0.13), (0.54, 0.185, 0.15), (0.66, 0.15, 0.13), (0.76, 0.145, 0.125),
                  (0.88, 0.17, 0.14), (0.97, 0.15, 0.11), (1.03, 0.065, 0.06)],
        "arm": (0.06, 0.052, 0.047), "leg": (0.086, 0.07, 0.06), "hand": 0.066,
    },
}
HEAD_C = Vector((0, 0, 1.40))
HEAD_R = 0.36

# --- Materials -----------------------------------------------------------------

_materials = {}


def mat(hexcol, rough=0.45):
    key = (hexcol, rough)
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new("C_%s_%02d" % (hexcol, int(rough * 100)))
    c = tuple(int(hexcol[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    lin = tuple((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*lin, 1.0)
    _materials[key] = m
    return m


# Glossy bits: eyes, crowns, gems, goggles.
GLOSSY = {EYE_WHITE, IRIS, PUPIL, "ffd23f", "e8b923", "dfe6f0", "e63946", "3aa0ff", "9fd8ff", "b8860b", "c0c8d0"}


class Part:
    """A mesh being built: vertices with bone weights, faces with colours."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.palette = []
        self._pending = []

    def colour(self, hexcol):
        if hexcol not in self.palette:
            self.palette.append(hexcol)
        return self.palette.index(hexcol)

    def vert(self, co, weights):
        v = self.bm.verts.new(co)
        self._pending.append((v, weights))
        return v

    def face(self, verts, hexcol):
        f = self.bm.faces.new(verts)
        f.material_index = self.colour(hexcol)
        return f

    def build(self, rig):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.verts.index_update()
        self.bm.to_mesh(mesh)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        for h in self.palette:
            mesh.materials.append(mat(h, 0.15 if h in GLOSSY else 0.45))
        groups = {n: obj.vertex_groups.new(name=n) for n in BONES}
        for v, weights in self._pending:
            total = sum(weights.values()) or 1.0
            for b, w in weights.items():
                if w > 0.001:
                    groups[b].add([v.index], w / total, "REPLACE")
        for p in mesh.polygons:
            p.use_smooth = True
        obj.parent = rig
        mod = obj.modifiers.new("Rig", "ARMATURE")
        mod.object = rig
        self.bm.free()
        return obj


def frame_for(d):
    d = d.normalized()
    ref = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
    x = ref.cross(d).normalized()
    y = d.cross(x).normalized()
    return x, y


def loft(part, rings, hexcol, cap_start=True, cap_end=True, segs=20, colours=None, wobble=None):
    """rings: (centre, direction, half_width, half_depth, weights). wobble(i, a)
    multiplies the radius at ring i, angle a (ruffles, scallops)."""
    segs = segs_of(segs)
    loops = []
    for ri, (c, d, rx, ry, w) in enumerate(rings):
        x, y = frame_for(d)
        loop = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            k = wobble(ri, a) if wobble else 1.0
            loop.append(part.vert(c + x * math.cos(a) * rx * k + y * math.sin(a) * ry * k, w))
        loops.append(loop)
    for r in range(len(loops) - 1):
        col = colours[r] if colours else hexcol
        a, b = loops[r], loops[r + 1]
        for i in range(segs):
            j = (i + 1) % segs
            part.face([a[i], a[j], b[j], b[i]], col)
    if cap_start:
        c, d, _, _, w = rings[0]
        mid = part.vert(c - d.normalized() * 0.002, w)
        for i in range(segs):
            part.face([loops[0][(i + 1) % segs], loops[0][i], mid], colours[0] if colours else hexcol)
    if cap_end:
        c, d, _, _, w = rings[-1]
        mid = part.vert(c + d.normalized() * 0.002, w)
        for i in range(segs):
            part.face([loops[-1][i], loops[-1][(i + 1) % segs], mid], colours[-1] if colours else hexcol)


def ellipsoid(part, centre, radii, hexcol, weights, segs=16, rings=10, z_from=-1.0, z_to=1.0, basis=None):
    """A (part of an) ellipsoid. basis: optional 3x3 rotation for its axes."""
    rot = basis or Matrix.Identity(3)
    segs = segs_of(segs)
    rings = segs_of(rings, 3)
    loops = []
    zs = [z_from + (z_to - z_from) * k / rings for k in range(rings + 1)]
    for z in zs:
        r = math.sqrt(max(0.0, 1.0 - z * z))
        loop = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            local = Vector((math.cos(a) * r * radii[0], math.sin(a) * r * radii[1], z * radii[2]))
            co = centre + rot @ local
            loop.append(part.vert(co, weights(co) if callable(weights) else weights))
        loops.append(loop)
    for k in range(rings):
        a, b = loops[k], loops[k + 1]
        for i in range(segs):
            j = (i + 1) % segs
            part.face([a[i], a[j], b[j], b[i]], hexcol)
    for end, zc in ((0, z_from), (-1, z_to)):
        if abs(zc) < 0.999:
            p = centre + rot @ Vector((0, 0, zc * radii[2]))
            mid = part.vert(p, weights(p) if callable(weights) else weights)
            loop = loops[end]
            for i in range(segs):
                if end == 0:
                    part.face([loop[(i + 1) % segs], loop[i], mid], hexcol)
                else:
                    part.face([loop[i], loop[(i + 1) % segs], mid], hexcol)


def blend(a, b, t):
    t = max(0.0, min(1.0, t))
    return {a: 1.0 - t, b: t}


def torso_weights(z):
    if z < 0.62:
        return blend("hips", "spine", (z - 0.56) / 0.12)
    if z < 0.80:
        return blend("spine", "chest", (z - 0.74) / 0.12)
    return blend("chest", "neck", (z - 1.00) / 0.05)


def body_ring(body, z):
    src = body["torso"]
    for k in range(len(src) - 1):
        if src[k][0] <= z <= src[k + 1][0]:
            u = (z - src[k][0]) / (src[k + 1][0] - src[k][0])
            u = u * u * (3 - 2 * u)  # smooth between rings
            return src[k][1] + (src[k + 1][1] - src[k][1]) * u, src[k][2] + (src[k + 1][2] - src[k][2]) * u
    return (src[0][1], src[0][2]) if z < src[0][0] else (src[-1][1], src[-1][2])


def torso(part, body, hexcol, z0, z1, grow=0.0, cap_start=True, cap_end=True, steps=10, flare=None):
    rings = []
    for k in range(steps + 1):
        z = z0 + (z1 - z0) * k / steps
        rx, ry = body_ring(body, z)
        f = flare(z) if flare else 0.0
        rings.append((Vector((0, 0, z)), Vector((0, 0, 1)), rx + grow + f, ry + grow + f * 0.85, torso_weights(z)))
    loft(part, rings, hexcol, cap_start, cap_end)


def limb_point(side, kind, t):
    if kind == "arm":
        b1, b2 = "upperarm." + side, "forearm." + side
    else:
        b1, b2 = "thigh." + side, "shin." + side
    p0, p1, p2 = Vector(BONES[b1][0]), Vector(BONES[b1][1]), Vector(BONES[b2][1])
    if t <= 0.5:
        return p0.lerp(p1, t / 0.5), p1 - p0
    return p1.lerp(p2, (t - 0.5) / 0.5), p2 - p1


def limb_weights(side, kind, t):
    b1 = ("upperarm." if kind == "arm" else "thigh.") + side
    b2 = ("forearm." if kind == "arm" else "shin.") + side
    if kind == "arm" and t < 0.12:
        return {b1: 0.5 + t / 0.24, "chest": 0.5 - t / 0.24}
    if kind == "leg" and t < 0.1:
        return {b1: 0.6 + t * 4.0, "hips": 0.4 - t * 4.0}
    return blend(b1, b2, (t - 0.42) / 0.16)


def limb(part, side, kind, body, hexcol, t0=0.0, t1=1.0, grow=0.0, cap_start=True, cap_end=True,
         colours=None, tuck=0.0, puff=None, steps=8):
    radii = body["arm" if kind == "arm" else "leg"]
    steps = segs_of(steps, 3)
    rings = []
    for k in range(steps + 1):
        t = t0 + (t1 - t0) * k / steps
        c, d = limb_point(side, kind, t)
        r = radii[0] + (radii[1] - radii[0]) * (t / 0.5) if t <= 0.5 else radii[1] + (radii[2] - radii[1]) * ((t - 0.5) / 0.5)
        if tuck > 0.0 and k == 0:
            c = c + Vector((-c.x, 0, 0)).normalized() * tuck
        extra = puff(t) if puff else 0.0
        rings.append((c, d, r + grow + extra, r * 0.95 + grow + extra, limb_weights(side, kind, t)))
    loft(part, rings, hexcol, cap_start, cap_end, segs=16, colours=colours)


def shoe(part, side, hexcol, grow=0.0, height=0.1, toe=0.16):
    s = 1 if side == "L" else -1
    w = {"foot." + side: 0.85, "shin." + side: 0.15}
    ellipsoid(part, Vector((0.11 * s, -0.035, 0.05)), (0.085 + grow, toe + grow, height * 0.5 + grow), hexcol, w,
              segs=16, rings=8, z_from=-0.55)


def mitten(part, side, body, hexcol, grow=0.0):
    s = 1 if side == "L" else -1
    c = Vector(BONES["forearm." + side][1]) + Vector((0.02 * s, 0, -0.05))
    r = body["hand"] + grow
    ellipsoid(part, c, (r * 0.85, r * 0.75, r * 1.05), hexcol, {"forearm." + side: 1.0}, segs=12, rings=8)
    ellipsoid(part, c + Vector((-0.02 * s, -r * 0.6, 0.015)), (r * 0.32, r * 0.3, r * 0.42), hexcol, {"forearm." + side: 1.0}, segs=8, rings=5)


def head_weights(co):
    return {"head": 1.0} if co.z > 1.10 else blend("neck", "head", (co.z - 1.00) / 0.10)


def on_face(x, z, out=0.0):
    """A point on the front of the head at (x, z) from its centre, pushed
    `out` metres along the surface normal."""
    y = -math.sqrt(max(0.0, HEAD_R ** 2 - x * x - z * z))
    p = Vector((x, y, z))
    return HEAD_C + p + p.normalized() * out, p.normalized()


def facing(n):
    """Rotation turning an ellipsoid's Y axis to point along normal n."""
    return Vector((0, -1, 0)).rotation_difference(-n).to_matrix()


# --- Bodies ------------------------------------------------------------------


def build_body(key, rig):
    body = BODIES[key]
    p = Part("Body_" + key)
    torso(p, body, SKIN, 0.44, 1.03)
    loft(p, [(Vector((0, 0, 0.98)), Vector((0, 0, 1)), 0.075, 0.07, {"chest": 0.5, "neck": 0.5}),
             (Vector((0, 0, 1.10)), Vector((0, 0, 1)), 0.075, 0.07, {"neck": 0.5, "head": 0.5})], SKIN, segs=16)
    # Head: big and round, slightly wider than tall at the cheeks.
    ellipsoid(p, HEAD_C, (HEAD_R * 1.02, HEAD_R * 0.96, HEAD_R), SKIN, head_weights, segs=28, rings=18)
    # Ears.
    for s in (1, -1):
        ellipsoid(p, HEAD_C + Vector((HEAD_R * 1.0 * s, 0.02, -0.02)), (0.04, 0.06, 0.075), SKIN, {"head": 1.0}, segs=10, rings=6)
    # Big glossy eyes: white, coloured iris, pupil, two highlights.
    for s in (1, -1):
        x = 0.125 * s
        c, n = on_face(x, 0.0, -0.026)
        rot = facing(n)
        ellipsoid(p, c, (0.074, 0.036, 0.094), EYE_WHITE, {"head": 1.0}, segs=16, rings=8, basis=rot)
        c2, _ = on_face(x + 0.006 * s, -0.008, 0.002)
        ellipsoid(p, c2, (0.054, 0.016, 0.068), IRIS, {"head": 1.0}, segs=16, rings=6, basis=rot)
        c3, _ = on_face(x + 0.008 * s, -0.01, 0.012)
        ellipsoid(p, c3, (0.03, 0.01, 0.038), PUPIL, {"head": 1.0}, segs=12, rings=5, basis=rot)
        if DETAIL >= 1.0:  # sparkles (too small to see on townspeople)
            c4, _ = on_face(x + 0.028 * s, 0.03, 0.02)
            ellipsoid(p, c4, (0.018, 0.006, 0.02), EYE_WHITE, {"head": 1.0}, segs=8, rings=4, basis=rot)
            c5, _ = on_face(x - 0.012 * s, -0.035, 0.018)
            ellipsoid(p, c5, (0.009, 0.005, 0.009), EYE_WHITE, {"head": 1.0}, segs=6, rings=3, basis=rot)
        # Eyebrows: one soft arch each, thin at the ends.
        rings = []
        for k in range(7):
            u = (k - 3) / 3.0
            cb, nb = on_face(x + u * 0.055 * s, 0.165 + 0.02 * (1 - u * u), 0.006)
            tangent = Vector((s, 0, -0.35 * u * s)).normalized()
            thick = 0.011 * (1.0 - 0.45 * abs(u))
            rings.append((cb, tangent, thick, thick * 0.6, {"head": 1.0}))
        loft(p, rings, BROW, segs=8)
        if key == "F":
            # Lashes: three flicks at the top outer corner.
            for k in range(3):
                lx = x + (0.045 + k * 0.014) * s
                lz = 0.075 + k * 0.012
                cl, nl = on_face(lx, lz, 0.004)
                ellipsoid(p, cl, (0.007, 0.006, 0.02), LASH, {"head": 1.0}, segs=6, rings=3,
                          basis=facing(nl) @ Matrix.Rotation(-0.6 * s, 3, "Y"))
        # Blush.
        cc, nc = on_face(0.2 * s, -0.11, -0.004)
        ellipsoid(p, cc, (0.05, 0.012, 0.03), BLUSH, {"head": 1.0}, segs=10, rings=4, basis=facing(nc))
    # Button nose.
    cn, nn = on_face(0.0, -0.075, 0.005)
    ellipsoid(p, cn, (0.034, 0.03, 0.028), "f2b591", {"head": 1.0}, segs=10, rings=6, basis=facing(nn))
    # Big smile: an arc of beads, corners up, with a little darker middle.
    for k in range(11):
        a = (k - 5) / 5.0
        cm, nm = on_face(a * 0.075, -0.16 + 0.03 * a * a, 0.003)
        ellipsoid(p, cm, (0.012, 0.008, 0.01), LIPS, {"head": 1.0}, segs=6, rings=3, basis=facing(nm))
    for side in ("L", "R"):
        limb(p, side, "arm", body, SKIN)
        mitten(p, side, body, SKIN)
        limb(p, side, "leg", body, SKIN)
        shoe(p, side, SKIN, height=0.08, toe=0.12)
    return p.build(rig)


# --- Hair ----------------------------------------------------------------------


def hair_cap(p, hexcol, low=0.1, fringe=0.0, grow=0.03, part_side=0.0):
    """Hair over the top and back of the head down to `low` (0..1 below
    the centre), the face kept clear with a fringe line `fringe` low."""
    r = HEAD_R + grow
    segs, rings = segs_of(28), segs_of(14, 6)
    loops = []
    zs = [1.0 - (1.0 + low) * k / rings for k in range(rings + 1)]
    for z in zs:
        rr = math.sqrt(max(0.0, 1.0 - z * z))
        loop = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            x, y = math.cos(a) * rr, math.sin(a) * rr
            zz = z
            line = 0.64 - fringe + 0.08 * part_side * x  # well above the brows
            if y < -0.3 and z < line:
                zz = max(z, line - 0.22 * (1 - abs(x)) ** 2)
                rr2 = math.sqrt(max(0.0, 1.0 - zz * zz))
                x, y = math.cos(a) * rr2, math.sin(a) * rr2
            co = HEAD_C + Vector((x * r * 1.02, y * r * 0.97, zz * r * 1.03))
            loop.append(p.vert(co, {"head": 1.0}))
        loops.append(loop)
    top = p.vert(HEAD_C + Vector((0, 0, r * 1.03)), {"head": 1.0})
    for i in range(segs):
        p.face([loops[0][i], loops[0][(i + 1) % segs], top], hexcol)
    for k in range(rings):
        a, b = loops[k], loops[k + 1]
        for i in range(segs):
            j = (i + 1) % segs
            p.face([a[j], a[i], b[i], b[j]], hexcol)


def hang_weights(co):
    """Long hair: the head at the top, shading into the chest lower down."""
    t = max(0.0, min(1.0, (1.12 - co.z) / 0.35))
    return {"head": 1.0 - t * 0.7, "chest": t * 0.7}


def build_hair(n, rig):
    p = Part("Hair_%d" % n)
    if n == 1:  # long golden princess waves with a side-swept fringe
        col = "f5cf6a"
        hair_cap(p, col, low=0.25, fringe=0.1, part_side=1.0)
        ellipsoid(p, HEAD_C + Vector((-0.1, -0.24, 0.2)), (0.2, 0.1, 0.09), col, {"head": 1.0}, segs=16, rings=8,
                  basis=Matrix.Rotation(-0.35, 3, "Y"))
        for s in (1, -1):  # framing locks down the sides of the face
            for k in range(4):
                c = HEAD_C + Vector((0.33 * s, -0.08, -0.05 - k * 0.11))
                ellipsoid(p, c + Vector((0.02 * s * math.sin(k * 1.7), 0, 0)), (0.085, 0.09, 0.08), col,
                          hang_weights, segs=12, rings=6)
        # The long back: a wavy curtain down to mid-back.
        for k in range(6):
            z = 1.30 - k * 0.13
            w = 0.34 - k * 0.012
            ellipsoid(p, Vector((0.0, 0.2 + k * 0.012, z)), (w, 0.14, 0.1), col, hang_weights, segs=16, rings=6)
            for s in (1, -1):
                ellipsoid(p, Vector((0.2 * s + 0.03 * math.sin(k * 2.1), 0.17, z - 0.05)), (0.11, 0.1, 0.09), col,
                          hang_weights, segs=10, rings=5)
    elif n == 2:  # short tousled hair with a cowlick
        col = "7a4a2a"
        hair_cap(p, col, low=0.1, fringe=0.06)
        for k in range(6):
            a = -1.1 + k * 0.44
            c = HEAD_C + Vector((math.sin(a) * 0.2, -0.17 + abs(a) * 0.05, 0.27 + math.cos(a) * 0.04))
            ellipsoid(p, c, (0.08, 0.07, 0.06), col, {"head": 1.0}, segs=10, rings=5,
                      basis=Matrix.Rotation(a * 0.4, 3, "Y"))
        ellipsoid(p, HEAD_C + Vector((0.04, 0.0, 0.4)), (0.03, 0.03, 0.08), col, {"head": 1.0}, segs=8, rings=5,
                  basis=Matrix.Rotation(0.5, 3, "X"))
    elif n == 3:  # ponytail with a big bow, auburn
        col = "c0602e"
        hair_cap(p, col, low=0.3, fringe=0.08)
        tie = HEAD_C + Vector((0, 0.3, 0.2))
        for k, (dy, dz, r) in enumerate([(0.38, 0.12, 0.1), (0.44, 0.0, 0.11), (0.46, -0.13, 0.1), (0.44, -0.25, 0.08), (0.4, -0.34, 0.05)]):
            ellipsoid(p, HEAD_C + Vector((0, dy, dz)), (r, r * 0.9, r * 1.25), col, hang_weights, segs=12, rings=6)
        bow = "ff6fae"
        for s in (1, -1):
            ellipsoid(p, tie + Vector((0.09 * s, 0.02, 0.03)), (0.09, 0.035, 0.065), bow, {"head": 1.0}, segs=12, rings=6,
                      basis=Matrix.Rotation(0.3 * s, 3, "Y"))
        ellipsoid(p, tie + Vector((0, 0.03, 0.02)), (0.035, 0.035, 0.035), bow, {"head": 1.0}, segs=8, rings=5)
    else:  # glossy black bob with a red headband
        col = "2e2420"
        hair_cap(p, col, low=0.55, fringe=0.14, grow=0.045)
        ellipsoid(p, HEAD_C + Vector((0, -0.2, 0.25)), (0.25, 0.1, 0.07), col, {"head": 1.0}, segs=16, rings=6)
        for s in (1, -1):
            ellipsoid(p, HEAD_C + Vector((0.3 * s, 0.02, -0.16)), (0.11, 0.2, 0.12), col, {"head": 1.0}, segs=12, rings=6)
        # Headband: an arc over the top.
        band = []
        for k in range(13):
            a = math.pi * k / 12
            band.append((HEAD_C + Vector((math.cos(a) * (HEAD_R + 0.055), -0.06, math.sin(a) * (HEAD_R + 0.06))),
                         Vector((0, 1, 0)), 0.022, 0.035, {"head": 1.0}))
        for k in range(len(band) - 1):
            pass
        loft(p, [(Vector((-(HEAD_R + 0.055), -0.06, 0.0)) + HEAD_C, Vector((0, 0, 1)), 0.022, 0.04, {"head": 1.0})] +
             [(HEAD_C + Vector((math.cos(math.pi * (1 - k / 10)) * (HEAD_R + 0.055), -0.06,
                                math.sin(math.pi * (1 - k / 10)) * (HEAD_R + 0.065))),
               Vector((math.sin(math.pi * (1 - k / 10)), 0, -math.cos(math.pi * (1 - k / 10)))) * -1, 0.022, 0.04, {"head": 1.0})
              for k in range(1, 11)], "e63946", segs=8)
    return p.build(rig)


# --- Outfits -------------------------------------------------------------------

# Sits down on the hair: the hair cap's height at the crown's radius.
CROWN_Z = HEAD_C.z + math.sqrt((HEAD_R + 0.03) ** 2 - 0.15 ** 2) * 1.03 - 0.012


def crown(p, gold, gem_a, gem_b, tiara=False):
    """A jewelled crown (or tiara) sitting on top of the hair."""
    w = {"head": 1.0}
    r0 = 0.15 if not tiara else 0.2
    z0 = CROWN_Z + (0.0 if not tiara else -0.06)
    yoff = 0.0 if not tiara else -0.08
    rings = [(HEAD_C * 0 + Vector((0, yoff, z0)), Vector((0, 0, 1)), r0, r0 * 0.92, w),
             (Vector((0, yoff, z0 + 0.05)), Vector((0, 0, 1)), r0 * 1.02, r0 * 0.94, w)]
    loft(p, rings, gold, cap_start=True, cap_end=False, segs=24)
    points = 5 if not tiara else 3
    for k in range(points):
        a = (-0.5 + k / (points - 1)) * (math.pi * 0.8 if tiara else 2 * math.pi)
        a += 0 if tiara else 0.0
        if tiara:
            x, y = math.sin(a) * r0, -math.cos(a) * r0 * 0.94 + yoff
        else:
            x, y = math.cos(a) * r0, math.sin(a) * r0 * 0.92
        tall = 0.09 if (not tiara or k == 1) else 0.06
        ellipsoid(p, Vector((x, y, z0 + 0.05 + tall * 0.5)), (0.03, 0.03, tall * 0.55), gold, w, segs=8, rings=5)
        ellipsoid(p, Vector((x, y, z0 + 0.05 + tall + 0.012)), (0.018, 0.018, 0.018), gold, w, segs=8, rings=4)
        gx, gy = (x * 1.08, y * 1.08) if not tiara else (x * 1.04, y - 0.012)
        ellipsoid(p, Vector((gx, gy, z0 + 0.03)), (0.02, 0.012, 0.022), gem_a if k % 2 == 0 else gem_b, w, segs=8, rings=4)


def gown(p, body, bodice, skirt, trim, glove, shoe_col):
    g = 0.016
    # Bodice, closed over the shoulders, with a trim at the waist.
    torso(p, body, bodice, 0.56, 1.03, g, cap_start=False, cap_end=True)
    loft(p, [(Vector((0, 0, 0.6)), Vector((0, 0, 1)), body_ring(body, 0.6)[0] + g + 0.012, body_ring(body, 0.6)[1] + g + 0.012, torso_weights(0.6)),
             (Vector((0, 0, 0.64)), Vector((0, 0, 1)), body_ring(body, 0.64)[0] + g + 0.012, body_ring(body, 0.64)[1] + g + 0.012, torso_weights(0.64))],
         trim, cap_start=False, cap_end=False)
    # Puffed sleeves.
    for side, s in (("L", 1), ("R", -1)):
        c, _ = limb_point(side, "arm", 0.1)
        ellipsoid(p, c + Vector((0.01 * s, 0, 0.0)), (0.1, 0.1, 0.09), bodice,
                  {"upperarm." + side: 0.7, "chest": 0.3}, segs=14, rings=8)
        # Long gloves from mid-forearm.
        limb(p, side, "arm", body, glove, 0.55, 1.0, 0.01, cap_start=False, cap_end=True)
        mitten(p, side, body, glove, grow=0.008)
    # Bell skirt with a scalloped, ruffled hem.
    rings = []
    zs = [0.62, 0.55, 0.47, 0.38, 0.29, 0.2, 0.12, 0.08]
    for k, z in enumerate(zs):
        u = (0.62 - z) / (0.62 - 0.08)
        rx0, ry0 = body_ring(body, min(z, 0.6))
        rx = (rx0 + g + 0.02) + (0.48 - rx0) * (u ** 0.8)
        ry = (ry0 + g + 0.02) + (0.42 - ry0) * (u ** 0.8)
        w = {"hips": 0.75, "spine": 0.25} if k < 2 else {"hips": 1.0}
        rings.append((Vector((0, 0, z)), Vector((0, 0, 1)), rx, ry, w))
    loft(p, rings, skirt, cap_start=False, cap_end=True, segs=32,
         wobble=lambda ri, a: 1.0 + (0.05 * math.cos(a * 8) if ri >= len(zs) - 2 else 0.02 * math.cos(a * 8)))
    # A hip drape (two swags) and a hem ruffle in the trim colour.
    loft(p, [(Vector((0, 0, 0.49)), Vector((0, 0, 1)), 0.27, 0.24, {"hips": 1.0}),
             (Vector((0, 0, 0.535)), Vector((0, 0, 1)), 0.25, 0.22, {"hips": 1.0})], bodice, cap_start=False, cap_end=False, segs=32,
         wobble=lambda ri, a: 1.0 + 0.05 * abs(math.sin(a * 3)))
    loft(p, [(Vector((0, 0, 0.115)), Vector((0, 0, 1)), 0.5, 0.44, {"hips": 1.0}),
             (Vector((0, 0, 0.15)), Vector((0, 0, 1)), 0.49, 0.43, {"hips": 1.0})], trim, cap_start=False, cap_end=False, segs=32,
         wobble=lambda ri, a: 1.0 + 0.05 * math.cos(a * 8))
    for side in ("L", "R"):
        shoe(p, side, shoe_col, grow=0.01, height=0.1, toe=0.13)


def build_outfit(n, key, rig):
    body = BODIES[key]
    p = Part("Outfit_%d_%s" % (n, key))
    if n == 1:  # pink ball gown, gold crown with red and blue gems
        gown(p, body, "f06aa8", "ffa6d6", "ffd23f", "ffffff", "f06aa8")
        crown(p, "ffd23f", "e63946", "3aa0ff")
    elif n == 2:  # blue ball gown, silver tiara
        gown(p, body, "4a9be8", "8fd0ff", "dfe6f0", "ffffff", "4a9be8")
        crown(p, "dfe6f0", "9fd8ff", "3aa0ff", tiara=True)
    elif n == 3:  # pilot
        jacket, fur, scarf, trousers, boot = "8b5a2b", "f1e2c6", "fafaf5", "c9b27c", "4a3324"
        g = 0.018
        torso(p, body, jacket, 0.48, 1.03, g + 0.008, cap_start=True, cap_end=True)
        # Zip and pocket flaps.
        front = body_ring(body, 0.78)[1] + g + 0.012
        ellipsoid(p, Vector((0, -front, 0.74)), (0.012, 0.01, 0.2), "c9a14a", {"spine": 0.5, "chest": 0.5}, segs=6, rings=6)
        for s in (1, -1):
            ellipsoid(p, Vector((0.1 * s, -front + 0.004, 0.6)), (0.06, 0.012, 0.03), "70461f", {"spine": 1.0}, segs=8, rings=4)
        # Fur collar and a scarf with a flying tail.
        loft(p, [(Vector((0, 0, 0.97)), Vector((0, 0, 1)), 0.2, 0.17, {"chest": 1.0}),
                 (Vector((0, 0, 1.05)), Vector((0, 0, 1)), 0.13, 0.12, {"chest": 0.5, "neck": 0.5})], fur, cap_start=False, cap_end=False,
             wobble=lambda ri, a: 1.0 + 0.06 * abs(math.sin(a * 5)))
        loft(p, [(Vector((0, 0, 1.03)), Vector((0, 0, 1)), 0.1, 0.095, {"neck": 1.0}),
                 (Vector((0, 0, 1.08)), Vector((0, 0, 1)), 0.095, 0.09, {"neck": 1.0})], scarf, cap_start=False, cap_end=False)
        ellipsoid(p, Vector((0.09, 0.12, 0.92)), (0.05, 0.03, 0.14), scarf, {"chest": 1.0}, segs=8, rings=5,
                  basis=Matrix.Rotation(0.5, 3, "X"))
        for side in ("L", "R"):
            limb(p, side, "arm", body, jacket, 0.0, 0.88, g + 0.012, cap_start=False, tuck=0.06)
            limb(p, side, "arm", body, fur, 0.84, 0.92, g + 0.024, cap_start=False, cap_end=False)
            mitten(p, side, body, "6b4226", grow=0.01)
            limb(p, side, "leg", body, trousers, 0.0, 0.78, g, cap_start=False, tuck=0.03)
            limb(p, side, "leg", body, boot, 0.74, 1.0, g + 0.02)
            shoe(p, side, boot, grow=0.018, height=0.11)
        torso(p, body, trousers, 0.44, 0.52, g, cap_start=True, cap_end=False)
        # Goggles up on the forehead, strap round the head.
        strap = []
        for k in range(17):
            a = 2 * math.pi * k / 16
            strap.append((HEAD_C + Vector((math.cos(a) * (HEAD_R + 0.04), math.sin(a) * (HEAD_R + 0.03), 0.17)),
                          Vector((-math.sin(a), math.cos(a), 0)), 0.03, 0.012, {"head": 1.0}))
        loft(p, strap[:-1] + [strap[0]], "5b3a1e", cap_start=False, cap_end=False, segs=6)
        for s in (1, -1):
            c, nrm = on_face(0.09 * s, 0.2, 0.04)
            rot = facing(nrm)
            ellipsoid(p, c, (0.07, 0.04, 0.06), "b8860b", {"head": 1.0}, segs=14, rings=6, basis=rot)
            ellipsoid(p, c - nrm * -0.03, (0.055, 0.015, 0.047), "9fd8ff", {"head": 1.0}, segs=14, rings=5, basis=rot)
    else:  # explorer
        shirt, pocket, shorts, sock, boot, bag = "d8c38a", "c4ad72", "a68a52", "fafaf5", "6b4a2b", "8b5a2b"
        g = 0.016
        torso(p, body, shirt, 0.5, 1.03, g, cap_start=True, cap_end=True)
        front = body_ring(body, 0.86)[1] + g + 0.01
        for s in (1, -1):
            ellipsoid(p, Vector((0.09 * s, -front, 0.84)), (0.05, 0.012, 0.045), pocket, {"chest": 1.0}, segs=8, rings=4)
        loft(p, [(Vector((0, 0, 0.52)), Vector((0, 0, 1)), body_ring(body, 0.52)[0] + g + 0.012, body_ring(body, 0.52)[1] + g + 0.012, {"hips": 1.0}),
                 (Vector((0, 0, 0.56)), Vector((0, 0, 1)), body_ring(body, 0.56)[0] + g + 0.012, body_ring(body, 0.56)[1] + g + 0.012, {"hips": 1.0})],
             "5b3a1e", cap_start=False, cap_end=False)
        torso(p, body, shorts, 0.44, 0.52, g + 0.004, cap_start=True, cap_end=False)
        for side in ("L", "R"):
            limb(p, side, "arm", body, shirt, 0.0, 0.42, g + 0.012, cap_start=False, tuck=0.06,
                 puff=lambda t: 0.012 if t > 0.34 else 0.0)  # rolled cuffs
            mitten(p, side, body, SKIN)
            limb(p, side, "leg", body, shorts, 0.0, 0.36, g + 0.012, cap_start=False, tuck=0.03)
            limb(p, side, "leg", body, sock, 0.7, 0.92, g + 0.006, cap_start=False)
            shoe(p, side, boot, grow=0.018, height=0.12)
        # Satchel on the hip, strap across the chest.
        ellipsoid(p, Vector((-0.22, -0.06, 0.5)), (0.06, 0.1, 0.08), bag, {"hips": 1.0}, segs=10, rings=6)
        rings = []
        for k in range(9):
            t = k / 8
            c = Vector((0.18 - 0.4 * t, -body_ring(body, 0.9 - 0.36 * t)[1] - g - 0.014, 0.98 - 0.42 * t))
            rings.append((c, Vector((-0.4, 0, -0.42)), 0.025, 0.008, torso_weights(c.z)))
        loft(p, rings, bag, segs=6)
    return p.build(rig)


# --- Rig and animation -----------------------------------------------------------

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def build_rig():
    arm_data = bpy.data.armatures.new("Rig")
    rig = bpy.data.objects.new("Rig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent) in BONES.items():
        b = arm_data.edit_bones.new(name)
        b.head = head
        b.tail = tail
        b.roll = 0.0
        if parent:
            b.parent = arm_data.edit_bones[parent]
            b.use_connect = tuple(arm_data.edit_bones[parent].tail) == tuple(head)
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def local_rot(rig, bone, axis, deg):
    rest = rig.data.bones[bone].matrix_local.to_3x3()
    q = Quaternion(axis, math.radians(deg))
    return (rest.inverted() @ q.to_matrix() @ rest).to_quaternion()


def pose(rig, frame, rots, hips_z=0.0):
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        q = Quaternion()
        for axis, deg in rots.get(pb.name, []):
            q = local_rot(rig, pb.name, axis, deg) @ q
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "hips":
            pb.location = rig.data.bones["hips"].matrix_local.to_3x3().inverted() @ Vector((0, 0, hips_z))
            pb.keyframe_insert("location", frame=frame)


def cycle(name, frames, fn, rig):
    act = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = act
    for f in range(frames + 1):
        rots, hz = fn(f / frames)
        pose(rig, f, rots, hz)
    act.use_fake_user = True
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    rig.animation_data.action = None


def arms_down(extra_l=0.0, extra_r=0.0, bend=12.0):
    return {"upperarm.L": [(X, extra_l)], "upperarm.R": [(X, extra_r)],
            "forearm.L": [(X, -bend)], "forearm.R": [(X, -bend)]}


def idle(t):
    s = math.sin(t * 2 * math.pi)
    r = arms_down(2 * s, 2 * s, 10 + 2 * s)
    r["chest"] = [(X, 1.5 * s)]
    r["head"] = [(Y, 3.0 * math.sin(t * 2 * math.pi + 1.0)), (X, -1.5 * s)]
    return r, 0.005 * s - 0.005


def walk(t):
    a = t * 2 * math.pi
    s = math.sin(a)
    swing = 40.0
    r = arms_down(swing * 0.7 * s, -swing * 0.7 * s, 16)
    r["thigh.L"] = [(X, -swing * s)]
    r["thigh.R"] = [(X, swing * s)]
    r["shin.L"] = [(X, 50 * max(0.0, math.sin(a + 1.4)) + 4)]
    r["shin.R"] = [(X, 50 * max(0.0, math.sin(a + 1.4 + math.pi)) + 4)]
    r["foot.L"] = [(X, -10 * math.sin(a + 0.6))]
    r["foot.R"] = [(X, 10 * math.sin(a + 0.6))]
    r["hips"] = [(Z, 6 * s)]
    r["chest"] = [(Z, -7 * s), (X, 3)]
    r["head"] = [(Z, 3 * s), (Y, 2 * s)]
    return r, -0.022 * abs(math.cos(a))


def run(t):
    a = t * 2 * math.pi
    s = math.sin(a)
    swing = 58.0
    r = {"upperarm.L": [(X, 45 * s)], "upperarm.R": [(X, -45 * s)],
         "forearm.L": [(X, -75)], "forearm.R": [(X, -75)]}
    r["thigh.L"] = [(X, -swing * s - 8)]
    r["thigh.R"] = [(X, swing * s - 8)]
    r["shin.L"] = [(X, 70 * max(0.0, math.sin(a + 1.2)) + 10)]
    r["shin.R"] = [(X, 70 * max(0.0, math.sin(a + 1.2 + math.pi)) + 10)]
    r["foot.L"] = [(X, -15 * math.sin(a + 0.6))]
    r["foot.R"] = [(X, 15 * math.sin(a + 0.6))]
    r["hips"] = [(Z, 8 * s)]
    r["spine"] = [(X, 10)]
    r["chest"] = [(Z, -10 * s), (X, 4)]
    r["head"] = [(X, -10)]
    return r, 0.045 * abs(math.sin(a)) - 0.035


def jump(t):
    def ease(x):
        x = max(0.0, min(1.0, x))
        return x * x * (3 - 2 * x)
    crouch = ease(t / 0.25) * (1 - ease((t - 0.25) / 0.15))
    up = ease((t - 0.25) / 0.2)
    tuck = ease((t - 0.45) / 0.3)
    r = {
        "upperarm.L": [(X, 25 * crouch - 150 * up * (1 - 0.5 * tuck)), (Y, 25 * up)],
        "upperarm.R": [(X, 25 * crouch - 150 * up * (1 - 0.5 * tuck)), (Y, -25 * up)],
        "forearm.L": [(X, -20 - 20 * tuck)], "forearm.R": [(X, -20 - 20 * tuck)],
        "thigh.L": [(X, -50 * crouch - 45 * tuck)], "thigh.R": [(X, -50 * crouch - 35 * tuck)],
        "shin.L": [(X, 80 * crouch + 70 * tuck)], "shin.R": [(X, 80 * crouch + 60 * tuck)],
        "spine": [(X, 18 * crouch - 6 * up)],
        "head": [(X, -12 * up)],
    }
    return r, -0.14 * crouch


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    rig = build_rig()
    parts = [build_body("M", rig), build_body("F", rig)]
    for n in range(1, 5):
        parts.append(build_hair(n, rig))
        for key in ("M", "F"):
            parts.append(build_outfit(n, key, rig))
    cycle("Idle", 48, idle, rig)
    cycle("Walk", 20, walk, rig)
    cycle("Run", 14, run, rig)
    cycle("Jump", 24, jump, rig)
    for o in bpy.context.scene.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format="GLB", export_yup=True, export_skins=True,
        export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
        export_frame_range=False, export_def_bones=False, export_apply=False,
    )
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts}
    print("BUILT", OUT, "parts:", len(parts))
    for k in sorted(tris):
        print("  %-12s %5d tris" % (k, tris[k]))


main()
