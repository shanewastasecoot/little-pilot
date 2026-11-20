class_name DeliveryBeacon
extends Node3D
## A tall soft column of light over where a parcel should go (seen from the
## air, from far away) with a big puffy heart turning above the spot (seen
## on foot). A heart, not a parcel: only parcels you can pick up look like
## parcels. One unshaded see-through mesh plus the parcel: two draw calls.

const HEIGHT := 170.0
const RADIUS := 7.0

## The heart over the spot (off for beacons over the plane or a post
## office).
@export var show_parcel := true
## Use the colour exactly as given (on for white/grey beacons), instead of
## a bold version of it.
@export var exact_colour := false
var colour := Color("ffd23f"):
	set(v):
		# A bold version of their colour: pale colours vanish on grass and sky.
		colour = v if exact_colour else Color.from_hsv(v.h, maxf(v.s, 0.8), 1.0)
		if _mat:
			_mat.set_shader_parameter("colour", colour)
var _mat: ShaderMaterial
var _column: MeshInstance3D
## Close by on foot: hide the column (it would cover them) and keep the
## little spinning parcel over their head.
var near := false:
	set(v):
		near = v
		if _column:
			_column.visible = not v
var _parcel: Node3D
var _t := 0.0

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 colour : source_color = vec4(1.0, 0.82, 0.25, 1.0);
void fragment() {
	// UV.y runs 0 at the top to 1 at the bottom of a CylinderMesh.
	float up = 1.0 - UV.y;
	float fade = 1.0 - up * 0.65;
	// Bands of light drifting up the column, and a brighter rim.
	float bands = 0.8 + 0.2 * sin(up * 46.0 - TIME * 3.0);
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = mix(colour.rgb, vec3(1.0), 0.1 * bands);
	ALPHA = clamp(fade * bands * (0.75 + 0.25 * edge), 0.0, 0.92);
}
"""


func _ready() -> void:
	var col := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = RADIUS * 0.6
	m.bottom_radius = RADIUS
	m.height = HEIGHT
	m.radial_segments = 16
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	col.mesh = m
	col.position.y = HEIGHT * 0.5
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("colour", colour)
	col.material_override = _mat
	add_child(col)
	_column = col
	if show_parcel:
		_parcel = CharacterLook.prop("Heart_Marker")
		_parcel.scale = Vector3.ONE * 3.2
		_parcel.position.y = 8.5
		add_child(_parcel)


func _process(delta: float) -> void:
	if not visible or _parcel == null:
		return
	_t += delta
	_parcel.rotation.y = _t * 1.4
	_parcel.position.y = 8.5 + sin(_t * 2.5) * 0.5
