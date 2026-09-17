class_name ScopeView
extends Control
## Looking through a magnified optic. The world is drawn a second time from the
## lens, at the optic's magnification, into a round sight picture with the rest
## of the screen blacked out. It only runs while you're actually looking through
## a scope, because drawing the world twice isn't free.

## The sight picture is this fraction of the screen's height across.
const RADIUS := 0.34
## How big the second render is. Square, so the circle stays honest.
const RESOLUTION := 900

var zoom := 1.0

var _viewport: SubViewport
var _camera: Camera3D
var _glass: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(RESOLUTION, RESOLUTION)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.handle_input_locally = false
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.current = true
	_viewport.add_child(_camera)

	var shader := Shader.new()
	shader.code = _SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("scope_image", _viewport.get_texture())
	material.set_shader_parameter("radius", RADIUS)
	_glass = ColorRect.new()
	_glass.material = material
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glass)
	_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Shows the sight picture at `magnification`, or hides it at 1.
func look_through(magnification: float) -> void:
	var wanted := magnification > 1.5
	if wanted != visible:
		visible = wanted
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if wanted else SubViewport.UPDATE_DISABLED
	zoom = magnification
	if not wanted:
		return
	_viewport.world_3d = get_viewport().find_world_3d()
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_camera.global_transform = camera.global_transform
		_camera.fov = clampf(Settings.fov / magnification, 1.0, 120.0)
		_camera.near = camera.near
		_camera.far = camera.far
	var size := get_viewport_rect().size
	_glass.material.set_shader_parameter("aspect", size.x / maxf(1.0, size.y))
	_glass.material.set_shader_parameter("magnification", magnification)


const _SHADER := """
shader_type canvas_item;
// The sight picture: the scope's own render inside a circle, everything else black.

uniform sampler2D scope_image : filter_linear;
uniform float radius = 0.34;
uniform float aspect = 1.777;
uniform float magnification = 4.0;

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * aspect, UV.y - 0.5);
	float d = length(p);
	if (d > radius) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 lens = (p / radius) * 0.5 + 0.5;
		vec3 image = texture(scope_image, lens).rgb;
		// Crosshair, with hash marks down the vertical for holding over at distance.
		float thin = radius * 0.004;
		float cross = step(abs(p.x), thin) * step(radius * 0.06, abs(p.y))
			+ step(abs(p.y), thin) * step(radius * 0.06, abs(p.x));
		float marks = 0.0;
		for (int i = 1; i < 5; i++) {
			float at = radius * 0.16 * float(i);
			marks += step(abs(p.y - at), thin * 1.2) * step(abs(p.x), radius * 0.05 / float(i));
		}
		float dot_middle = 1.0 - step(thin * 1.6, d);
		image = mix(image, vec3(0.02, 0.02, 0.02), clamp(cross + marks + dot_middle, 0.0, 1.0));
		// The edge of the glass darkens, and the tube shadows the rim.
		float edge = smoothstep(radius * 0.86, radius, d);
		image = mix(image, vec3(0.0), edge);
		COLOR = vec4(image, 1.0);
	}
}
"""
