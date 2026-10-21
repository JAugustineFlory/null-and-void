"""Builds the furniture and fittings we take from the CC0 packs, with Blender (bpy).

    pip install bpy==5.0.1   # Python 3.11
    python -I tools/art/build_props.py -- GLB_DIR [PACKS_DIR] [ID ...]
    godot --headless -s tools/art/pack_props.gd -- GLB_DIR assets/art/props

PACKS_DIR is the project's staged packs folder (art/packs/, see
docs/art/CREDITS.md). Writes one .glb per prop in PROPS to GLB_DIR (name ids
to rebuild only those); pack_props.gd then packs each into the compressed mesh
the game loads, assets/art/props/<id>.res.

What happens to a pack's model, so it fits the game's look and stays small:
- Textures and extra materials go. Each face takes one flat colour: the average
  (median) of its texture (Poly Haven) or its material's colour (Quaternius), kept in the
  vertex colour. One mesh, one material, one draw.
- It's welded and decimated to a triangle budget, so a 20,000-triangle scan
  becomes a low-poly prop like the rest of the game.
- It's turned to face -Z (like ArtProps), scaled to its real size in metres,
  and stood with its origin on the floor under its middle.
Props load by id through ArtModels ("prop/<id>"); ArtProps.model() places one.
"""

import math
import os
import sys

import bpy
import bmesh  # after bpy: the wheel only exposes bmesh once bpy has loaded
import numpy as np
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/props"
PACKS = ARGS[1] if len(ARGS) > 1 else "/mnt/project-files/art/packs"
ONLY = ARGS[2:]

HOUSE = "quaternius/Ultimate House Interior/Ultimate House Interior Pack - June 2020/FBX/"
FURNITURE = "quaternius/Ultimate Furniture (2019)/Furniture Pack - March 2019/FBX/"

# id: src (under PACKS), tris (budget), size (metres: the largest of its x/y/z
# matched to the same axis of the model, after the turn), turn (degrees about
# up, so its front faces -Z in Godot), keep (only objects whose name has one of
# these), tint (material name part -> colour, to repaint a part).
PROPS = {
    "generator": {"src": "polyhaven/portable_generator/portable_generator_1k.gltf", "tris": 1400, "size": {"x": 0.82}},
    "wall_clock": {"src": "polyhaven/wall_clock/wall_clock_1k.gltf", "tris": 300, "size": {"x": 0.32}},
    "hand_truck": {"src": "polyhaven/hand_truck/hand_truck_1k.gltf", "tris": 900, "size": {"y": 1.3}},
    "metal_rack": {"src": "polyhaven/worn_metal_rack/worn_metal_rack_1k.gltf", "tris": 700, "size": {"y": 1.9}},
    "metal_desk": {"src": "polyhaven/metal_office_desk/metal_office_desk_1k.gltf", "tris": 900, "size": {"y": 0.76}},
    "utility_box": {"src": "polyhaven/utility_box_01/utility_box_01_1k.gltf", "tris": 500, "size": {"y": 0.9}},
    "wheelie_bin": {"src": HOUSE + "Trashcan_Green.fbx", "tris": 700, "size": {"y": 1.1},
                    "tint": {"Green": (0.13, 0.22, 0.4)}},
    "wood_chair": {"src": HOUSE + "Chair_1.fbx", "tris": 300, "size": {"y": 0.9}},
    "desk_lamp": {"src": HOUSE + "Light_Desk.fbx", "tris": 400, "size": {"y": 0.45}},
    "wood_desk": {"src": FURNITURE + "Desk.fbx", "tris": 1200, "size": {"y": 0.76}},
}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    if path.endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    elif path.endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# --- Colours -------------------------------------------------------------------

def _linear_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def material_source(mat):
    """(image pixels HxWx4 as stored, or None, flat sRGB colour) for a material."""
    colour = np.array([0.8, 0.8, 0.8])
    if mat is None:
        return None, colour
    if not mat.node_tree:
        return None, _linear_to_srgb(np.array(mat.diffuse_color[:3]))
    for n in mat.node_tree.nodes:
        if n.type != "BSDF_PRINCIPLED":
            continue
        inp = n.inputs["Base Color"]
        if inp.is_linked:
            src = inp.links[0].from_node
            if src.type == "TEX_IMAGE" and src.image:
                img = src.image
                w, h = img.size
                px = np.empty(w * h * 4, dtype=np.float32)
                img.pixels.foreach_get(px)
                return px.reshape(h, w, 4), colour
        return None, _linear_to_srgb(np.array(inp.default_value[:3]))
    return None, colour


def sample(px, uv):
    h, w, _ = px.shape
    if not (math.isfinite(uv[0]) and math.isfinite(uv[1])):
        uv = (0.0, 0.0)
    x = int((uv[0] % 1.0) * (w - 1))
    y = int((uv[1] % 1.0) * (h - 1))
    return px[y, x, :3]


def bake_face_colours(ob, tint):
    """Give every face one colour: its texture's average over the face, or its
    material's colour. Stored per corner (sRGB bytes) for the exporter."""
    me = ob.data
    sources = []
    for slot in ob.material_slots:
        px, flat = material_source(slot.material)
        name = slot.material.name if slot.material else ""
        for part, c in tint.items():
            if part.lower() in name.lower():
                px, flat = None, np.array(c)
        sources.append((px, flat))
    uv = None
    if me.uv_layers.active:
        # Copied out first: adding the colour attribute moves the mesh's layers.
        uv = np.empty(len(me.loops) * 2, dtype=np.float32)
        me.uv_layers.active.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly in me.polygons:
        px, flat = sources[poly.material_index] if sources else (None, np.array([0.8, 0.8, 0.8]))
        if px is not None and uv is not None:
            loops = list(poly.loop_indices)
            pts = [uv[i] for i in loops]
            centre = sum((Vector(p) for p in pts), Vector((0, 0))) / len(pts)
            # The middle and points part-way to each corner. The median keeps the
            # face's own colour where a thin line (a clock's numbers) crosses it.
            samples = [sample(px, centre)] + [sample(px, centre.lerp(Vector(p), t)) for p in pts for t in (0.3, 0.6, 0.85)]
            c = np.median(samples, axis=0)
        else:
            c = flat
        for i in poly.loop_indices:
            attr.data[i].color_srgb = (float(c[0]), float(c[1]), float(c[2]), 1.0)
    me.color_attributes.active_color = attr
    me.color_attributes.default_color_name = attr.name


# --- Build ---------------------------------------------------------------------

def build(pid, spec):
    clear()
    load(os.path.join(PACKS, spec["src"]))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    keep = spec.get("keep")
    if keep:
        meshes = [o for o in meshes if any(k in o.name for k in keep)]
    # Bake every object's world transform into its mesh, then join them.
    for o in meshes:
        o.data = o.data.copy()
        o.data.transform(o.matrix_world)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
        for m in list(o.modifiers):
            o.modifiers.remove(m)
    for o in list(bpy.data.objects):
        if o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)
    for o in meshes:
        if o.data.uv_layers:
            o.data.uv_layers.active = o.data.uv_layers[0]
        bake_face_colours(o, spec.get("tint", {}))
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = pid
    me = ob.data

    # Weld (imports split vertices at UV seams), then decimate to the budget.
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.to_mesh(me)
    bm.free()
    have = tris(ob)
    if have > spec["tris"]:
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.ratio = spec["tris"] / have
        bpy.ops.object.modifier_apply(modifier=mod.name)

    # Face -Y in Blender is the packs' front; Godot's -Z is glTF's -Z, which is
    # Blender's +Y. So turn it round (plus any per-prop turn).
    turn = math.radians(180.0 + spec.get("turn", 0.0))
    me.transform(Matrix.Rotation(turn, 4, "Z"))
    # Real size: Blender (x, y, z) is Godot (x, z, y).
    co = np.array([v.co[:] for v in me.vertices])
    lo, hi = co.min(axis=0), co.max(axis=0)
    axis, want = next(iter(spec["size"].items()))
    have_len = (hi - lo)[{"x": 0, "z": 1, "y": 2}[axis]]
    s = want / have_len
    me.transform(Matrix.Scale(s, 4))
    centre = Vector(((lo[0] + hi[0]) / 2 * s, (lo[1] + hi[1]) / 2 * s, lo[2] * s))
    me.transform(Matrix.Translation(-centre))

    # One plain material; the colour is in the vertices. No UVs: nothing samples them.
    me.materials.clear()
    mat = bpy.data.materials.new(pid)
    me.materials.append(mat)
    for poly in me.polygons:
        poly.material_index = 0
        poly.use_smooth = False
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, pid + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_animations=False,
        export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_yup=True,
        export_texcoords=False, export_normals=True, export_materials="EXPORT",
    )
    dims = (hi - lo) * s
    print("WROTE %-12s %5d tris  %5.1f KB  %.2f x %.2f x %.2f m" % (
        pid, tris(ob), os.path.getsize(path) / 1024, dims[0], dims[2], dims[1]))


if __name__ == "__main__":
    for pid, spec in PROPS.items():
        if not ONLY or pid in ONLY:
            build(pid, spec)
