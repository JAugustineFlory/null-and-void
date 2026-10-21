"""Builds the crew's character models with Blender (bpy), from the Quaternius
Universal Base Characters (CC0, see docs/art/CREDITS.md).

    pip install bpy==5.0.1   # Python 3.11
    python -I tools/art/build_characters.py -- assets/art/characters [PACK_DIR]

PACK_DIR is the unzipped "Universal Base Characters[Standard]" folder (the
project keeps it in art/packs/quaternius/). Writes body1.glb (the male base)
and body2.glb (the female base). Each holds the pack's 65-bone skeleton, the
body, and every garment a look can ask for as its own mesh (Jacket_open,
Hair_long, Head_cap, ...). SkinnedBody shows the ones a look wears, tints them
and poses the bones from CharacterRig.

What happens to the pack's model:
- The textures go. Skin, shirt, trousers and shoes are painted by
  body.gdshader from two numbers per vertex, kept in the UV map: the height on
  the body in CharacterRig's units (so the shader's hem, waist and neckline
  are the same for both bodies) and how far down the arm it is (0 at the
  shoulder, 1 at the fingertips; shirt sleeves end there).
- Face detail from the texture is baked into the vertex colour: red darkens
  the skin, green marks the lips. The eyes are joined to the body with their
  colours baked in (alpha 0 marks them).
- Muscles are smoothed away where clothes cover them, and the feet are
  rounded into shoes, so nobody looks like they're in a bodysuit.
- Jackets, collars, badges, lanyards and radios are fitted to the body here.
  Hair comes from the pack's hairstyles, fitted to each head. Hats and glasses
  are placed from the head and the eyes.

Blender space after loading: the pack faces -Y, so the armature turns 180
degrees about Z and everything here is built facing +Y with the character's
right at +X. glTF export turns that into Godot's -Z forward, like CharacterRig.
The turn is on the armature object, not the bones, so the pack's animation
clips (UAL) still play on the skeleton.
"""

import math
import os
import sys

import bpy
import bmesh  # after bpy: the wheel only exposes bmesh once bpy has loaded
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/art/characters"
PACK = ARGS[1] if len(ARGS) > 1 else "/mnt/project-files/art/packs/quaternius/Universal Base Characters[Standard]"
BASE = os.path.join(PACK, "Base Characters", "Godot - UE")
HAIR = os.path.join(PACK, "Hairstyles", "Rigged to Head Bone", "glTF (Godot -Unreal)")
KINDS = {1: "Male", 2: "Female"}
# Which base body each hairstyle was modelled on (they're placed for that head).
HAIR_NATIVE = {"Hair_SimpleParted": 1, "Hair_Buzzed": 1, "Hair_Beard": 1, "Hair_Long": 2, "Hair_BuzzedFemale": 2}

# CharacterRig's heights (its joints at height 1.0), for the paint fields.
RIG_ANKLE, RIG_KNEE, RIG_HIP, RIG_SPINE, RIG_NECK, RIG_HEAD = 0.085, 0.44, 0.87, 0.98, 1.47, 1.54
BODY_RATIO = 0.45  # how much of the body's mesh (all but the head) to keep
ARM_TORSO_Z = 1.3  # arms count as chest height, so a sleeve meets its shirt
ARM_PREFIXES = ("upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky")


# --- Mesh helpers --------------------------------------------------------------

def new_object(name, me):
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def mesh_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return new_object(name, me)


def apply_modifiers(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def blob(name, center, radii, segments=14, rings=9):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + Vector(center)
    return mesh_object(name, bm)


def box(name, center, size, bevel=0.0, frame=None):
    """A box; `frame` (columns right, out, up) turns it to lie on a surface."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        local = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        v.co = (frame @ local if frame else local) + Vector(center)
    ob = mesh_object(name, bm)
    if bevel:
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        apply_modifiers(ob)
    return ob


def cylinder(name, center, radius, depth, verts=12, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=radius, depth=depth)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(center)
    return mesh_object(name, bm)


def join(name, obs):
    obs = [o for o in obs if o]
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def shade(ob, value, alpha=1.0):
    """Vertex colour: 1 takes the tint as is, lower darkens it (seams, brims)."""
    me = ob.data
    if "shade" not in me.color_attributes:
        me.color_attributes.new("shade", "FLOAT_COLOR", "POINT")
    attr = me.color_attributes["shade"]
    for i in range(len(me.vertices)):
        attr.data[i].color = (value, value, value, alpha)
    me.color_attributes.active_color = attr
    me.color_attributes.default_color_name = "shade"
    return ob


def shade_where(ob, test, value):
    attr = ob.data.color_attributes["shade"]
    for i, v in enumerate(ob.data.vertices):
        if test(v.co):
            attr.data[i].color = (value, value, value, 1.0)


def smooth_shading(ob):
    for p in ob.data.polygons:
        p.use_smooth = True


def delete_faces(ob, drop):
    """Deletes the faces whose centre passes `drop`, and any loose vertices."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if drop(f.calc_center_median())], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def lerp_table(x, table):
    """Piecewise-linear lookup in [(x, y)], extended past both ends."""
    if x <= table[0][0]:
        (a, fa), (b, fb) = table[0], table[1]
    elif x >= table[-1][0]:
        (a, fa), (b, fb) = table[-2], table[-1]
    else:
        for (a, fa), (b, fb) in zip(table, table[1:]):
            if x <= b:
                break
    return fa + (x - a) / (b - a) * (fb - fa)


def luminance(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def baked_colors(ob, texture):
    """Each vertex's colour from `texture` (a file), averaged over its corners."""
    img = bpy.data.images.load(texture, check_existing=True)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    uv = ob.data.uv_layers[0].data
    sums = np.zeros((len(ob.data.vertices), 4))
    for loop in ob.data.loops:
        u, v = uv[loop.index].uv
        c = px[int((v % 1.0) * h) % h, int((u % 1.0) * w) % w]
        s = sums[loop.vertex_index]
        s[:3] += c[:3]
        s[3] += 1
    return [tuple(s[:3] / max(1, s[3])) for s in sums]


def set_colors(ob, colors):
    me = ob.data
    while len(me.color_attributes):  # one at a time: removing one invalidates the others' handles
        me.color_attributes.remove(me.color_attributes[0])
    attr = me.color_attributes.new("shade", "FLOAT_COLOR", "POINT")
    for i, c in enumerate(colors):
        attr.data[i].color = c
    me.color_attributes.active_color = attr
    me.color_attributes.default_color_name = "shade"  # the one the exporter writes


def strip_uvs(ob):
    while len(ob.data.uv_layers):
        ob.data.uv_layers.remove(ob.data.uv_layers[0])


def set_fields(ob, fields):
    """Writes per-vertex (height, arm) paint fields into the only UV map."""
    strip_uvs(ob)
    uv = ob.data.uv_layers.new(name="UVMap")
    for loop in ob.data.loops:
        uv.data[loop.index].uv = fields[loop.vertex_index]


def world_mesh(ob, name):
    """A plain copy of `ob`'s mesh in world space (no skin, no modifiers)."""
    me = ob.data.copy()
    me.transform(ob.matrix_world)
    return new_object(name, me)


# --- Lofts and fitting -----------------------------------------------------------

def radial_profile(points, n):
    """For n directions round a centre, how far out the points reach.
    `points` are 2D (a, b) round the centre; direction 0 is along +b."""
    r = [None] * n
    for a, b in points:
        k = int(round((math.atan2(a, b) / (2 * math.pi)) * n)) % n
        d = math.hypot(a, b)
        if r[k] is None or d > r[k]:
            r[k] = d
    known = [i for i in range(n) if r[i] is not None]
    if not known:
        return [0.05] * n
    for i in range(n):
        if r[i] is None:  # bridge a gap (between the legs) from the nearest known sides
            lo = max((k for k in known if k < i), default=known[-1] - n)
            hi = min((k for k in known if k > i), default=known[0] + n)
            t = (i - lo) / (hi - lo)
            r[i] = r[lo % n] * (1 - t) + r[hi % n] * t
    for _ in range(2):  # round off, never inward
        r = [max(r[i], (r[i - 1] + r[i] + r[(i + 1) % n]) / 3) for i in range(n)]
    return r


def loft(name, loops, gap=None):
    """Joins rings of points (each the same count, bottom to top) into a tube.
    `gap(mid)` True leaves that face out (an open jacket front)."""
    bm = bmesh.new()
    vl = [[bm.verts.new(p) for p in loop] for loop in loops]
    n = len(loops[0])
    for lo, hi in zip(vl, vl[1:]):
        for i in range(n):
            j = (i + 1) % n
            mid = (lo[i].co + lo[j].co + hi[i].co + hi[j].co) / 4
            if gap and gap(mid):
                continue
            bm.faces.new((lo[i], hi[i], hi[j], lo[j]))
    return mesh_object(name, bm)


def face_outward(ob, axis_point):
    """Turns every face to point away from `axis_point(face centre)`."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        if f.normal.dot(c - axis_point(c)) < 0:
            f.normal_flip()
    bm.to_mesh(ob.data)
    bm.free()


# --- The body ------------------------------------------------------------------------

def texture_of(ob):
    for node in ob.data.materials[0].node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image and "Normal" not in node.image.name and "Rough" not in node.image.name:
            return bpy.path.abspath(node.image.filepath)
    raise RuntimeError("no base colour texture on " + ob.name)


def is_arm(w):
    return sum(v for k, v in w.items() if k.startswith(ARM_PREFIXES))


def weights_of(ob):
    names = {g.index: g.name for g in ob.vertex_groups}
    return [{names[g.group]: g.weight for g in v.groups if g.weight > 0.0} for v in ob.data.vertices]


class Body:
    """The base model loaded and measured, in the turned (+Y forward) space."""

    def __init__(self, kind):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(BASE, "Superhero_%s_FullBody.gltf" % KINDS[kind]))
        self.kind = kind
        for o in list(bpy.data.objects):
            if o.name.startswith("Icosphere"):
                bpy.data.objects.remove(o)
        self.arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
        self.arm.name = "Armature"
        self.arm.rotation_mode = "XYZ"
        self.arm.rotation_euler = (0, 0, math.pi)
        bpy.context.view_layer.update()
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
        self.mesh = [o for o in meshes if o.name.lower().startswith("superhero")][0]
        self.eyes = [o for o in meshes if o.name.startswith("Eyes")][0]
        self.brows = [o for o in meshes if o.name.startswith("Eyebrows")][0]
        self.texture = texture_of(self.mesh)
        thin_body(self.mesh)
        mw = self.arm.matrix_world
        self.bone = {b.name: mw @ b.head_local for b in self.arm.data.bones}
        # The pack's joint heights next to the rig's, for the paint fields.
        self.heights = [
            (0.0, 0.0), (self.bone["foot_r"].z, RIG_ANKLE), (self.bone["calf_r"].z, RIG_KNEE),
            (self.bone["thigh_r"].z, RIG_HIP), (self.bone["spine_01"].z, RIG_SPINE),
            (self.bone["neck_01"].z, RIG_NECK), (self.bone["Head"].z, RIG_HEAD),
        ]
        sx = self.bone["upperarm_r"].x
        ex = self.bone["lowerarm_r"].x
        wx = self.bone["hand_r"].x
        self.shoulder_x, self.wrist_x = sx, wx
        self.arm_table = [(sx - 0.05, 0.0), (sx, 0.05), (ex, 0.41), (wx, 0.845), (wx + 0.03, 0.9), (wx + 0.22, 1.0)]
        self.ws = weights_of(self.mesh)
        self.measure_head()

    def rig_height(self, z):
        return lerp_table(z, self.heights)

    def pack_height(self, h):
        """The inverse: where a rig height falls on this body."""
        return lerp_table(h, [(b, a) for a, b in self.heights])

    def measure_head(self):
        mw = self.mesh.matrix_world
        pts = [mw @ v.co for v, w in zip(self.mesh.data.vertices, self.ws) if w.get("Head", 0.0) > 0.5]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        self.head_c = (lo + hi) / 2
        self.head_r = (hi - lo) / 2
        self.chin = lo.z
        ew = self.eyes.matrix_world
        eyes = [ew @ v.co for v in self.eyes.data.vertices]
        right = [p for p in eyes if p.x > 0]
        self.eye_c = sum(right, Vector()) / len(right)  # the right eye's centre
        self.eye_front = max(p.y for p in eyes)


def paint_fields(body, ob):
    """(height, arm) per vertex: see the module docstring."""
    mw = ob.matrix_world
    neck_top = body.bone["neck_01"].z + 0.03
    out = []
    for v, w in zip(ob.data.vertices, body.ws):
        p = mw @ v.co
        if is_arm(w) > 0.5 and abs(p.x) > body.shoulder_x - 0.06:
            out.append((ARM_TORSO_Z, max(0.02, lerp_table(abs(p.x), body.arm_table))))
            continue
        h = body.rig_height(p.z)
        if p.z < neck_top and abs(p.x) > 0.075:
            h = min(h, 1.43)  # the shoulders stay under the shirt; only the neck rises past its neckline
        out.append((h, 0.0))
    return out


def taubin(bm, verts, rounds, lam=0.5, mu=-0.53):
    """Smooths `verts` without shrinking them (Taubin: a step in, a step back out).
    Vertices sharing a position (UV seams) move together, so seams don't open."""
    key = lambda co: (round(co.x, 5), round(co.y, 5), round(co.z, 5))
    group = {}
    for v in bm.verts:
        group.setdefault(key(v.co), []).append(v)
    moving = {key(v.co) for v in verts}
    links = {k: set() for k in moving}
    for k in moving:
        for v in group[k]:
            for e in v.link_edges:
                links[k].add(key(e.other_vert(v).co))
    pos = {k: group[k][0].co.copy() for k in group}
    for _ in range(rounds):
        for f in (lam, mu):
            new = {}
            for k in moving:
                if links[k]:
                    avg = sum((pos[n] for n in links[k]), Vector()) / len(links[k])
                    new[k] = pos[k] + (avg - pos[k]) * f
            pos.update(new)
    for k in moving:
        for v in group[k]:
            v.co = pos[k].copy()


def smooth_under_clothes(body):
    """Evens out the muscles where clothes cover them, and rounds the feet into shoes."""
    ob = body.mesh
    mw = ob.matrix_world
    foot_z = body.bone["foot_r"].z
    neck_z = body.bone["neck_01"].z
    elbow_x = body.bone["lowerarm_r"].x
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    torso, arms, feet = [], [], []
    for v in bm.verts:
        p = mw @ v.co
        arm = is_arm(body.ws[v.index])
        if arm > 0.3:
            if abs(p.x) < elbow_x + 0.03:
                arms.append(v)
        elif p.z < foot_z + 0.03:
            feet.append(v)
        elif p.z < neck_z - 0.02:
            torso.append(v)
    taubin(bm, torso, 14)
    taubin(bm, arms, 8)
    # Shoes: a little bigger than the foot, smooth, with a flat sole.
    bm.normal_update()
    for v in feet:
        v.co += v.normal * 0.008
    taubin(bm, feet, 10, mu=0.0)  # plain smoothing: the toes melt into a toecap
    inv = mw.inverted()
    for v in feet:
        p = mw @ v.co
        if p.z < 0.012:
            p.z = 0.0
            v.co = inv @ p
    bm.to_mesh(ob.data)
    bm.free()


def bake_face(body):
    """Vertex colours: red darkens (face detail from the texture), green marks the lips."""
    ob = body.mesh
    mw = ob.matrix_world
    cols = baked_colors(ob, body.texture)
    face = [i for i, w in enumerate(body.ws) if w.get("Head", 0.0) > 0.5]
    lum = sorted(luminance(cols[i]) for i in face)
    ref = lum[len(lum) // 2]
    red = sorted(cols[i][0] / (cols[i][1] + 0.02) for i in face)
    ref_red = red[len(red) // 2]
    mouth_lo = body.chin + 0.02
    mouth_hi = body.eye_c.z - 0.045
    out = []
    lips_z = []
    for i, v in enumerate(ob.data.vertices):
        c = cols[i]
        w = body.ws[i]
        k = min(1.0, max(0.0, (w.get("Head", 0.0) + w.get("neck_01", 0.0) - 0.3) / 0.5))
        detail = 1.0 + (min(1.1, max(0.72, luminance(c) / ref)) - 1.0) * k
        p = mw @ v.co
        lips = 0.0
        if k > 0.9 and mouth_lo < p.z < mouth_hi and abs(p.x) < 0.035 and p.y > body.head_c.y + 0.05:
            lips = min(1.0, max(0.0, (c[0] / (c[1] + 0.02) - ref_red * 1.06) / (ref_red * 0.12)))
            if lips > 0.5:
                lips_z.append(p.z)
        out.append((detail, lips, 1.0, 1.0))
    body.mouth_z = sum(lips_z) / len(lips_z) if lips_z else body.eye_c.z - 0.075
    print("  lips verts", len(lips_z), "mouth z %.3f" % body.mouth_z)
    return out


def make_body(body):
    """The body with the eyes joined in: one draw for skin, clothes, shoes and eyes."""
    colors = bake_face(body)
    smooth_under_clothes(body)
    set_fields(body.mesh, paint_fields(body, body.mesh))
    set_colors(body.mesh, colors)
    eye_cols = baked_colors(body.eyes, texture_of(body.eyes))
    set_fields(body.eyes, [(2.0, 0.0)] * len(body.eyes.data.vertices))  # above any neckline: never painted
    set_colors(body.eyes, [(c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 0.0) for c in eye_cols])  # the texture is sRGB; colours are linear
    for ob in (body.mesh, body.eyes):
        ob.data.materials.clear()
    joined = join("Body", [body.mesh, body.eyes])
    joined.data.materials.append(bpy.data.materials.new("Body"))
    smooth_shading(joined)
    body.mesh = joined
    body.ws = weights_of(joined)
    return joined


# --- Weights -------------------------------------------------------------------------

class Skinner:
    """Gives a garment the weights of the body surface under each of its vertices."""

    def __init__(self, body):
        self.body = body
        ob = body.mesh
        mw = ob.matrix_world
        self.verts = [mw @ v.co for v in ob.data.vertices]
        self.polys = [list(p.vertices) for p in ob.data.polygons]
        self.bvh = BVHTree.FromPolygons(self.verts, self.polys)

    def weights_at(self, p):
        loc, _n, index, _d = self.bvh.find_nearest(p)
        poly = self.polys[index]
        bary = poly_3d_calc([self.verts[i] for i in poly], loc)
        out = {}
        for vi, b in zip(poly, bary):
            for g, w in self.body.ws[vi].items():
                out[g] = out.get(g, 0.0) + w * b
        return out

    def skin(self, ob, rigid=None):
        """Binds `ob` (built in world space) to the body under it, or wholly to bone `rigid`."""
        arm = self.body.arm
        ob.vertex_groups.clear()
        groups = {}
        for v in ob.data.vertices:
            w = {rigid: 1.0} if rigid else self.weights_at(v.co)
            top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
            total = sum(x for _, x in top) or 1.0
            for g, x in top:
                if g not in groups:
                    groups[g] = ob.vertex_groups.new(name=g)
                groups[g].add([v.index], x / total, "REPLACE")
        ob.parent = arm
        ob.matrix_parent_inverse = arm.matrix_world.inverted()
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        ob.data.materials.clear()
        ob.data.materials.append(bpy.data.materials.get(ob.name) or bpy.data.materials.new(ob.name))
        smooth_shading(ob)
        return ob


# --- Surface placement ---------------------------------------------------------

class Surface:
    """Ray casts against the smoothed body, to sit badges and straps on it."""

    def __init__(self, body):
        ob = body.mesh
        mw = ob.matrix_world
        verts = [mw @ v.co for v in ob.data.vertices]
        self.bvh = BVHTree.FromPolygons(verts, [list(p.vertices) for p in ob.data.polygons])

    def front(self, x, z):
        """The body's front surface at (x, z): point and normal."""
        hit = self.bvh.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
        return hit[0], hit[1]

    def side(self, sign, z):
        """The body's side surface at height z, a little forward of the middle."""
        for y in (0.02, 0.0, 0.04, -0.02):
            hit = self.bvh.ray_cast(Vector((sign * 1.0, y, z)), Vector((-sign, 0, 0)))
            if hit[0] is not None:
                return hit[0], hit[1]
        raise RuntimeError("no side surface at %.3f" % z)


def surface_frame(normal):
    """Columns right, out (the normal), up: for a flat thing lying on the surface."""
    out = normal.normalized()
    right = Vector((0, 0, 1)).cross(out).normalized()
    up = out.cross(right).normalized()
    return Matrix((right, out, up)).transposed()


# --- Clothes -----------------------------------------------------------------------

def torso_ring(body, z, off, n=20, flare=0.0):
    """A ring round the body at height z (arms left out), `off` outside it."""
    mw = body.mesh.matrix_world
    pts = []
    for v, w in zip(body.mesh.data.vertices, body.ws):
        if is_arm(w) > 0.3:
            continue
        p = mw @ v.co
        if abs(p.z - z) < 0.01:
            pts.append(p)
    if not pts:
        return None
    cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
    r = radial_profile([(p.x, p.y - cy) for p in pts], n)
    return [Vector((math.sin(t) * (r[i] + off + flare), cy + math.cos(t) * (r[i] + off + flare), z))
            for i, t in enumerate(2 * math.pi * k / n for k in range(n))]


def sleeve_ring(body, side, x, off, n=10):
    """A ring round one arm (straight out to the side, as the pack rests) at x."""
    mw = body.mesh.matrix_world
    pts = []
    for v, w in zip(body.mesh.data.vertices, body.ws):
        if is_arm(w) < 0.5:
            continue
        p = mw @ v.co
        if p.x * side > 0 and abs(abs(p.x) - x) < 0.012:
            pts.append(p)
    if not pts:
        return None
    cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
    cz = (min(p.z for p in pts) + max(p.z for p in pts)) / 2
    r = radial_profile([(p.z - cz, p.y - cy) for p in pts], n)
    return [Vector((side * x, cy + math.cos(t) * (r[i] + off), cz + math.sin(t) * (r[i] + off)))
            for i, t in enumerate(2 * math.pi * k / n for k in range(n))]


def crotch_height(body):
    """Where the legs part: the lowest point between them, as a rig height."""
    mw = body.mesh.matrix_world
    low = body.bone["thigh_r"].z
    for v, w in zip(body.mesh.data.vertices, body.ws):
        p = mw @ v.co
        if abs(p.x) < 0.012 and is_arm(w) < 0.3 and body.bone["calf_r"].z < p.z < low:
            low = p.z
    return body.rig_height(low)


def cut(bm, co, no, where=lambda c: True):
    """Slices the faces whose centres pass `where` along the plane (co, no), so a
    trim along that plane leaves a straight edge instead of a ragged one."""
    faces = [f for f in bm.faces if where(f.calc_center_median())]
    geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no)


def drop_faces(bm, test):
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if test(f.calc_center_median())], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")


def body_shell(body, name, low, sleeve, off, gap=None):
    """A copy of the body's surface from rig height `low` up to the neckline and
    down the arms to `sleeve` (the arm paint field), pushed `off` out. Being the
    body's own surface, it bends exactly as the body does, so nothing pokes
    through. `gap(x, z)` > 0 marks the open front: (width, chest) for a front
    open below `chest` to `width` either side and widening above it."""
    fields = paint_fields(body, body.mesh)
    me = body.mesh.data.copy()
    me.transform(body.mesh.matrix_world)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    keep = lambda h, a: (a == 0.0 and low - 0.08 <= h <= 1.44) or 0.0 < a < sleeve + 0.06
    drop = [f for f in bm.faces if not all(keep(*fields[v.index]) for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # Straight edges: the hem, the cuffs and the opening.
    low_z = body.pack_height(low)
    wrist = lerp_table(sleeve, [(b, a) for a, b in body.arm_table])
    cut(bm, (0, 0, low_z), (0, 0, 1), lambda c: c.z < low_z + 0.1)
    for s in (1, -1):
        cut(bm, (s * wrist, 0, 0), (1, 0, 0), lambda c: c.x * s > wrist - 0.1)
    drop_faces(bm, lambda c: c.z < low_z or abs(c.x) > wrist)
    if gap:
        width, chest = gap
        for s in (1, -1):
            cut(bm, (s * width, 0, 0), (1, 0, 0), lambda c: c.y > 0.0 and c.z < chest + 0.04)
            cut(bm, (s * width, 0, chest), (s, 0, -0.32), lambda c: c.y > 0.0 and c.z > chest - 0.04)
        drop_faces(bm, lambda c: c.y > 0.0 and abs(c.x) < width + max(0.0, c.z - chest) * 0.32)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * off
    for layer in list(bm.loops.layers.uv):
        bm.loops.layers.uv.remove(layer)
    return mesh_object(name, bm)


def make_jacket(body, skin, name, hem, flare, open_front, off=0.018):
    """A jacket over the torso and arms, from the body's own surface. `hem` is a
    rig height; below where the legs part, a lofted skirt carries it on (a coat)."""
    split = crotch_height(body) + 0.03
    chest = body.pack_height(1.18)
    gap = (0.022, chest) if open_front else None
    pieces = [body_shell(body, name, max(hem, split), 0.8, off, gap)]
    if hem < split:  # a coat: a skirt from where the shell stops down to the hem
        mw = body.mesh.matrix_world
        top_z = body.pack_height(split)
        hem_z = body.pack_height(hem)
        near = [mw @ v.co for v, w in zip(body.mesh.data.vertices, body.ws)
                if is_arm(w) < 0.3 and abs((mw @ v.co).z - top_z) < 0.02]
        rx = max(abs(p.x) for p in near) + off
        y0, y1 = min(p.y for p in near), max(p.y for p in near)
        cy, ry = (y0 + y1) / 2, (y1 - y0) / 2 + off
        rings = []
        steps = 6
        for i in range(steps + 1):
            t = i / steps  # 0 at the hem, 1 tucked up under the jacket
            z = hem_z + (top_z + 0.06 - hem_z) * t
            grow = flare * (1 - t) - 0.012 * t
            rings.append([Vector((math.sin(a) * (rx + grow), cy + math.cos(a) * (ry + grow * 0.7), z))
                          for a in (2 * math.pi * k / 24 for k in range(24))])
        skirt = loft("Skirt", rings, gap=lambda m: m.y > cy and abs(m.x) < 0.03)
        face_outward(skirt, lambda c: Vector((0, cy, c.z)))
        pieces.append(skirt)
    nz = body.bone["neck_01"].z
    collar_gap = (lambda m: m.y > 0.0 and abs(m.x) < 0.05) if open_front else None
    collar = loft("Collar", [torso_ring(body, nz - 0.015, off * 0.8, 16), torso_ring(body, nz + 0.015, off * 0.7, 16)], gap=collar_gap)
    face_outward(collar, lambda c: Vector((0, 0, c.z)))
    pieces.append(collar)
    jacket = join(name, pieces)
    shade(jacket, 1.0)
    return skin.skin(jacket)


def make_tops(body, skin):
    out = {}
    nz = body.bone["neck_01"].z
    collar = loft("Collar", [torso_ring(body, nz - 0.01, 0.006, 16), torso_ring(body, nz + 0.012, 0.012, 16)])
    face_outward(collar, lambda c: Vector((0, 0, c.z)))
    shade(collar, 1.0)
    shade_where(collar, lambda c: c.z < nz - 0.005, 0.9)
    out["Collar"] = skin.skin(collar)
    out["Jacket_open"] = make_jacket(body, skin, "Jacket_open", 0.8, 0.01, True)
    closed = make_jacket(body, skin, "Jacket_closed", 0.83, 0.004, False, 0.02)
    shade_where(closed, lambda c: abs(c.x) < 0.008 and c.y > 0.05, 0.7)  # the zip
    out["Jacket_closed"] = closed
    blazer = make_jacket(body, skin, "Jacket_blazer", 0.79, 0.012, True)
    sz = body.bone["clavicle_r"].z
    for v in blazer.data.vertices:  # squarer shoulders
        if v.co.z > sz - 0.04 and 0.1 < abs(v.co.x) < body.shoulder_x + 0.08:
            v.co.z += 0.016 * min(1.0, (abs(v.co.x) - 0.1) / 0.08)
    out["Jacket_blazer"] = blazer
    out["Jacket_coat"] = make_jacket(body, skin, "Jacket_coat", 0.48, 0.06, True, 0.02)
    return out


def make_accessories(body, skin):
    """Logo patch, badges, lanyard, radio: fitted to the chest and belt."""
    out = {}
    surf = Surface(body)

    def patch(name, x, h, size, lift=0.004):
        p, n = surf.front(x, body.pack_height(h))
        return shade(box(name, p + n * (size[1] / 2 + lift), size, frame=surface_frame(n)), 1.0)

    out["Logo"] = patch("Logo", -0.085, 1.31, (0.06, 0.006, 0.045))
    out["Badge"] = patch("Badge", 0.085, 1.25, (0.05, 0.006, 0.07))
    out["Lanyard_badge"] = patch("Lanyard_badge", 0.0, 1.22, (0.05, 0.006, 0.07))
    # The lanyard: two straps from the sides of the neck down to the badge clip.
    straps = []
    nz = body.bone["neck_01"].z - 0.02
    clip = body.pack_height(1.22) + 0.035
    for s in (1, -1):
        bm = bmesh.new()
        rows = []
        for i in range(9):
            t = i / 8
            p, n = surf.front(s * (0.05 * (1 - t) + 0.006 * t), nz * (1 - t) + clip * t)
            if p is None:
                continue
            side = Vector((0, 0, 1)).cross(n).normalized() * 0.009
            q = p + n * 0.004
            rows.append((bm.verts.new(q - side), bm.verts.new(q + side)))
        for a, b in zip(rows, rows[1:]):
            bm.faces.new((a[0], b[0], b[1], a[1]))
        strap = mesh_object("Strap", bm)
        face_outward(strap, lambda c: Vector((0, 0, c.z)))
        straps.append(shade(strap, 1.0))
    out["Lanyard"] = join("Lanyard", straps)
    p, n = surf.side(1, body.pack_height(0.92))
    out["Belt_radio"] = shade(box("Belt_radio", p + n * 0.025, (0.045, 0.06, 0.11), bevel=0.008, frame=surface_frame(n)), 1.0)
    out["Logo_jacket"] = patch("Logo_jacket", -0.09, 1.30, (0.05, 0.006, 0.06), 0.03)
    out["Jacket_badge"] = patch("Jacket_badge", -0.09, 1.30, (0.04, 0.006, 0.05), 0.03)
    # Over a jacket, the badge and lanyard sit out on the jacket's front.
    for name in ("Badge", "Lanyard", "Lanyard_badge"):
        over = out[name].copy()
        over.data = out[name].data.copy()
        bpy.context.scene.collection.objects.link(over)
        over.data.transform(Matrix.Translation((0, 0.026, 0)))
        out[name + "_jacket"] = over
    for name, ob in out.items():
        ob.name = name
        ob.data.name = name
        if name == "Belt_radio":
            skin.skin(ob, rigid="pelvis")
        elif name.startswith("Lanyard") and "badge" not in name:
            skin.skin(ob)
        else:
            skin.skin(ob, rigid="spine_03")
    return out


# --- Hair and the head ----------------------------------------------------------------

HEADS = {}  # kind -> (centre, half size) of each base head, where its hairstyles sit


def import_mesh(path):
    """The mesh in a glTF, as world-space data in the turned (+Y forward) space."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    found = None
    for o in new:
        if o.type == "MESH" and not o.name.startswith("Icosphere"):
            found = world_mesh(o, os.path.basename(path)[:-5])
            found.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
            found["texture"] = texture_of(o)
    for o in new:
        bpy.data.objects.remove(o)
    return found


def fit_to_head(ob, body, native):
    nc, nr = HEADS[native]
    s = Vector((body.head_r.x / nr.x, body.head_r.y / nr.y, body.head_r.z / nr.z))
    for v in ob.data.vertices:
        d = v.co - nc
        v.co = body.head_c + Vector((d.x * s.x, d.y * s.y, d.z * s.z))


def hair_detail(ob, texture):
    """Strand detail from a hairstyle's texture, as vertex shade (0.6 to 1)."""
    lums = [luminance(c) for c in baked_colors(ob, texture)]
    hi = sorted(lums)[int(len(lums) * 0.95)] or 1.0
    return [(v, v, v, 1.0) for v in (0.6 + 0.4 * min(1.0, l / hi) for l in lums)]


def thin_body(ob, ratio=BODY_RATIO):
    """Fewer triangles everywhere but the head: hands, feet and muscles under
    clothes don't need the pack's detail. The pack's mesh is split along its
    texture seams; welding it first keeps those seams from cracking open."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(ob.data)
    bm.free()
    d = ob.modifiers.new("thin", "DECIMATE")
    d.ratio = ratio
    d.vertex_group = "Head"
    d.invert_vertex_group = True
    d.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_move_to_index(modifier="thin", index=0)
    bpy.ops.object.modifier_apply(modifier="thin")


def decimate(ob, ratio):
    d = ob.modifiers.new("dec", "DECIMATE")
    d.ratio = ratio
    apply_modifiers(ob)


def hairstyle(body, name, ratio=1.0):
    ob = import_mesh(os.path.join(HAIR, name + ".gltf"))
    fit_to_head(ob, body, HAIR_NATIVE[name])
    set_colors(ob, hair_detail(ob, ob["texture"]))
    strip_uvs(ob)
    if ratio < 1.0:
        decimate(ob, ratio)
    return ob


def make_hair(body, skin):
    out = {}
    brows = world_mesh(body.brows, "Brows")
    set_colors(brows, hair_detail(brows, texture_of(body.brows)))
    strip_uvs(brows)
    decimate(brows, 0.35)
    bpy.data.objects.remove(body.brows)

    def with_brows(name, ob):
        b = brows.copy()
        b.data = brows.data.copy()
        bpy.context.scene.collection.objects.link(b)
        return join(name, [ob, b])

    buzz = "Hair_Buzzed" if body.kind == 1 else "Hair_BuzzedFemale"
    hc = body.head_c
    out["Hair_short"] = with_brows("Hair_short", hairstyle(body, "Hair_SimpleParted", 0.6))
    out["Hair_long"] = with_brows("Hair_long", hairstyle(body, "Hair_Long", 0.45))
    out["Hair_buzzed"] = with_brows("Hair_buzzed", hairstyle(body, buzz, 0.35))
    # A bob: the long hair cut at the jaw.
    bob = hairstyle(body, "Hair_Long", 0.45)
    cut = body.chin + 0.03
    delete_faces(bob, lambda c: c.z < cut)
    for v in bob.data.vertices:
        v.co.z = max(v.co.z, cut + 0.01)
    out["Hair_bob"] = with_brows("Hair_bob", bob)
    # Bald with a fringe: the buzz cut kept round the back and sides only.
    bald = hairstyle(body, buzz, 0.35)
    delete_faces(bald, lambda c: c.y > hc.y + 0.03 or c.z > hc.z + 0.03 - max(0.0, c.y - hc.y + 0.06) * 0.25)
    out["Hair_bald"] = with_brows("Hair_bald", bald)
    # A mustache: the beard's upper lip.
    beard = hairstyle(body, "Hair_Beard")
    mz = body.mouth_z
    delete_faces(beard, lambda c: not (mz + 0.004 < c.z < mz + 0.03 and abs(c.x) < 0.034 and c.y > hc.y + 0.05))
    out["Face_mustache"] = beard
    bpy.data.objects.remove(brows)
    for name, ob in out.items():
        ob.name = name
        ob.data.name = name
        skin.skin(ob, rigid="Head")
    return out


# The head the hats were first designed round; they're stretched onto each body's head.
A_HEAD_C = Vector((0, 0, 1.625))
A_HEAD_R = Vector((0.105, 0.115, 0.13))


def to_head(ob, body, extra=0.0):
    r = body.head_r + Vector((extra, extra, extra))
    for v in ob.data.vertices:
        d = v.co - A_HEAD_C
        v.co = body.head_c + Vector((d.x * r.x / A_HEAD_R.x, d.y * r.y / A_HEAD_R.y, d.z * r.z / A_HEAD_R.z))
    return ob


def head_shell(name, keep, offset, segments=18, rings=12):
    shell = blob(name, A_HEAD_C, tuple(r + offset for r in A_HEAD_R), segments, rings)
    delete_faces(shell, lambda c: not keep(c))
    return shade(shell, 1.0)


def make_headwear(body, skin):
    out = {}
    hc = A_HEAD_C
    top = hc.z + 0.03
    crown = head_shell("CapCrown", lambda c: c.z > top, 0.02)
    brim = shade(cylinder("CapBrim", (0, 0.13, top + 0.012), 0.09, 0.012, 12, (1.0, 0.75, 1.0)), 0.9)
    out["Head_cap"] = join("Head_cap", [crown, brim])
    crown2 = head_shell("MercerCrown", lambda c: c.z > top + 0.005, 0.018)
    brim2 = shade(cylinder("MercerBrim", (0, 0.125, top), 0.088, 0.012, 12, (1.0, 0.72, 1.0)), 0.85)
    brim2.data.transform(Matrix.Translation((0, 0.125, top)) @ Matrix.Rotation(math.radians(16), 4, "X") @ Matrix.Translation((0, -0.125, -top)))
    out["Head_mercer_cap"] = join("Head_mercer_cap", [crown2, brim2])
    beanie = head_shell("Beanie", lambda c: c.z > hc.z + 0.02, 0.024)
    cuff = shade(cylinder("Cuff", (0, 0, hc.z + 0.035), 0.125, 0.04, 16, (0.92, 1.0, 1.0)), 0.85)
    out["Head_beanie"] = join("Head_beanie", [beanie, cuff])
    dome = head_shell("Dome", lambda c: c.z > top - 0.005, 0.03)
    rim = shade(cylinder("Rim", (0, 0.01, top), 0.155, 0.012, 18, (1.0, 1.1, 1.0)), 0.95)
    out["Head_hard_hat"] = join("Head_hard_hat", [dome, rim])
    for name, ob in out.items():
        to_head(ob, body, 0.006)  # room for the buzz cut worn under a hat
        ob.name = name
        ob.data.name = name
        skin.skin(ob, rigid="Head")
    return out


def make_face_items(body, skin):
    out = {}
    ex, ez = body.eye_c.x, body.eye_c.z
    y = body.eye_front + 0.012
    back = body.head_c.y - body.head_r.y * 0.25  # where the arms reach the ears
    ear = body.head_r.x + 0.004
    parts = []
    for s in (1, -1):
        cx = s * ex
        parts.append(box("Frame", (cx, y, ez + 0.016), (0.05, 0.006, 0.006)))
        parts.append(box("Frame", (cx, y, ez - 0.016), (0.05, 0.006, 0.006)))
        parts.append(box("Frame", (cx + s * 0.026, y, ez), (0.006, 0.006, 0.036)))
        parts.append(box("Frame", (cx - s * 0.026, y, ez), (0.006, 0.006, 0.036)))
        parts.append(box("Arm", (s * ear, (y + back) / 2, ez + 0.012), (0.005, y - back, 0.005)))
    parts.append(box("Bridge", (0, y + 0.002, ez + 0.01), (2 * ex - 0.05, 0.005, 0.005)))
    out["Face_glasses"] = join("Face_glasses", [shade(p, 1.0) for p in parts])
    parts = []
    zr = ez - 0.03
    for s in (1, -1):
        parts.append(box("Lens", (s * (ex - 0.003), y + 0.012, zr), (0.044, 0.004, 0.004)))
        parts.append(box("Lens", (s * (ex - 0.003), y + 0.012, zr - 0.013), (0.034, 0.004, 0.004)))
        parts.append(box("Arm", (s * ear, (y + 0.012 + back) / 2, zr + 0.02), (0.004, y + 0.012 - back, 0.004)))
    out["Face_reading_glasses"] = join("Face_reading_glasses", [shade(p, 1.0) for p in parts])
    studs = [blob("Stud", (s * (body.head_r.x + 0.006), back + 0.01, ez - 0.045), (0.006, 0.006, 0.006), 6, 4) for s in (1, -1)]
    out["Ears_studs"] = join("Ears_studs", [shade(s_, 1.0) for s_ in studs])
    for name, ob in out.items():
        ob.name = name
        ob.data.name = name
        skin.skin(ob, rigid="Head")
    return out


# --- Build ------------------------------------------------------------------------------

def build(kind):
    body = Body(kind)
    base = make_body(body)
    skin = Skinner(body)
    pieces = {}
    pieces.update(make_tops(body, skin))
    pieces.update(make_accessories(body, skin))
    pieces.update(make_hair(body, skin))
    pieces.update(make_headwear(body, skin))
    pieces.update(make_face_items(body, skin))
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o != base and o.name not in pieces:
            bpy.data.objects.remove(o)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "body%d.glb" % kind)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_skins=True, export_animations=False,
        export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_yup=True,
        export_texcoords=True, export_normals=True, export_materials="EXPORT",
    )
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    print("WROTE", path, "meshes", len(meshes), "body tris", tris(base), "all tris", sum(tris(o) for o in meshes))
    for o in sorted(meshes, key=lambda o: o.name):
        print("   %-24s %6d" % (o.name, tris(o)))


if __name__ == "__main__":
    for k in KINDS:  # measure both heads first: hairstyles move from one to the other
        b = Body(k)
        HEADS[k] = (b.head_c.copy(), b.head_r.copy())
    for k in KINDS:
        build(k)
