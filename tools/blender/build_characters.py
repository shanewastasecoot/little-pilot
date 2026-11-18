"""Build Little Pilot's player characters in Blender, from code.

Run (from the project root):
    flatpak run org.blender.Blender -b --factory-startup \
        -P tools/blender/build_characters.py -- assets/characters/player/player.glb
or simply  ./dev.sh characters

Everything is generated: one armature ("Rig") shared by every part, two
bodies (Body_M, Body_F), four hair styles (Hair_1..4, one mesh fits both
heads) and four outfits, each made for both bodies from that body's own
measurements so nothing pokes through (Outfit_1_M .. Outfit_4_F). All parts
are skinned to the same bones with explicit weights (no automatic weight
painting), and four animations are keyframed on the rig: Idle, Walk, Run
(loops, in place) and Jump.

Units: metres, about 1.85 m tall, Blender Z-up facing -Y (glTF/Godot: Y-up
facing +Z). Flat colours, one material per colour. The game scales the
character to storybook size (~5 m) like the townspeople.
"""

import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "player.glb"
FPS = 24
RING = 12  # segments round limbs and bodies (low-poly, smooth-shaded)

SKIN = "f2c19e"
EYE = "2b2622"
MOUTH = "9e3b3b"
CHEEK = "f29a8a"

# --- Skeleton ----------------------------------------------------------------
# name: (head, tail, parent). Arms hang in a relaxed A-pose.
BONES = {
    "hips": ((0, 0, 0.80), (0, 0, 0.92), None),
    "spine": ((0, 0, 0.92), (0, 0, 1.10), "hips"),
    "chest": ((0, 0, 1.10), (0, 0, 1.28), "spine"),
    "neck": ((0, 0, 1.28), (0, 0, 1.36), "chest"),
    "head": ((0, 0, 1.36), (0, 0, 1.82), "neck"),
}
for side, s in (("L", 1), ("R", -1)):
    BONES["upperarm." + side] = ((0.18 * s, 0, 1.24), (0.30 * s, 0.01, 1.04), "chest")
    BONES["forearm." + side] = ((0.30 * s, 0.01, 1.04), (0.39 * s, 0, 0.85), "upperarm." + side)
    BONES["thigh." + side] = ((0.10 * s, 0, 0.84), (0.11 * s, 0, 0.47), "hips")
    BONES["shin." + side] = ((0.11 * s, 0, 0.47), (0.11 * s, 0.02, 0.10), "thigh." + side)
    BONES["foot." + side] = ((0.11 * s, 0.02, 0.10), (0.11 * s, -0.13, 0.03), "shin." + side)

# Body shapes. Torso: rings (z, half width, half depth) from hips to shoulders.
BODIES = {
    "M": {
        "torso": [(0.78, 0.155, 0.115), (0.88, 0.16, 0.12), (1.00, 0.15, 0.115), (1.12, 0.17, 0.12),
                  (1.22, 0.19, 0.12), (1.29, 0.16, 0.10), (1.32, 0.07, 0.06)],
        "arm": (0.058, 0.05, 0.045), "leg": (0.085, 0.066, 0.055), "hand": 0.058,
    },
    "F": {
        "torso": [(0.78, 0.17, 0.12), (0.88, 0.175, 0.125), (1.00, 0.135, 0.105), (1.12, 0.15, 0.115),
                  (1.21, 0.165, 0.115), (1.28, 0.14, 0.095), (1.32, 0.065, 0.055)],
        "arm": (0.05, 0.044, 0.04), "leg": (0.083, 0.062, 0.052), "hand": 0.052,
    },
}
HEAD_C = Vector((0, 0, 1.585))
HEAD_R = 0.235

# --- Helpers -------------------------------------------------------------------

_materials = {}


def mat(hexcol):
    if hexcol in _materials:
        return _materials[hexcol]
    m = bpy.data.materials.new("C_" + hexcol)
    c = tuple(int(hexcol[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    lin = tuple((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.75
    m.diffuse_color = (*lin, 1.0)
    _materials[hexcol] = m
    return m


class Part:
    """A mesh being built: vertices with bone weights, faces with colours."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.colours = []  # material index per face, by colour
        self.palette = []

    def colour(self, hexcol):
        if hexcol not in self.palette:
            self.palette.append(hexcol)
        return self.palette.index(hexcol)

    def vert(self, co, weights):
        v = self.bm.verts.new(co)
        v[self.deform]  # create
        self._pending = getattr(self, "_pending", [])
        self._pending.append((v, weights))
        return v

    def face(self, verts, hexcol):
        f = self.bm.faces.new(verts)
        f.material_index = self.colour(hexcol)
        return f

    def build(self, rig):
        names = list(BONES.keys())
        mesh = bpy.data.meshes.new(self.name)
        self.bm.verts.index_update()
        self.bm.to_mesh(mesh)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        for h in self.palette:
            mesh.materials.append(mat(h))
        groups = {n: obj.vertex_groups.new(name=n) for n in names}
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
    """Two unit vectors perpendicular to direction d (x: sideways, y: depth)."""
    d = d.normalized()
    ref = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
    x = ref.cross(d).normalized()
    y = d.cross(x).normalized()
    return x, y


def loft(part, rings, hexcol, cap_start=True, cap_end=True, segs=RING, colours=None):
    """rings: list of (centre, direction, half_width, half_depth, weights).
    colours: optional per-band colour list (len(rings) - 1)."""
    loops = []
    for c, d, rx, ry, w in rings:
        x, y = frame_for(d)
        loop = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            loop.append(part.vert(c + x * math.cos(a) * rx + y * math.sin(a) * ry, w))
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


def ellipsoid(part, centre, radii, hexcol, weights, segs=RING, rings=8, z_from=-1.0, z_to=1.0):
    """A (part of an) ellipsoid: z_from/z_to cut it (-1..1 of its height)."""
    loops = []
    zs = [z_from + (z_to - z_from) * k / rings for k in range(rings + 1)]
    for z in zs:
        r = math.sqrt(max(0.0, 1.0 - z * z))
        loop = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            co = centre + Vector((math.cos(a) * r * radii[0], math.sin(a) * r * radii[1], z * radii[2]))
            loop.append(part.vert(co, weights(co) if callable(weights) else weights))
        loops.append(loop)
    for k in range(rings):
        a, b = loops[k], loops[k + 1]
        for i in range(segs):
            j = (i + 1) % segs
            if zs[k] <= -0.999:
                part.face([a[i], b[j], b[i]], hexcol) if False else part.face([a[i], a[j], b[j], b[i]], hexcol)
            else:
                part.face([a[i], a[j], b[j], b[i]], hexcol)
    # caps for cut ends
    if z_from > -0.999:
        mid = part.vert(centre + Vector((0, 0, z_from * radii[2])), weights(centre) if callable(weights) else weights)
        for i in range(segs):
            part.face([loops[0][(i + 1) % segs], loops[0][i], mid], hexcol)
    if z_to < 0.999:
        mid = part.vert(centre + Vector((0, 0, z_to * radii[2])), weights(centre) if callable(weights) else weights)
        for i in range(segs):
            part.face([loops[-1][i], loops[-1][(i + 1) % segs], mid], hexcol)


def blend(a, b, t):
    """Weights for a vertex between bone a and bone b (t = 0..1)."""
    t = max(0.0, min(1.0, t))
    return {a: 1.0 - t, b: t}


def limb(part, side, kind, body, hexcol, t0=0.0, t1=1.0, grow=0.0, cap_start=True, cap_end=True, colours=None, tuck=0.0):
    """Arm or leg as a lofted tube along its two bones, from t0 to t1
    (0 = shoulder/hip, 0.5 = elbow/knee, 1 = wrist/ankle). `grow` thickens it
    (clothes)."""
    if kind == "arm":
        b1, b2, radii = "upperarm." + side, "forearm." + side, body["arm"]
    else:
        b1, b2, radii = "thigh." + side, "shin." + side, body["leg"]
    p0, p1 = Vector(BONES[b1][0]), Vector(BONES[b1][1])
    p2 = Vector(BONES[b2][1])
    # tuck: start this far (m) back inside the body, towards its middle.
    if tuck > 0.0:
        inward = Vector((-p0.x, 0.0, 0.0)).normalized() if abs(p0.x) > 1e-4 else Vector()
        p0 = p0 + inward * tuck + (p0 - p1).normalized() * tuck * 0.5
    rings = []
    steps = 6
    for k in range(steps + 1):
        t = t0 + (t1 - t0) * k / steps
        if t <= 0.5:
            u = t / 0.5
            c = p0.lerp(p1, u)
            d = p1 - p0
            r = radii[0] + (radii[1] - radii[0]) * u
        else:
            u = (t - 0.5) / 0.5
            c = p1.lerp(p2, u)
            d = p2 - p1
            r = radii[1] + (radii[2] - radii[1]) * u
        # Around the joint (t ~ 0.5), blend the two bones.
        w = blend(b1, b2, (t - 0.42) / 0.16)
        # Top of the limb blends into the body.
        if kind == "arm" and t < 0.12:
            w = {b1: 0.5 + t / 0.24, "chest": 0.5 - t / 0.24}
        if kind == "leg" and t < 0.1:
            w = {b1: 0.6 + t * 4.0, "hips": 0.4 - t * 4.0}
        rings.append((c, d, r + grow, r * 0.95 + grow, w))
    loft(part, rings, hexcol, cap_start, cap_end, colours=colours)


def torso_weights(z):
    if z < 0.92:
        return blend("hips", "spine", (z - 0.86) / 0.12)
    if z < 1.10:
        return blend("spine", "chest", (z - 1.04) / 0.12)
    return blend("chest", "neck", (z - 1.30) / 0.04)


def torso(part, body, hexcol, z0, z1, grow=0.0, cap_start=True, cap_end=True, flare=None):
    """The torso between heights z0 and z1 (interpolated from the body's
    rings), `grow` m bigger all round. flare(z) adds width (skirts, hems)."""
    src = body["torso"]
    rings = []
    zs = sorted(set([z0, z1] + [r[0] for r in src if z0 < r[0] < z1]))
    for z in zs:
        for k in range(len(src) - 1):
            if src[k][0] <= z <= src[k + 1][0]:
                u = (z - src[k][0]) / (src[k + 1][0] - src[k][0])
                rx = src[k][1] + (src[k + 1][1] - src[k][1]) * u
                ry = src[k][2] + (src[k + 1][2] - src[k][2]) * u
                break
        else:
            rx, ry = (src[0][1], src[0][2]) if z < src[0][0] else (src[-1][1], src[-1][2])
        f = flare(z) if flare else 0.0
        rings.append((Vector((0, 0, z)), Vector((0, 0, 1)), rx + grow + f, ry + grow + f * 0.8, torso_weights(z)))
    loft(part, rings, hexcol, cap_start, cap_end)


def foot(part, side, hexcol, grow=0.0, height=0.09):
    s = 1 if side == "L" else -1
    w = {"foot." + side: 0.85, "shin." + side: 0.15}
    ellipsoid(part, Vector((0.11 * s, -0.04, 0.045)), (0.065 + grow, 0.12 + grow, height * 0.5 + grow), hexcol, w,
              rings=6, z_from=-0.6)


def hand(part, side, body, hexcol):
    s = 1 if side == "L" else -1
    c = Vector(BONES["forearm." + side][1]) + Vector((0.02 * s, 0, -0.04))
    r = body["hand"]
    ellipsoid(part, c, (r * 0.9, r * 0.75, r * 1.15), hexcol, {"forearm." + side: 1.0}, segs=10, rings=6)


def head_weights(co):
    return {"head": 1.0} if co.z > 1.40 else blend("neck", "head", (co.z - 1.30) / 0.10)


# --- Bodies ------------------------------------------------------------------


def build_body(key, rig):
    body = BODIES[key]
    p = Part("Body_" + key)
    torso(p, body, SKIN, 0.76, 1.32)
    # Neck
    loft(p, [(Vector((0, 0, 1.28)), Vector((0, 0, 1)), 0.06, 0.055, {"chest": 0.5, "neck": 0.5}),
             (Vector((0, 0, 1.40)), Vector((0, 0, 1)), 0.06, 0.055, {"neck": 0.6, "head": 0.4})], SKIN)
    # Head: a big round friendly head, eyes, little nose, smile, cheeks, ears.
    ellipsoid(p, HEAD_C, (HEAD_R, HEAD_R * 0.95, HEAD_R * 1.02), SKIN, head_weights, segs=16, rings=10)
    for s in (1, -1):
        ellipsoid(p, HEAD_C + Vector((0.08 * s, -0.205, 0.015)), (0.034, 0.02, 0.046), EYE, {"head": 1.0}, segs=10, rings=5)
        ellipsoid(p, HEAD_C + Vector((0.094 * s, -0.222, 0.033)), (0.011, 0.006, 0.011), "ffffff", {"head": 1.0}, segs=8, rings=3)
        ellipsoid(p, HEAD_C + Vector((0.135 * s, -0.17, -0.055)), (0.035, 0.012, 0.022), CHEEK, {"head": 1.0}, segs=8, rings=3)
        ellipsoid(p, HEAD_C + Vector((0.232 * s, 0.0, 0.0)), (0.03, 0.045, 0.055), SKIN, {"head": 1.0}, segs=8, rings=4)
        if key == "F":
            # Eyelashes: two little flicks above each eye.
            ellipsoid(p, HEAD_C + Vector((0.112 * s, -0.198, 0.06)), (0.018, 0.008, 0.007), EYE, {"head": 1.0}, segs=6, rings=3)
    ellipsoid(p, HEAD_C + Vector((0, -0.232, -0.025)), (0.022, 0.02, 0.018), SKIN, {"head": 1.0}, segs=8, rings=4)
    # Smile: an arc of little beads, corners turned up.
    for k in range(7):
        a = (k - 3) / 3.0
        x = a * 0.05
        z = -0.105 + 0.022 * a * a
        y = -math.sqrt(max(0.0, HEAD_R ** 2 - x * x - z * z)) + 0.004
        ellipsoid(p, HEAD_C + Vector((x, y, z)), (0.011, 0.008, 0.009), MOUTH, {"head": 1.0}, segs=6, rings=3)
    for side in ("L", "R"):
        limb(p, side, "arm", body, SKIN)
        hand(p, side, body, SKIN)
        limb(p, side, "leg", body, SKIN)
        foot(p, side, SKIN, height=0.08)
    return p.build(rig)


# --- Hair (one mesh fits both heads) ------------------------------------------


def hair_cap(p, hexcol, low=0.05, fringe=0.0, grow=0.018):
    """Hair covering the top/back of the head down to `low` (0..1 of radius
    below the centre), with an optional fringe at the front."""
    r = HEAD_R + grow
    segs, rings = 16, 8
    loops = []
    zs = [1.0 - (1.0 + low) * k / rings for k in range(rings + 1)]
    for z in zs:
        rr = math.sqrt(max(0.0, 1.0 - z * z))
        loop = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            x, y = math.cos(a) * rr, math.sin(a) * rr
            # The face stays clear: pull the front up to the fringe line.
            zz = z
            if y < -0.35 and z < 0.55 - fringe:
                zz = max(z, 0.55 - fringe - 0.25 * (1 - abs(x)))
                rr2 = math.sqrt(max(0.0, 1.0 - zz * zz))
                x, y = math.cos(a) * rr2, math.sin(a) * rr2
            co = HEAD_C + Vector((x * r, y * r * 0.97, zz * r * 1.04))
            loop.append(p.vert(co, {"head": 1.0}))
        loops.append(loop)
    top = p.vert(HEAD_C + Vector((0, 0, r * 1.04)), {"head": 1.0})
    for i in range(segs):
        p.face([loops[0][i], loops[0][(i + 1) % segs], top], hexcol)
    for k in range(rings):
        a, b = loops[k], loops[k + 1]
        for i in range(segs):
            j = (i + 1) % segs
            p.face([a[j], a[i], b[i], b[j]], hexcol)


def build_hair(n, rig):
    p = Part("Hair_%d" % n)
    if n == 1:  # short and tousled, brown
        col = "6b4226"
        hair_cap(p, col, low=0.1, fringe=0.12)
        for k in range(7):
            a = -0.9 + k * 0.3
            c = HEAD_C + Vector((math.sin(a) * 0.14, -0.13 + abs(a) * 0.04, 0.2 + math.cos(a) * 0.03))
            ellipsoid(p, c, (0.06, 0.05, 0.045), col, {"head": 1.0}, segs=8, rings=4)
    elif n == 2:  # long bob down to the chin, black, with a fringe
        col = "2a2522"
        hair_cap(p, col, low=0.62, fringe=0.2, grow=0.026)
        ellipsoid(p, HEAD_C + Vector((0, -0.12, 0.15)), (0.2, 0.09, 0.07), col, {"head": 1.0}, segs=12, rings=4)
    elif n == 3:  # ponytail with a red tie, blonde
        col = "e8c35a"
        hair_cap(p, col, low=0.3, fringe=0.08)
        tie = HEAD_C + Vector((0, 0.22, 0.12))
        ellipsoid(p, tie, (0.045, 0.04, 0.045), "e63946", {"head": 1.0}, segs=8, rings=4)
        for k, (dy, dz, r) in enumerate([(0.29, 0.06, 0.07), (0.33, -0.04, 0.075), (0.34, -0.14, 0.065), (0.32, -0.22, 0.045)]):
            ellipsoid(p, HEAD_C + Vector((0, dy, dz)), (r, r * 0.9, r * 1.3), col, {"head": 1.0}, segs=10, rings=5)
    else:  # two big curly puffs, dark brown
        col = "3b2418"
        hair_cap(p, col, low=0.2, fringe=0.1, grow=0.03)
        for s in (1, -1):
            c = HEAD_C + Vector((0.17 * s, 0.03, 0.17))
            ellipsoid(p, c, (0.12, 0.12, 0.11), col, {"head": 1.0}, segs=12, rings=6)
            for k in range(5):
                a = k * 1.25
                ellipsoid(p, c + Vector((math.cos(a) * 0.09, math.sin(a) * 0.09, 0.05 * math.sin(a * 2))),
                          (0.055, 0.055, 0.05), col, {"head": 1.0}, segs=8, rings=4)
    return p.build(rig)


# --- Outfits (built for each body from its measurements) ------------------------


def build_outfit(n, key, rig):
    body = BODIES[key]
    p = Part("Outfit_%d_%s" % (n, key))
    g = 0.014  # clothes stand this far off the skin
    if n == 1:  # T-shirt, shorts, trainers
        shirt, shorts, shoe = "ff5a5f", "2f6fdb", "f4f4f4"
        torso(p, body, shirt, 0.86, 1.32, g, cap_start=True, cap_end=True)
        torso(p, body, shorts, 0.74, 0.90, g + 0.008, cap_end=False)
        for side in ("L", "R"):
            limb(p, side, "arm", body, shirt, 0.0, 0.32, g + 0.012, cap_start=False, tuck=0.06)
            limb(p, side, "leg", body, shorts, 0.0, 0.33, g + 0.01, cap_start=False, tuck=0.03)
            foot(p, side, shoe, grow=0.012, height=0.1)
    elif n == 2:  # hoodie with a hood and pocket, jeans, trainers
        hoodie, jeans, shoe = "4cc06a", "3b5b8c", "333a44"
        torso(p, body, hoodie, 0.80, 1.32, g + 0.01, cap_end=True)
        ellipsoid(p, Vector((0, 0.1, 1.33)), (0.15, 0.08, 0.07), hoodie, {"chest": 0.6, "neck": 0.4}, segs=12, rings=5)
        ellipsoid(p, Vector((0, -body["torso"][1][2] - 0.022, 0.92)), (0.1, 0.012, 0.05), "3fa95b", {"spine": 0.6, "hips": 0.4}, segs=10, rings=4)
        torso(p, body, jeans, 0.74, 0.86, g, cap_end=False)
        for side in ("L", "R"):
            limb(p, side, "arm", body, hoodie, 0.0, 0.92, g + 0.014, cap_start=False, tuck=0.06)
            limb(p, side, "leg", body, jeans, 0.0, 0.93, g + 0.008, cap_start=False, tuck=0.03)
            foot(p, side, shoe, grow=0.012, height=0.1)
    elif n == 3:  # pilot: leather jacket, white scarf, khaki trousers, boots
        jacket, scarf, trousers, boot = "8b5a2b", "f8f8f2", "c9b27c", "4a3324"
        torso(p, body, jacket, 0.80, 1.32, g + 0.012, cap_end=True)
        loft(p, [(Vector((0, 0, 1.26)), Vector((0, 0, 1)), 0.1, 0.09, {"chest": 0.5, "neck": 0.5}),
                 (Vector((0, 0, 1.36)), Vector((0, 0, 1)), 0.085, 0.08, {"neck": 1.0})], scarf, cap_start=False, cap_end=False)
        ellipsoid(p, Vector((0.05, -0.1, 1.2)), (0.035, 0.02, 0.09), scarf, {"chest": 1.0}, segs=8, rings=4)
        torso(p, body, trousers, 0.74, 0.86, g, cap_end=False)
        for side in ("L", "R"):
            limb(p, side, "arm", body, jacket, 0.0, 0.9, g + 0.016, cap_start=False, tuck=0.06)
            limb(p, side, "leg", body, trousers, 0.0, 0.8, g + 0.01, cap_start=False, tuck=0.03)
            limb(p, side, "leg", body, boot, 0.78, 1.0, g + 0.02)
            foot(p, side, boot, grow=0.016, height=0.11)
    else:  # dungarees over a stripy top, yellow wellies
        top_a, top_b, dung, boot = "ffffff", "4aa8ff", "f2b134", "ffd23f"
        bands = [top_a if k % 2 == 0 else top_b for k in range(6)]
        torso(p, body, top_a, 0.95, 1.32, g, cap_end=True)
        # Bib and straps over the stripes.
        torso(p, body, dung, 0.74, 1.12, g + 0.012, cap_end=False)
        front = body["torso"][3][2] + g + 0.016
        ellipsoid(p, Vector((0, -front, 1.16)), (0.11, 0.022, 0.075), dung, {"chest": 0.7, "spine": 0.3}, segs=10, rings=4)
        for sx in (1, -1):  # two buttons
            ellipsoid(p, Vector((0.07 * sx, -front - 0.016, 1.2)), (0.014, 0.008, 0.014), "5b4636", {"chest": 1.0}, segs=6, rings=3)
        for side in ("L", "R"):
            limb(p, side, "arm", body, top_a, 0.0, 0.85, g + 0.01, cap_start=False, colours=bands, tuck=0.06)
            limb(p, side, "leg", body, dung, 0.0, 0.85, g + 0.014, cap_start=False, tuck=0.03)
            limb(p, side, "leg", body, boot, 0.82, 1.0, g + 0.024)
            foot(p, side, boot, grow=0.02, height=0.11)
    return p.build(rig)


# --- Rig -----------------------------------------------------------------------


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


# --- Animation -------------------------------------------------------------------
# Rotations are given round armature axes (X = sideways: + tips a downward
# limb backwards and an upward one forwards; Y = front/back; Z = up) and
# converted to each bone's own frame, so the keys read naturally.

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def local_rot(rig, bone, axis, deg):
    rest = rig.data.bones[bone].matrix_local.to_3x3()
    q = Quaternion(axis, math.radians(deg))
    return (rest.inverted() @ q.to_matrix() @ rest).to_quaternion()


def pose(rig, frame, rots, hips_z=0.0, hips_y=0.0):
    """rots: {bone: [(axis, degrees), ...]} for this frame; others rest."""
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        q = Quaternion()
        for axis, deg in rots.get(pb.name, []):
            q = local_rot(rig, pb.name, axis, deg) @ q
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "hips":
            pb.location = rig.data.bones["hips"].matrix_local.to_3x3().inverted() @ Vector((0, hips_y, hips_z))
            pb.keyframe_insert("location", frame=frame)


def cycle(name, frames, fn, rig, loop=True):
    act = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = act
    for f in range(frames + 1):
        t = f / frames
        rots, hz, hy = fn(t)
        pose(rig, f, rots, hz, hy)
    act.use_fake_user = True
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    rig.animation_data.action = None


def arms_down(extra_l=0.0, extra_r=0.0, bend=10.0):
    # Relaxed arms: elbows a little bent; extra = swing forward (-) / back (+).
    return {
        "upperarm.L": [(X, extra_l)], "upperarm.R": [(X, extra_r)],
        "forearm.L": [(X, -bend)], "forearm.R": [(X, -bend)],
    }


def idle(t):
    s = math.sin(t * 2 * math.pi)
    r = arms_down(2 * s, 2 * s, 8 + 2 * s)
    r["chest"] = [(X, 1.5 * s)]
    r["head"] = [(Y, 2.5 * math.sin(t * 2 * math.pi + 1.0)), (X, -1.0 * s)]
    return r, 0.006 * s - 0.006, 0.0


def walk(t):
    a = t * 2 * math.pi
    s = math.sin(a)
    swing = 30.0
    r = arms_down(swing * 0.7 * s, -swing * 0.7 * s, 14)
    r["thigh.L"] = [(X, -swing * s)]
    r["thigh.R"] = [(X, swing * s)]
    # Knee bends as the leg swings through (back half of the swing).
    r["shin.L"] = [(X, 35 * max(0.0, math.sin(a + 1.4)) + 5)]
    r["shin.R"] = [(X, 35 * max(0.0, math.sin(a + 1.4 + math.pi)) + 5)]
    r["foot.L"] = [(X, -10 * math.sin(a + 0.6))]
    r["foot.R"] = [(X, 10 * math.sin(a + 0.6))]
    r["hips"] = [(Z, 6 * s)]
    r["chest"] = [(Z, -8 * s), (X, 3)]
    r["head"] = [(Z, 3 * s)]
    bob = -0.025 * abs(math.cos(a))
    return r, bob, 0.0


def run(t):
    a = t * 2 * math.pi
    s = math.sin(a)
    swing = 48.0
    r = {
        "upperarm.L": [(X, 45 * s)], "upperarm.R": [(X, -45 * s)],
        "forearm.L": [(X, -75)], "forearm.R": [(X, -75)],
    }
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
    bob = 0.05 * abs(math.sin(a)) - 0.04
    return r, bob, 0.0


def jump(t):
    # 0..0.25 crouch, 0.25..0.45 push up (arms up), 0.45..1 tuck in the air.
    def ease(x):
        x = max(0.0, min(1.0, x))
        return x * x * (3 - 2 * x)
    crouch = ease(t / 0.25) * (1 - ease((t - 0.25) / 0.15))
    up = ease((t - 0.25) / 0.2)
    tuck = ease((t - 0.45) / 0.3)
    r = {
        "upperarm.L": [(X, -20 * crouch * 0 + 25 * crouch - 150 * up * (1 - 0.5 * tuck)), (Y, 25 * up)],
        "upperarm.R": [(X, 25 * crouch - 150 * up * (1 - 0.5 * tuck)), (Y, -25 * up)],
        "forearm.L": [(X, -20 - 20 * tuck)], "forearm.R": [(X, -20 - 20 * tuck)],
        "thigh.L": [(X, -50 * crouch - 45 * tuck)], "thigh.R": [(X, -50 * crouch - 35 * tuck)],
        "shin.L": [(X, 80 * crouch + 70 * tuck)], "shin.R": [(X, 80 * crouch + 60 * tuck)],
        "spine": [(X, 18 * crouch - 6 * up)],
        "head": [(X, -12 * up)],
    }
    return r, -0.2 * crouch, 0.0


# --- Build and export ----------------------------------------------------------------


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
    cycle("Walk", 22, walk, rig)
    cycle("Run", 14, run, rig)
    cycle("Jump", 24, jump, rig, loop=False)
    for o in bpy.context.scene.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        export_yup=True,
        export_skins=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_force_sampling=True,
        export_frame_range=False,
        export_def_bones=False,
        export_apply=False,
    )
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts}
    print("BUILT", OUT, "parts:", len(parts))
    for k in sorted(tris):
        print("  %-12s %5d tris" % (k, tris[k]))


main()
