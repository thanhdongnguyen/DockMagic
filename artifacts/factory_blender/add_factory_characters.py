import bpy
import math
import os
from mathutils import Vector

OUT_DIR = "/Users/dongnt/Desktop/github/dockmagic/artifacts/factory_blender"
FINAL_BLEND = os.path.join(OUT_DIR, "factory_scene_with_characters.blend")
FINAL_PREVIEW = os.path.join(OUT_DIR, "factory_final_preview.png")
CHAR_PREVIEW = os.path.join(OUT_DIR, "factory_character_preview.png")
CHAR_SIDE_PREVIEW = os.path.join(OUT_DIR, "factory_character_side_preview.png")

scene = bpy.context.scene
scene["factory_stage"] = "environment-and-rigged-characters"

root_environment = bpy.data.collections.get("FACTORY_ENVIRONMENT")
if root_environment is None:
    raise RuntimeError("Factory environment collection is missing")

character_root = bpy.data.collections.get("FACTORY_CHARACTERS")
if character_root:
    for obj in list(character_root.all_objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(character_root)
character_root = bpy.data.collections.new("FACTORY_CHARACTERS")
scene.collection.children.link(character_root)

def get_material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        raise RuntimeError("Missing material: " + name)
    return mat

MAT_ACCENT = get_material("MAT_Action_Blue")
MAT_DARK = get_material("MAT_Dark_Metal")
MAT_METAL = get_material("MAT_Metal")
MAT_RUBBER = get_material("MAT_Rubber")

def material(name, color, metallic=0.0, roughness=0.5, emission=None, emission_strength=0.0):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
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

MAT_SHELL = material("MAT_Robot_Shell", (0.58, 0.62, 0.68), metallic=0.48, roughness=0.28)
MAT_SHELL_LIGHT = material("MAT_Robot_Shell_Light", (0.82, 0.85, 0.89), metallic=0.35, roughness=0.25)
MAT_JOINT = material("MAT_Robot_Joint", (0.025, 0.030, 0.038), metallic=0.64, roughness=0.30)
MAT_VISOR = material("MAT_Robot_Visor", (0.006, 0.010, 0.016), metallic=0.42, roughness=0.18)
MAT_EYE = material("MAT_Robot_Eye", (0.0, 0.22, 0.74), metallic=0.22, roughness=0.20, emission=(0.0, 0.34, 1.0), emission_strength=3.2)
MAT_WARNING = material("MAT_Waiting_Approval", (0.72, 0.18, 0.015), metallic=0.20, roughness=0.32, emission=(1.0, 0.22, 0.015), emission_strength=2.6)

def move_to_collection(obj, collection):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)

def add_box(name, location, size, mat, collection, rotation=(0.0, 0.0, 0.0), bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("Mechanical edge bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return obj

def add_sphere(name, location, scale, mat, collection, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return obj

def add_cylinder(name, location, radius, depth, mat, collection, rotation=(0.0, 0.0, 0.0), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    modifier = obj.modifiers.new("Mechanical edge bevel", "BEVEL")
    modifier.width = min(radius * 0.22, 0.06)
    modifier.segments = 2
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return obj

def parent_to_bone(obj, armature, bone_name):
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = 'BONE'
    obj.parent_bone = bone_name
    obj.matrix_world = world

def create_armature(name, origin, scale, collection):
    arm_data = bpy.data.armatures.new(name + "_Armature")
    armature = bpy.data.objects.new(name + "_RIG", arm_data)
    collection.objects.link(armature)
    armature.location = origin
    armature.show_in_front = True
    armature.display_type = 'WIRE'

    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')

    def bone(bone_name, head, tail, parent=None):
        b = arm_data.edit_bones.new(bone_name)
        b.head = tuple(scale * value for value in head)
        b.tail = tuple(scale * value for value in tail)
        if parent:
            b.parent = arm_data.edit_bones.get(parent)
        return b

    bone("root", (0, 0, 0.06), (0, 0, 0.42))
    bone("pelvis", (0, 0, 0.42), (0, 0, 0.82), "root")
    bone("spine", (0, 0, 0.82), (0, 0, 1.48), "pelvis")
    bone("neck", (0, 0, 1.48), (0, 0, 1.65), "spine")
    bone("head", (0, 0, 1.65), (0, 0, 2.24), "neck")
    bone("upper_arm.L", (0.42, 0, 1.38), (0.82, 0, 1.26), "spine")
    bone("forearm.L", (0.82, 0, 1.26), (1.12, -0.08, 0.98), "upper_arm.L")
    bone("hand.L", (1.12, -0.08, 0.98), (1.24, -0.10, 0.86), "forearm.L")
    bone("upper_arm.R", (-0.42, 0, 1.38), (-0.82, 0, 1.26), "spine")
    bone("forearm.R", (-0.82, 0, 1.26), (-1.12, -0.08, 0.98), "upper_arm.R")
    bone("hand.R", (-1.12, -0.08, 0.98), (-1.24, -0.10, 0.86), "forearm.R")
    bone("thigh.L", (0.28, 0, 0.66), (0.30, 0, 0.30), "pelvis")
    bone("shin.L", (0.30, 0, 0.30), (0.30, 0, -0.08), "thigh.L")
    bone("foot.L", (0.30, 0, -0.08), (0.30, -0.28, -0.12), "shin.L")
    bone("thigh.R", (-0.28, 0, 0.66), (-0.30, 0, 0.30), "pelvis")
    bone("shin.R", (-0.30, 0, 0.30), (-0.30, 0, -0.08), "thigh.R")
    bone("foot.R", (-0.30, 0, -0.08), (-0.30, -0.28, -0.12), "shin.R")

    bpy.ops.object.mode_set(mode='POSE')
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = 'XYZ'
    bpy.ops.object.mode_set(mode='OBJECT')
    armature.select_set(False)
    return armature

def create_actions(armature, prefix):
    actions = {}
    specifications = {
        "Idle": [
            (1, {"root_loc": (0, 0, 0), "head": (0, 0, 0)}),
            (20, {"root_loc": (0, 0, 0.025), "head": (0.025, 0, -0.025)}),
            (40, {"root_loc": (0, 0, 0), "head": (0, 0, 0)}),
        ],
        "Thinking": [
            (1, {"head": (0.02, 0, -0.12), "upper_arm.L": (0, 0.10, -0.20), "forearm.L": (0, 0.15, -0.52)}),
            (16, {"head": (-0.04, 0.06, 0.11), "upper_arm.L": (0, 0.14, -0.28), "forearm.L": (0, 0.20, -0.62)}),
            (32, {"head": (0.02, 0, -0.12), "upper_arm.L": (0, 0.10, -0.20), "forearm.L": (0, 0.15, -0.52)}),
        ],
        "Typing": [
            (1, {"upper_arm.L": (0.18, 0, -0.18), "forearm.L": (0.30, 0, -0.42), "upper_arm.R": (-0.18, 0, 0.18), "forearm.R": (-0.30, 0, 0.42)}),
            (6, {"upper_arm.L": (0.12, 0, -0.14), "forearm.L": (0.42, 0, -0.34), "upper_arm.R": (-0.12, 0, 0.14), "forearm.R": (-0.42, 0, 0.34)}),
            (12, {"upper_arm.L": (0.18, 0, -0.18), "forearm.L": (0.30, 0, -0.42), "upper_arm.R": (-0.18, 0, 0.18), "forearm.R": (-0.30, 0, 0.42)}),
        ],
        "Testing": [
            (1, {"head": (0.0, 0.0, -0.10), "upper_arm.R": (-0.12, 0.18, 0.10), "forearm.R": (-0.18, 0.12, 0.38)}),
            (12, {"head": (0.0, 0.0, 0.12), "upper_arm.R": (-0.18, 0.10, 0.18), "forearm.R": (-0.24, 0.16, 0.48)}),
            (24, {"head": (0.0, 0.0, -0.10), "upper_arm.R": (-0.12, 0.18, 0.10), "forearm.R": (-0.18, 0.12, 0.38)}),
        ],
        "WaitingApproval": [
            (1, {"head": (0.16, 0.0, 0.0), "upper_arm.L": (0.0, 0.0, -0.08), "upper_arm.R": (0.0, 0.0, 0.08)}),
            (24, {"head": (0.20, 0.0, 0.0), "upper_arm.L": (0.0, 0.0, -0.08), "upper_arm.R": (0.0, 0.0, 0.08)}),
        ],
    }
    armature.animation_data_create()
    for action_name, frames in specifications.items():
        action = bpy.data.actions.new(prefix + "_" + action_name)
        action.use_fake_user = True
        armature.animation_data.action = action
        for pose_bone in armature.pose.bones:
            pose_bone.rotation_mode = 'XYZ'
            pose_bone.rotation_euler = (0.0, 0.0, 0.0)
            pose_bone.location = (0.0, 0.0, 0.0)
        for frame, values in frames:
            scene.frame_set(frame)
            root = armature.pose.bones.get("root")
            if "root_loc" in values:
                root.location = tuple(values["root_loc"])
                root.keyframe_insert(data_path="location", frame=frame, group="root")
            for bone_name, rotation in values.items():
                if bone_name == "root_loc":
                    continue
                pose_bone = armature.pose.bones.get(bone_name)
                if pose_bone:
                    pose_bone.rotation_euler = rotation
                    pose_bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)
        actions[action_name] = action
    armature.animation_data.action = None
    armature["available_actions"] = ", ".join(specifications.keys())
    return actions

def create_robot(name, origin, scale=1.0, pose="Idle", facing=0.0, approval=False, full_action_set=False):
    robot_collection = bpy.data.collections.new(name + " Character")
    character_root.children.link(robot_collection)
    armature = create_armature(name, origin, scale, robot_collection)

    def wp(local):
        return (
            origin[0] + local[0] * scale,
            origin[1] + local[1] * scale,
            origin[2] + local[2] * scale,
        )

    # Core shell
    pelvis = add_box(name + "_Pelvis", wp((0, 0, 0.72)), (0.92*scale, 0.62*scale, 0.38*scale), MAT_DARK, robot_collection, bevel=0.11*scale)
    torso = add_box(name + "_Torso", wp((0, 0, 1.18)), (1.16*scale, 0.72*scale, 0.78*scale), MAT_SHELL, robot_collection, bevel=0.18*scale)
    chest = add_box(name + "_Chest_Panel", wp((0, -0.38, 1.20)), (0.52*scale, 0.08*scale, 0.40*scale), MAT_DARK, robot_collection, bevel=0.07*scale)
    chest_line = add_box(name + "_Chest_Action_Inlay", wp((0, -0.43, 1.20)), (0.11*scale, 0.035*scale, 0.28*scale), MAT_ACCENT, robot_collection, bevel=0.025*scale)
    backpack = add_box(name + "_Backpack", wp((0, 0.43, 1.17)), (0.70*scale, 0.26*scale, 0.56*scale), MAT_DARK, robot_collection, bevel=0.12*scale)

    parent_to_bone(pelvis, armature, "pelvis")
    for obj in (torso, chest, chest_line, backpack):
        parent_to_bone(obj, armature, "spine")

    # Head, visor, eyes, antenna
    head = add_sphere(name + "_Head", wp((0, 0, 1.88)), (0.63*scale, 0.50*scale, 0.50*scale), MAT_SHELL_LIGHT, robot_collection)
    visor = add_box(name + "_Visor", wp((0, -0.44, 1.88)), (1.02*scale, 0.15*scale, 0.46*scale), MAT_VISOR, robot_collection, bevel=0.16*scale)
    eye_left = add_sphere(name + "_Eye_L", wp((0.23, -0.535, 1.91)), (0.085*scale, 0.045*scale, 0.09*scale), MAT_EYE, robot_collection, segments=16, rings=8)
    eye_right = add_sphere(name + "_Eye_R", wp((-0.23, -0.535, 1.91)), (0.085*scale, 0.045*scale, 0.09*scale), MAT_EYE, robot_collection, segments=16, rings=8)
    antenna = add_cylinder(name + "_Antenna", wp((0, 0, 2.39)), 0.055*scale, 0.30*scale, MAT_DARK, robot_collection, vertices=12)
    antenna_tip = add_sphere(name + "_Antenna_Tip", wp((0, 0, 2.57)), (0.11*scale, 0.11*scale, 0.11*scale), MAT_WARNING if approval else MAT_EYE, robot_collection, segments=12, rings=6)
    for obj in (head, visor, eye_left, eye_right, antenna, antenna_tip):
        parent_to_bone(obj, armature, "head")

    # Arms and hands
    for side, sign in (("L", 1.0), ("R", -1.0)):
        upper = add_cylinder(name + "_UpperArm_" + side, wp((0.70*sign, 0, 1.30)), 0.17*scale, 0.56*scale, MAT_SHELL, robot_collection, rotation=(0, math.radians(90), 0), vertices=16)
        elbow = add_sphere(name + "_Elbow_" + side, wp((0.92*sign, -0.03, 1.14)), (0.19*scale, 0.19*scale, 0.19*scale), MAT_JOINT, robot_collection, segments=16, rings=8)
        forearm = add_cylinder(name + "_Forearm_" + side, wp((1.05*sign, -0.07, 1.02)), 0.15*scale, 0.45*scale, MAT_SHELL_LIGHT, robot_collection, rotation=(0, math.radians(90), 0), vertices=16)
        hand = add_sphere(name + "_Hand_" + side, wp((1.26*sign, -0.10, 0.92)), (0.18*scale, 0.16*scale, 0.17*scale), MAT_JOINT, robot_collection, segments=16, rings=8)
        parent_to_bone(upper, armature, "upper_arm." + side)
        parent_to_bone(elbow, armature, "forearm." + side)
        parent_to_bone(forearm, armature, "forearm." + side)
        parent_to_bone(hand, armature, "hand." + side)

    # Legs and feet
    for side, sign in (("L", 1.0), ("R", -1.0)):
        hip = add_sphere(name + "_Hip_" + side, wp((0.28*sign, 0, 0.62)), (0.20*scale, 0.20*scale, 0.20*scale), MAT_JOINT, robot_collection, segments=16, rings=8)
        thigh = add_cylinder(name + "_Thigh_" + side, wp((0.29*sign, 0, 0.40)), 0.18*scale, 0.48*scale, MAT_SHELL, robot_collection, vertices=16)
        knee = add_sphere(name + "_Knee_" + side, wp((0.30*sign, -0.02, 0.18)), (0.18*scale, 0.18*scale, 0.18*scale), MAT_JOINT, robot_collection, segments=16, rings=8)
        shin = add_cylinder(name + "_Shin_" + side, wp((0.30*sign, 0, -0.02)), 0.16*scale, 0.42*scale, MAT_SHELL_LIGHT, robot_collection, vertices=16)
        foot = add_box(name + "_Foot_" + side, wp((0.30*sign, -0.13, -0.23)), (0.42*scale, 0.62*scale, 0.22*scale), MAT_DARK, robot_collection, bevel=0.08*scale)
        parent_to_bone(hip, armature, "thigh." + side)
        parent_to_bone(thigh, armature, "thigh." + side)
        parent_to_bone(knee, armature, "shin." + side)
        parent_to_bone(shin, armature, "shin." + side)
        parent_to_bone(foot, armature, "foot." + side)

    # Underfoot state marker uses shape plus color.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.82*scale, minor_radius=0.055*scale, major_segments=40, minor_segments=8, location=wp((0, 0, -0.32)))
    state_ring = bpy.context.object
    state_ring.name = name + "_State_Ring"
    state_ring.data.materials.append(MAT_WARNING if approval else MAT_ACCENT)
    move_to_collection(state_ring, robot_collection)

    actions = create_actions(armature, name)
    armature.rotation_euler[2] = facing
    if pose in actions:
        armature.animation_data.action = actions[pose]
    scene.frame_set(12 if pose in ("Typing", "Testing") else 16)
    armature["role"] = "root" if scale >= 0.9 else "subagent"
    armature["current_visual_state"] = pose
    robot_collection["modular_character"] = True
    robot_collection["rig_type"] = "mechanical rigid-bone armature"
    return armature

# Root session and two subagents in DockMagic.
dock_root = create_robot("FactoryWorker_Root", (-5.35, 2.15, 0.62), 1.0, "Thinking", 0.0, False, True)
planner = create_robot("FactoryWorker_Planner", (-7.45, 5.55, 0.56), 0.72, "Typing", math.radians(-18), False)
tester = create_robot("FactoryWorker_Tester", (-3.20, 5.65, 0.56), 0.72, "Testing", math.radians(16), False)

# Additional workers prove that one modular design scales across departments.
benagent = create_robot("FactoryWorker_BenAgent", (5.20, 2.35, 0.60), 0.92, "Typing", 0.0, False)
website = create_robot("FactoryWorker_Website", (-5.35, -8.05, 0.60), 0.92, "Testing", 0.0, False)
cli = create_robot("FactoryWorker_CLI", (5.20, -8.00, 0.60), 0.92, "WaitingApproval", 0.0, True)

character_root["character_style"] = "friendly compact industrial robot"
character_root["state_system"] = "pose + shape + localized semantic light"
character_root["recommended_runtime"] = "Blender orthographic sprites / SpriteKit"

camera = bpy.data.objects.get("Factory_Orthographic_Camera")
if camera is None:
    raise RuntimeError("Factory camera missing")

def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

# Full factory render.
camera.location = (24.0, -29.0, 25.0)
camera.data.ortho_scale = 31.5
look_at(camera, (0.0, 0.0, 1.1))
scene.camera = camera
scene.render.filepath = FINAL_PREVIEW
bpy.ops.wm.save_as_mainfile(filepath=FINAL_BLEND)
bpy.ops.render.render(write_still=True)

# Close character review from a three-quarter angle.
camera.location = (1.0, -7.0, 10.0)
camera.data.ortho_scale = 9.2
look_at(camera, (-5.35, 4.10, 1.30))
scene.render.filepath = CHAR_PREVIEW
bpy.ops.render.render(write_still=True)

# Side/alternate character review angle.
camera.location = (-13.0, -0.5, 7.0)
camera.data.ortho_scale = 7.8
look_at(camera, (-5.35, 4.10, 1.25))
scene.render.filepath = CHAR_SIDE_PREVIEW
bpy.ops.render.render(write_still=True)

# Restore the production view and persist it.
camera.location = (24.0, -29.0, 25.0)
camera.data.ortho_scale = 31.5
look_at(camera, (0.0, 0.0, 1.1))
scene.render.filepath = FINAL_PREVIEW
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=FINAL_BLEND)
print("FACTORY_CHARACTERS_COMPLETE", FINAL_BLEND, FINAL_PREVIEW, CHAR_PREVIEW, CHAR_SIDE_PREVIEW)
