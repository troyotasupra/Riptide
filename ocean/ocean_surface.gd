class_name OceanSurface
extends Node3D
## The sea: a detailed wave mesh that follows the camera, plus a flat, coarse
## far sea out to the horizon so distant islands never sit over empty sky.
## Waves are computed from world position in the shader, so moving the meshes
## never moves the water.

const NEAR_SIZE := 800.0
const NEAR_STEP := 2.0
const FAR_SIZE := 8000.0
const FAR_STEP := 100.0
## The far sea sits below the wave troughs so it never pokes through the near mesh.
const FAR_DEPTH := -2.5
const MAX_HULLS := 4  # must match water.gdshader

var _near: MeshInstance3D
var _far: MeshInstance3D
var _near_material: ShaderMaterial


func _ready() -> void:
	name = "Ocean"
	_near_material = _make_material(1.0)
	_near = _make_plane(NEAR_SIZE, NEAR_STEP, _near_material)
	_far = _make_plane(FAR_SIZE, FAR_STEP, _make_material(0.0))
	add_child(_near)
	add_child(_far)
	visible = not GameState.hide_ocean


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		var p := camera.global_position
		_near.global_position = Vector3(snappedf(p.x, NEAR_STEP), 0.0, snappedf(p.z, NEAR_STEP))
		_far.global_position = Vector3(snappedf(p.x, FAR_STEP), FAR_DEPTH, snappedf(p.z, FAR_STEP))
	_near_material.set_shader_parameter("wave_time", Ocean.time)
	_near_material.set_shader_parameter("storm", Waves.storm)
	_update_hull_masks()


## Tells the water shader which hull interiors to leave dry.
func _update_hull_masks() -> void:
	var inverses: Array[Projection] = []
	var mins := PackedVector3Array()
	var maxs := PackedVector3Array()
	for boat: Boat in get_tree().get_nodes_in_group("boats"):
		if boat.water_mask.size == Vector3.ZERO or inverses.size() >= MAX_HULLS:
			continue
		inverses.append(Projection(boat.get_global_transform_interpolated().affine_inverse()))
		mins.append(boat.water_mask.position)
		maxs.append(boat.water_mask.end)
	var count := inverses.size()
	while inverses.size() < MAX_HULLS:
		inverses.append(Projection.IDENTITY)
		mins.append(Vector3.ZERO)
		maxs.append(Vector3.ZERO)
	_near_material.set_shader_parameter("hull_count", count)
	_near_material.set_shader_parameter("hull_world_to_local", inverses)
	_near_material.set_shader_parameter("hull_min", mins)
	_near_material.set_shader_parameter("hull_max", maxs)


static func _make_material(wave_scale: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://ocean/water.gdshader")
	material.set_shader_parameter("wave_scale", wave_scale)
	return material


static func _make_plane(size: float, step: float, material: ShaderMaterial) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = int(size / step) - 1
	plane.subdivide_depth = int(size / step) - 1
	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.material_override = material
	instance.extra_cull_margin = 16.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return instance
