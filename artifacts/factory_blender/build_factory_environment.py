import bpy
import math
import os
from mathutils import Vector

OUT_DIR = "/Users/dongnt/Desktop/github/dockmagic/artifacts/factory_blender"
ENV_BLEND = os.path.join(OUT_DIR, "factory_environment.blend")
ENV_PREVIEW = os.path.join(OUT_DIR, "factory_environment_preview.png")
os.makedirs(OUT_DIR, exist_ok=True)

# Start from the untouched default scene.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    bpy.data.collections.remove(collection)

scene = bpy.context.scene
scene.name = "DockMagic Factory"
scene["factory_stage"] = "environment-only"
scene["design_language"] = "neutral-first, one action blue, modular isometric factory"

root_collection = bpy.data.collections.new("FACTORY_ENVIRONMENT")
scene.collection.children.link(root_collection)
architecture = bpy.data.collections.new("Architecture")
stations = bpy.data.collections.new("Workstations")
props = bpy.data.collections.new("Factory Props")
lighting = bpy.data.collections.new("Lighting")
root_collection.children.link(architecture)
root_collection.children.link(stations)
root_collection.children.link(props)
root_collection.children.link(lighting)

def material(name, color, metallic=0.0, roughness=0.55, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = (*emission, 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat

MAT_CANVAS = material("MAT_Canvas", (0.012, 0.014, 0.018), roughness=0.72)
MAT_PLATFORM = material("MAT_Platform", (0.055, 0.060, 0.068), metallic=0.25, roughness=0.52)
MAT_FLOOR = material("MAT_Floor", (0.090, 0.096, 0.105), metallic=0.12, roughness=0.63)
MAT_FLOOR_ALT = material("MAT_Floor_Inset", (0.052, 0.057, 0.064), metallic=0.10, roughness=0.72)
MAT_WALL = material("MAT_Wall", (0.115, 0.121, 0.132), metallic=0.18, roughness=0.52)
MAT_OUTLINE = material("MAT_Outline", (0.020, 0.023, 0.028), metallic=0.30, roughness=0.44)
MAT_METAL = material("MAT_Metal", (0.160, 0.170, 0.184), metallic=0.74, roughness=0.30)
MAT_DARK_METAL = material("MAT_Dark_Metal", (0.038, 0.043, 0.050), metallic=0.72, roughness=0.34)
MAT_RUBBER = material("MAT_Rubber", (0.010, 0.012, 0.015), metallic=0.0, roughness=0.90)
MAT_TEXT = material("MAT_Text", (0.68, 0.70, 0.74), metallic=0.0, roughness=0.58)
MAT_ACCENT = material("MAT_Action_Blue", (0.0, 0.23, 0.72), metallic=0.30, roughness=0.28, emission=(0.0, 0.24, 0.82), emission_strength=1.8)
MAT_SCREEN = material("MAT_Screen", (0.006, 0.025, 0.050), metallic=0.18, roughness=0.24, emission=(0.0, 0.26, 0.82), emission_strength=2.1)

def move_to_collection(obj, collection):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)

def add_box(name, location, size, mat, collection=architecture, rotation=(0.0, 0.0, 0.0), bevel=0.12):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("Soft industrial edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return obj

def add_cylinder(name, location, radius, depth, mat, collection=props, rotation=(0.0, 0.0, 0.0), vertices=16, bevel=0.06):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    if bevel > 0:
        modifier = obj.modifiers.new("Edge bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return obj

def add_text(name, body, location, size=0.62, rotation=(0.0, 0.0, 0.0), align='CENTER', collection=architecture):
    bpy.ops.object.text_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.body = body
    obj.data.align_x = align
    obj.data.align_y = 'CENTER'
    obj.data.size = size
    obj.data.extrude = 0.025
    obj.data.bevel_depth = 0.012
    obj.data.materials.append(MAT_TEXT)
    move_to_collection(obj, collection)
    return obj

def add_curve(name, points, mat, bevel_depth=0.055, collection=props):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = bevel_depth
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for index, point in enumerate(points):
        spline.points[index].co = (*point, 1.0)
    obj = bpy.data.objects.new(name, curve)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

def add_panel_sign(project, center):
    add_box(project + "_Sign_Plate", (center[0], center[1], 0.42), (4.3, 0.95, 0.22), MAT_DARK_METAL, architecture, bevel=0.16)
    add_text(project + "_Sign_Text", project, (center[0], center[1] - 0.04, 0.55), size=0.47, rotation=(0.0, 0.0, 0.0))

def add_monitor(prefix, location, facing=0.0):
    x, y, z = location
    add_cylinder(prefix + "_Monitor_Stem", (x, y, z + 0.35), 0.10, 0.58, MAT_METAL, stations, vertices=12)
    add_box(prefix + "_Monitor", (x, y, z + 0.92), (1.7, 0.20, 1.02), MAT_DARK_METAL, stations, rotation=(0.0, 0.0, facing), bevel=0.11)
    screen = add_box(prefix + "_Screen", (x, y - 0.115, z + 0.92), (1.42, 0.055, 0.74), MAT_SCREEN, stations, rotation=(0.0, 0.0, facing), bevel=0.045)
    return screen

def add_workstation(prefix, center, width=3.5):
    x, y = center
    add_box(prefix + "_Desk", (x, y, 0.72), (width, 1.45, 0.28), MAT_METAL, stations, bevel=0.14)
    for dx in (-width * 0.38, width * 0.38):
        add_box(prefix + "_Desk_Leg", (x + dx, y, 0.36), (0.20, 1.12, 0.72), MAT_DARK_METAL, stations, bevel=0.06)
    add_monitor(prefix, (x, y + 0.05, 0.78))
    add_box(prefix + "_Keyboard", (x, y - 0.48, 0.91), (1.15, 0.42, 0.06), MAT_RUBBER, stations, bevel=0.05)
    add_box(prefix + "_Chair_Base", (x, y - 1.65, 0.32), (1.15, 1.05, 0.22), MAT_DARK_METAL, stations, bevel=0.12)
    add_box(prefix + "_Chair_Back", (x, y - 1.98, 0.92), (1.15, 0.22, 1.22), MAT_DARK_METAL, stations, rotation=(math.radians(-8), 0.0, 0.0), bevel=0.14)

def add_server_rack(prefix, location):
    x, y = location
    add_box(prefix + "_Rack", (x, y, 1.45), (2.1, 1.25, 2.9), MAT_DARK_METAL, props, bevel=0.14)
    for row in range(5):
        z = 0.48 + row * 0.48
        add_box(prefix + "_Unit_" + str(row), (x, y - 0.64, z), (1.72, 0.08, 0.29), MAT_METAL, props, bevel=0.035)
        add_cylinder(prefix + "_Light_" + str(row), (x + 0.62, y - 0.70, z), 0.055, 0.035, MAT_ACCENT, props, rotation=(math.radians(90), 0.0, 0.0), vertices=12, bevel=0.0)

def add_crate(prefix, location, size=1.0):
    x, y, z = location
    add_box(prefix + "_Body", (x, y, z + size * 0.5), (size, size, size), MAT_PLATFORM, props, bevel=0.09)
    band = 0.10
    add_box(prefix + "_Band_X", (x, y, z + size * 0.5), (size + 0.04, band, size + 0.04), MAT_METAL, props, bevel=0.02)
    add_box(prefix + "_Band_Y", (x, y, z + size * 0.5), (band, size + 0.04, size + 0.04), MAT_METAL, props, bevel=0.02)

def add_conveyor(prefix, center, length=4.8):
    x, y = center
    add_box(prefix + "_Frame", (x, y, 0.62), (length, 1.45, 0.34), MAT_DARK_METAL, props, bevel=0.10)
    roller_count = 8
    for index in range(roller_count):
        rx = x - length * 0.42 + index * (length * 0.84 / (roller_count - 1))
        add_cylinder(prefix + "_Roller_" + str(index), (rx, y, 0.84), 0.18, 1.18, MAT_METAL, props, rotation=(math.radians(90), 0.0, 0.0), vertices=16)
    for dx in (-length * 0.42, length * 0.42):
        add_box(prefix + "_Leg", (x + dx, y, 0.31), (0.22, 1.12, 0.62), MAT_PLATFORM, props, bevel=0.05)

# Canvas and platform
add_box("Factory_Backdrop", (0.0, 0.0, -1.05), (40.0, 40.0, 0.4), MAT_CANVAS, architecture, bevel=0.0)
add_box("Factory_Platform", (0.0, 0.0, -0.35), (22.8, 22.8, 0.9), MAT_PLATFORM, architecture, bevel=0.32)

bay_centers = {
    "DOCKMAGIC": (-5.35, 5.35),
    "BENAGENT": (5.35, 5.35),
    "WEBSITE": (-5.35, -5.35),
    "CLI TOOLS": (5.35, -5.35),
}
for index, (name, center) in enumerate(bay_centers.items()):
    floor_mat = MAT_FLOOR if index % 2 == 0 else MAT_FLOOR_ALT
    add_box(name + "_Floor", (center[0], center[1], 0.08), (9.9, 9.9, 0.34), floor_mat, architecture, bevel=0.16)
    # Neutral inset frame around each bay.
    add_box(name + "_Frame_Back", (center[0], center[1] + 4.72, 0.31), (9.3, 0.16, 0.22), MAT_OUTLINE, architecture, bevel=0.04)
    add_box(name + "_Frame_Front", (center[0], center[1] - 4.72, 0.31), (9.3, 0.16, 0.22), MAT_OUTLINE, architecture, bevel=0.04)
    add_box(name + "_Frame_Left", (center[0] - 4.72, center[1], 0.31), (0.16, 9.3, 0.22), MAT_OUTLINE, architecture, bevel=0.04)
    add_box(name + "_Frame_Right", (center[0] + 4.72, center[1], 0.31), (0.16, 9.3, 0.22), MAT_OUTLINE, architecture, bevel=0.04)

# Central service cross
add_box("Central_Walkway_NS", (0.0, 0.0, 0.30), (1.15, 21.0, 0.18), MAT_WALL, architecture, bevel=0.08)
add_box("Central_Walkway_EW", (0.0, 0.0, 0.31), (21.0, 1.15, 0.18), MAT_WALL, architecture, bevel=0.08)
add_box("Action_Blue_Inlay_NS", (0.0, 0.0, 0.42), (0.075, 20.2, 0.025), MAT_ACCENT, architecture, bevel=0.015)
add_box("Action_Blue_Inlay_EW", (0.0, 0.0, 0.43), (20.2, 0.075, 0.025), MAT_ACCENT, architecture, bevel=0.015)

# Outer back and side walls, kept low enough for isometric readability.
add_box("Back_Wall", (0.0, 10.75, 1.55), (22.0, 0.42, 3.1), MAT_WALL, architecture, bevel=0.16)
add_box("Left_Wall", (-10.75, 0.0, 1.55), (0.42, 21.6, 3.1), MAT_WALL, architecture, bevel=0.16)
add_box("Right_Wall", (10.75, 0.0, 1.55), (0.42, 21.6, 3.1), MAT_WALL, architecture, bevel=0.16)
add_box("Front_Left_Bumper", (-7.9, -10.75, 0.75), (5.4, 0.42, 1.5), MAT_WALL, architecture, bevel=0.16)
add_box("Front_Right_Bumper", (7.9, -10.75, 0.75), (5.4, 0.42, 1.5), MAT_WALL, architecture, bevel=0.16)

# Low internal partitions
for y in (-5.35, 5.35):
    add_box("Partition_V_" + str(y), (0.0, y, 1.0), (0.36, 8.8, 2.0), MAT_WALL, architecture, bevel=0.12)
for x in (-5.35, 5.35):
    add_box("Partition_H_" + str(x), (x, 0.0, 1.0), (8.8, 0.36, 2.0), MAT_WALL, architecture, bevel=0.12)

# Project signage
add_panel_sign("DOCKMAGIC", (-5.35, 8.75))
add_panel_sign("BENAGENT", (5.35, 8.75))
add_panel_sign("WEBSITE", (-5.35, -1.85))
add_panel_sign("CLI TOOLS", (5.35, -1.85))

# Workstations and distinct production props
add_workstation("DockMagic_Main", (-5.4, 3.8))
add_workstation("BenAgent_Main", (5.2, 4.0))
add_workstation("Website_Main", (-5.4, -6.3))
add_workstation("CLI_Main", (5.2, -6.2))

add_conveyor("DockMagic_Build_Line", (-5.4, 7.0), length=4.5)
add_server_rack("BenAgent_Server", (7.7, 6.7))

# Website signal pylons
for offset in (-1.1, 0.0, 1.1):
    add_cylinder("Website_Node_" + str(offset), (-7.2 + offset, -3.4, 0.78), 0.24, 1.55, MAT_METAL, props, vertices=12)
    add_cylinder("Website_Node_Light_" + str(offset), (-7.2 + offset, -3.4, 1.58), 0.11, 0.12, MAT_ACCENT, props, vertices=12)
add_curve("Website_Data_Cable", [(-8.3, -3.4, 0.35), (-5.4, -3.4, 0.35), (-5.4, -5.1, 0.35)], MAT_DARK_METAL, 0.055)

# CLI tool crates and terminal pedestal
add_crate("CLI_Crate_A", (7.5, -3.8, 0.25), 1.25)
add_crate("CLI_Crate_B", (8.7, -4.9, 0.25), 0.95)
add_crate("CLI_Crate_C", (7.5, -5.2, 0.25), 0.82)
add_box("CLI_Terminal_Pedestal", (3.1, -3.8, 0.85), (1.4, 1.4, 1.7), MAT_DARK_METAL, props, bevel=0.16)
add_box("CLI_Terminal_Screen", (3.1, -4.52, 1.2), (1.0, 0.07, 0.68), MAT_SCREEN, props, bevel=0.05)

# Repeating architectural details
for x in (-8.6, -4.3, 0.0, 4.3, 8.6):
    add_cylinder("Back_Pipe_" + str(x), (x, 10.47, 1.8), 0.13, 2.2, MAT_DARK_METAL, props, vertices=12)
    add_box("Back_Pipe_Cap_" + str(x), (x, 10.22, 2.82), (0.42, 0.46, 0.26), MAT_METAL, props, bevel=0.05)

for location in [(-9.7, 9.6), (9.7, 9.6), (-9.7, -9.6), (9.7, -9.6)]:
    add_cylinder("Corner_Beacon_" + str(location), (location[0], location[1], 0.73), 0.19, 1.25, MAT_DARK_METAL, props, vertices=12)
    add_cylinder("Corner_Beacon_Light_" + str(location), (location[0], location[1], 1.43), 0.12, 0.15, MAT_ACCENT, props, vertices=12)

# Camera
bpy.ops.object.camera_add(location=(24.0, -29.0, 25.0))
camera = bpy.context.object
camera.name = "Factory_Orthographic_Camera"
camera.data.type = "ORTHO"
camera.data.ortho_scale = 31.5
move_to_collection(camera, lighting)

def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

look_at(camera, (0.0, 0.0, 1.1))
scene.camera = camera

# Lighting
def add_area(name, location, energy, size, color=(1.0, 1.0, 1.0)):
    bpy.ops.object.light_add(type='AREA', location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = 'DISK'
    light.data.size = size
    light.data.color = color
    look_at(light, (0.0, 0.0, 0.0))
    move_to_collection(light, lighting)
    return light

add_area("Key_Light", (-8.0, -10.0, 24.0), 1550.0, 13.0)
add_area("Fill_Light", (15.0, -2.0, 15.0), 1050.0, 10.0)
add_area("Rim_Light", (-12.0, 13.0, 12.0), 900.0, 8.0)
bpy.ops.object.light_add(type='POINT', location=(0.0, 0.0, 10.0))
center_light = bpy.context.object
center_light.name = "Center_Soft_Light"
center_light.data.energy = 450.0
center_light.data.shadow_soft_size = 5.0
move_to_collection(center_light, lighting)

scene.world.color = (0.004, 0.005, 0.008)
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.render.filepath = ENV_PREVIEW
scene.render.image_settings.color_mode = 'RGBA'
scene.render.resolution_percentage = 100
try:
    scene.view_settings.look = 'AgX - Medium High Contrast'
except Exception:
    pass

# Metadata for future export/use.
root_collection["modular_asset_ready"] = True
root_collection["camera_style"] = "fixed orthographic isometric"
root_collection["palette"] = "neutral materials + one action blue"
root_collection["tile_units"] = 1.0

bpy.ops.wm.save_as_mainfile(filepath=ENV_BLEND)
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=ENV_BLEND)
print("FACTORY_ENVIRONMENT_COMPLETE", ENV_BLEND, ENV_PREVIEW)
