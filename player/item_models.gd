class_name ItemModels
extends RefCounted
## Detailed low-poly models of every item, used in the hand, in the world, and
## photographed for inventory icons. Grip (or natural base) at the origin; long
## items point along +Y.

const STEEL := Color(0.72, 0.74, 0.77)
const DARK_STEEL := Color(0.18, 0.19, 0.21)
const WOOD := Color(0.52, 0.37, 0.22)
const PALE_WOOD := Color(0.70, 0.64, 0.55)
const BARK := Color(0.36, 0.27, 0.18)
const LEATHER := Color(0.34, 0.22, 0.13)
const ROPE := Color(0.74, 0.65, 0.47)
const PAPER := Color(0.90, 0.86, 0.74)
const BRASS := Color(0.80, 0.64, 0.28)
## Gun finishes: worn gunmetal, black parkerising, polymer furniture, oiled wood.
const GUNMETAL := Color(0.26, 0.27, 0.29)
const PARKER := Color(0.14, 0.145, 0.15)
const POLYMER := Color(0.17, 0.18, 0.17)
const GUN_WOOD := Color(0.34, 0.21, 0.12)


## Guns come from the CC0 model pack (assets/models/guns) when it's there:
## file, real length (m), which way the barrel points in the file, where the grip is,
## and where the left hand holds the handguard (0 = grip, 1 = muzzle).
const GUN_MODELS := {
	"m1911": ["guns/pistol.glb", 0.216, 1.0, 0.2, 0.3],
	"uzi": ["guns/smg.glb", 0.47, 1.0, 0.42, 0.35],
	"m4": ["guns/assault_rifle.glb", 0.84, 1.0, 0.33, 0.4],
	"mossberg": ["guns/shotgun.glb", 1.0, 1.0, 0.3, 0.45],
	"intervention": ["guns/sniper.glb", 1.27, 1.0, 0.3, 0.3],
}


## Where on a gun model things attach (muzzle, rail, grip), in the model's own space.
static func anchor(model: Node3D, name: String, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	return model.get_meta(name, fallback) if model != null and model.has_meta(name) else fallback


static func build(id: String) -> Node3D:
	if GUN_MODELS.has(id) and ModelLib.exists(GUN_MODELS[id][0]):
		var spec: Array = GUN_MODELS[id]
		var anchors := {}
		var gun := ModelLib.gun(spec[0], spec[1], spec[2], spec[3], anchors, spec[4])
		gun.name = "Item_" + id
		for key: String in anchors:
			gun.set_meta(key, anchors[key])
		return gun
	var root := Node3D.new()
	root.name = "Item_" + id
	match id:
		"knife":
			_knife(root)
		"machete":
			_machete(root)
		"dagger":
			_dagger(root)
		"bow":
			_bow(root)
		"arrow":
			_arrow(root, Vector3.ZERO)
		"outboard_motor":
			_outboard(root)
		"fuel_drum":
			_fuel_drum(root)
		"stone_hatchet":
			_cylinder(root, 0.018, 0.5, Vector3(0.0, 0.12, 0.0), Materials.wood(WOOD), Vector3.ZERO, 0.022)
			_rock(root, 3, Vector3(0.07, 0.1, 0.19), Vector3(0.0, 0.34, -0.05), Materials.stone(Color(0.28, 0.28, 0.31)))
			# Cord lashing wound tight around the head and handle.
			var wrap := PackedVector3Array()
			var wrap_r := PackedFloat32Array()
			for k in 36:
				var a := k * 0.75
				wrap.append(Vector3(cos(a) * 0.027, 0.3 + k * 0.0026, sin(a) * 0.027))
				wrap_r.append(0.0055)
			var lashing := MeshInstance3D.new()
			lashing.mesh = MeshKit.tube(wrap, wrap_r, 5, "hatchet_lashing")
			lashing.material_override = Materials.cloth(ROPE)
			root.add_child(lashing)
		"torch":
			_cylinder(root, 0.02, 0.46, Vector3(0.0, 0.12, 0.0), Materials.wood(WOOD), Vector3.ZERO, 0.017)
			_cylinder(root, 0.034, 0.1, Vector3(0.0, 0.38, 0.0), Materials.cloth(Color(0.35, 0.30, 0.25)))
			_flame(root, Vector3(0.0, 0.47, 0.0), 0.06)
		"canteen", "canteen_clean", "canteen_dirty":
			var body := MeshInstance3D.new()
			body.mesh = _unit_sphere()
			body.material_override = Materials.cloth(Color(0.32, 0.38, 0.28))
			body.scale = Vector3(0.14, 0.2, 0.07)
			body.position.y = 0.08
			root.add_child(body)
			_cylinder(root, 0.018, 0.035, Vector3(0.0, 0.19, 0.0), Materials.metal(DARK_STEEL, 0.5))
			_torus(root, 0.08, 0.006, Vector3(0.0, 0.08, 0.0), Materials.leather(LEATHER), Vector3(PI / 2.0, 0.0, 0.0))
			if id != "canteen":
				_box(root, Vector3(0.05, 0.04, 0.002), Vector3(0.0, 0.07, -0.037), Materials.plain(Color(0.2, 0.55, 0.9) if id == "canteen_clean" else Color(0.55, 0.45, 0.25)))
		"lighter":
			var shell := MeshInstance3D.new()
			shell.mesh = _unit_sphere()
			shell.material_override = Materials.plain(Color(0.80, 0.16, 0.14), 0.3)
			shell.scale = Vector3(0.028, 0.065, 0.016)
			root.add_child(shell)
			_box(root, Vector3(0.022, 0.014, 0.012), Vector3(0.0, 0.036, 0.0), Materials.metal(STEEL))
			# Its flame: held, it's lit.
			_flame(root, Vector3(0.0, 0.05, 0.0), 0.014)
		"fishing_rod":
			_fishing_rod(root)
		"oar":
			var shaft := MeshInstance3D.new()
			shaft.mesh = MeshKit.tube(PackedVector3Array([Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.7, 0.0), Vector3(0.0, 1.3, 0.0)]), PackedFloat32Array([0.024, 0.022, 0.02]), 8, "oar_shaft")
			shaft.material_override = Materials.wood(PALE_WOOD)
			root.add_child(shaft)
			_box(root, Vector3(0.15, 0.48, 0.02), Vector3(0.0, 1.52, 0.0), Materials.wood(PALE_WOOD.darkened(0.08)))
			_torus(root, 0.027, 0.008, Vector3(0.0, 0.55, 0.0), Materials.cloth(ROPE))
			_capsule(root, 0.03, 0.16, Vector3(0.0, -0.02, 0.0), Materials.wood(WOOD))
		"raft_kit":
			for i in 3:
				var pole := MeshInstance3D.new()
				pole.mesh = MeshKit.branch(70 + i, 0.9, 0.035, 0.03, 0.05, 5)
				pole.material_override = Materials.bark(BARK)
				pole.rotation = Vector3(0.0, 0.0, PI / 2.0)
				pole.position = Vector3(0.45, 0.04 + (i % 2) * 0.06, (i - 1) * 0.07)
				root.add_child(pole)
			for x: float in [-0.25, 0.25]:
				_torus(root, 0.12, 0.012, Vector3(x, 0.07, 0.0), Materials.cloth(ROPE), Vector3(0.0, 0.0, PI / 2.0), Vector3(1.0, 1.0, 0.6))
		"spear":
			_cylinder(root, 0.018, 1.5, Vector3(0.0, 0.45, 0.0), Materials.wood(PALE_WOOD), Vector3.ZERO, 0.02)
			_rock(root, 5, Vector3(0.05, 0.17, 0.02), Vector3(0.0, 1.27, 0.0), Materials.stone(Color(0.25, 0.25, 0.28)))
			for y: float in [1.16, 1.19]:
				_torus(root, 0.022, 0.007, Vector3(0.0, y, 0.0), Materials.cloth(ROPE))
		"m1911", "flare_gun":
			# 216 mm long, 135 mm tall. Slide, frame and grip drawn from the side.
			var flare := id == "flare_gun"
			var pistol_body := Materials.gun_steel(PARKER if not flare else Color(0.75, 0.32, 0.06), 0.42)
			var pistol_steel := Materials.gun_steel(GUNMETAL, 0.38)
			_profile(root, [
				Vector2(-0.008, 0.044), Vector2(0.148, 0.044), Vector2(0.162, 0.056), Vector2(0.162, 0.08),
				Vector2(0.04, 0.088), Vector2(-0.008, 0.086),
			], 0.032, pistol_steel, "m1911_slide")
			_profile(root, [
				Vector2(-0.006, 0.046), Vector2(0.126, 0.046), Vector2(0.126, 0.024), Vector2(0.058, 0.02),
				Vector2(0.052, 0.002), Vector2(0.026, 0.0), Vector2(0.014, 0.022), Vector2(-0.006, 0.024),
			], 0.03, pistol_body, "m1911_frame")
			_profile(root, [
				Vector2(0.016, 0.026), Vector2(-0.014, 0.022), Vector2(-0.05, -0.092), Vector2(-0.022, -0.112),
				Vector2(0.026, -0.1), Vector2(0.038, -0.004),
			], 0.032, pistol_body, "m1911_grip")
			for side: float in [-1.0, 1.0]:
				_profile(root, [
					Vector2(0.012, 0.014), Vector2(-0.012, 0.012), Vector2(-0.044, -0.086), Vector2(-0.02, -0.1),
					Vector2(0.022, -0.09), Vector2(0.03, -0.004),
				], 0.005, Materials.gun_wood(Color(0.32, 0.20, 0.12)) if not flare else Materials.plain(Color(0.2, 0.2, 0.22), 0.8)).position.x = side * 0.018
			_grooves(root, 7, 0.01, 0.042, 0.082, 0.034, 0.03, Materials.gun_steel(PARKER.darkened(0.3), 0.6))
			_tube_along(root, 0.012 if not flare else 0.02, 0.15, 0.176, 0.062, pistol_steel)
			_tube_along(root, 0.0075 if not flare else 0.017, 0.155, 0.184, 0.062, Materials.gun_steel(DARK_STEEL, 0.32))
			_span(root, 0.012, 0.004, 0.028, 0.082, 0.098, pistol_steel)
			_span(root, 0.009, 0.03, 0.05, 0.004, 0.026, Materials.gun_steel(PARKER, 0.5))
			_torus(root, 0.021, 0.0035, Vector3(0.0, 0.038, 0.0), pistol_body, Vector3(0.0, 0.0, PI / 2.0), Vector3(1.0, 1.0, 0.75))
			_sight(root, 0.146, 0.086, true, pistol_steel)
			_sight(root, 0.004, 0.086, false, pistol_steel)
		"uzi":
			# Stamped box receiver, grip-fed magazine, folding stock alongside.
			var uzi_metal := Materials.gun_steel(PARKER, 0.48)
			var uzi_steel := Materials.gun_steel(GUNMETAL, 0.4)
			var uzi_polymer := Materials.gun_polymer(POLYMER)
			_profile(root, [
				Vector2(-0.055, 0.004), Vector2(0.195, 0.004), Vector2(0.2, 0.086), Vector2(0.135, 0.092),
				Vector2(0.128, 0.104), Vector2(0.09, 0.104), Vector2(0.084, 0.092), Vector2(-0.05, 0.088),
			], 0.056, uzi_metal, "uzi_body")
			_profile(root, [
				Vector2(0.072, 0.014), Vector2(0.006, 0.014), Vector2(-0.004, -0.09), Vector2(0.018, -0.104),
				Vector2(0.074, -0.096), Vector2(0.084, -0.006),
			], 0.05, uzi_polymer, "uzi_grip")
			_profile(root, [
				Vector2(0.062, -0.07), Vector2(0.018, -0.074), Vector2(0.008, -0.22), Vector2(0.056, -0.226),
			], 0.036, uzi_metal, "uzi_mag")
			_grooves(root, 6, 0.02, 0.17, 0.086, 0.058, 0.014, Materials.gun_steel(PARKER.darkened(0.28), 0.6))
			_tube_along(root, 0.015, 0.185, 0.268, 0.048, uzi_steel)
			_tube_along(root, 0.0095, 0.25, 0.315, 0.048, Materials.gun_steel(DARK_STEEL, 0.35))
			_span(root, 0.026, 0.058, 0.096, 0.086, 0.106, uzi_steel)
			_span(root, 0.006, 0.08, 0.15, 0.03, 0.062, Materials.gun_steel(PARKER.darkened(0.4), 0.6)).position.x = 0.028
			_torus(root, 0.023, 0.0035, Vector3(0.0, 0.03, 0.0), uzi_metal, Vector3(0.0, 0.0, PI / 2.0), Vector3(1.0, 1.0, 0.7))
			_sight(root, 0.185, 0.1, true, uzi_steel)
			_sight(root, 0.0, 0.09, false, uzi_steel)
			for side: float in [-1.0, 1.0]:
				_span(root, 0.012, -0.2, -0.04, 0.052, 0.066, uzi_steel).position.x = side * 0.032
			_span(root, 0.078, -0.226, -0.2, 0.026, 0.09, uzi_polymer)
		"m4":
			# 840 mm carbine. The body, grip, magazine and stock are drawn as side
			# profiles, so the magwell slopes and the stock has a comb.
			var rifle_metal := Materials.gun_steel(PARKER, 0.42)
			var rifle_steel := Materials.gun_steel(GUNMETAL, 0.38)
			var furniture := Materials.gun_polymer(POLYMER)
			_profile(root, [
				Vector2(-0.03, 0.152), Vector2(0.272, 0.152), Vector2(0.272, 0.094), Vector2(0.206, 0.094),
				Vector2(0.206, 0.028), Vector2(0.158, 0.006), Vector2(0.088, 0.006), Vector2(0.058, 0.042),
				Vector2(-0.03, 0.042),
			], 0.046, rifle_metal, "m4_body")
			_profile(root, [
				Vector2(0.062, 0.044), Vector2(0.012, 0.044), Vector2(-0.028, -0.078), Vector2(0.004, -0.118),
				Vector2(0.046, -0.104), Vector2(0.052, -0.02), Vector2(0.076, -0.004),
			], 0.042, furniture, "m4_grip")
			_profile(root, [
				Vector2(0.2, 0.03), Vector2(0.152, 0.03), Vector2(0.118, -0.1), Vector2(0.134, -0.178),
				Vector2(0.186, -0.19), Vector2(0.212, -0.06),
			], 0.031, rifle_metal, "m4_mag")
			_profile(root, [
				Vector2(-0.026, 0.15), Vector2(-0.08, 0.148), Vector2(-0.152, 0.134), Vector2(-0.206, 0.128),
				Vector2(-0.21, 0.064), Vector2(-0.148, 0.074), Vector2(-0.086, 0.062), Vector2(-0.026, 0.058),
			], 0.046, furniture, "m4_stock")
			_tube_along(root, 0.019, -0.19, -0.02, 0.113, rifle_steel)
			_span(root, 0.05, -0.222, -0.206, 0.058, 0.132, Materials.gun_polymer(PARKER.darkened(0.2)))
			# Rails, ejection port and charging handle.
			_rail(root, -0.02, 0.27, 0.158, 0.032)
			_span(root, 0.006, 0.14, 0.212, 0.104, 0.136, Materials.gun_steel(PARKER.darkened(0.4), 0.6)).position.x = 0.024
			_span(root, 0.03, -0.058, -0.022, 0.116, 0.142, rifle_steel)
			_torus(root, 0.024, 0.0035, Vector3(0.0, 0.05, 0.018), Materials.gun_steel(PARKER, 0.5), Vector3(0.0, 0.0, PI / 2.0), Vector3(1.0, 1.0, 0.7))
			_span(root, 0.009, 0.05, 0.075, 0.02, 0.046, Materials.gun_steel(PARKER, 0.5))
			# Handguard over the barrel, gas block, barrel, flash hider.
			_tube_along(root, 0.032, 0.256, 0.5, 0.122, furniture)
			_rail(root, 0.27, 0.49, 0.156, 0.03)
			_span(root, 0.03, 0.492, 0.532, 0.122, 0.17, rifle_steel)
			_tube_along(root, 0.0115, 0.45, 0.79, 0.122, Materials.gun_steel(DARK_STEEL, 0.34))
			_tube_along(root, 0.017, 0.772, 0.836, 0.122, rifle_steel)
			_grooves(root, 3, 0.785, 0.825, 0.142, 0.036, 0.014, Materials.gun_steel(DARK_STEEL, 0.5))
			_sight(root, 0.505, 0.168, true, rifle_steel)
			_sight(root, -0.005, 0.162, false, rifle_steel)
		"mossberg":
			# A metre of pump gun: barrel over its tube, and one piece of walnut.
			var shotgun_steel := Materials.gun_steel(GUNMETAL.darkened(0.12), 0.38)
			var shotgun_black := Materials.gun_steel(PARKER, 0.48)
			var wood := Materials.gun_wood(GUN_WOOD)
			_profile(root, [
				Vector2(-0.02, 0.014), Vector2(0.21, 0.014), Vector2(0.215, 0.09), Vector2(-0.02, 0.094),
			], 0.05, shotgun_black, "mossberg_body")
			# Wrist, comb and butt in one outline, with the drop a shotgun has.
			_profile(root, [
				Vector2(-0.018, 0.094), Vector2(-0.08, 0.086), Vector2(-0.18, 0.062), Vector2(-0.285, 0.05),
				Vector2(-0.3, -0.028), Vector2(-0.21, -0.012), Vector2(-0.11, 0.012), Vector2(-0.04, 0.016),
				Vector2(-0.018, 0.03),
			], 0.052, wood, "mossberg_stock")
			_span(root, 0.056, -0.318, -0.298, -0.03, 0.052, Materials.gun_polymer(PARKER.darkened(0.2)))
			_span(root, 0.006, 0.05, 0.13, 0.03, 0.07, Materials.gun_steel(PARKER.darkened(0.4), 0.6)).position.x = 0.026
			_tube_along(root, 0.019, 0.19, 0.77, 0.072, shotgun_steel)
			_tube_along(root, 0.015, 0.19, 0.64, 0.028, shotgun_steel)
			_sphere(root, 0.006, Vector3(0.0, 0.762, 0.093), Materials.plain(Color(0.9, 0.85, 0.4), 0.3))
			_tube_along(root, 0.03, 0.36, 0.53, 0.028, wood)
			_grooves(root, 7, 0.375, 0.515, 0.058, 0.056, 0.018, Materials.gun_wood(GUN_WOOD.darkened(0.25)))
			_span(root, 0.009, 0.03, 0.055, 0.0, 0.016, Materials.gun_steel(PARKER, 0.5))
			_torus(root, 0.024, 0.0035, Vector3(0.0, 0.042, 0.012), shotgun_black, Vector3(0.0, 0.0, PI / 2.0), Vector3(1.0, 1.0, 0.7))
		"intervention":
			# 1.27 m bolt gun: heavy fluted barrel, chassis stock with a cut-out.
			var sniper_black := Materials.gun_steel(PARKER, 0.4)
			var sniper_steel := Materials.gun_steel(GUNMETAL.darkened(0.08), 0.36)
			var chassis := Materials.gun_polymer(Color(0.30, 0.32, 0.28))
			_profile(root, [
				Vector2(-0.04, 0.012), Vector2(0.28, 0.012), Vector2(0.3, 0.098), Vector2(-0.04, 0.1),
			], 0.055, sniper_black, "intervention_body")
			_profile(root, [
				Vector2(-0.035, 0.1), Vector2(-0.3, 0.096), Vector2(-0.315, 0.028), Vector2(-0.26, 0.032),
				Vector2(-0.235, 0.06), Vector2(-0.15, 0.062), Vector2(-0.12, 0.03), Vector2(-0.06, 0.012),
				Vector2(-0.035, 0.012),
			], 0.05, chassis, "intervention_stock")
			_span(root, 0.056, -0.335, -0.315, 0.024, 0.1, Materials.gun_polymer(PARKER.darkened(0.2)))
			_profile(root, [
				Vector2(0.062, 0.016), Vector2(0.004, 0.016), Vector2(-0.03, -0.1), Vector2(0.0, -0.122),
				Vector2(0.05, -0.11), Vector2(0.066, -0.01),
			], 0.044, chassis, "intervention_grip")
			_profile(root, [
				Vector2(0.196, 0.014), Vector2(0.142, 0.014), Vector2(0.138, -0.12), Vector2(0.194, -0.124),
			], 0.038, sniper_black, "intervention_mag")
			_rail(root, -0.02, 0.28, 0.102, 0.036)
			_tube_along(root, 0.021, 0.27, 0.93, 0.07, sniper_steel)
			for i in 4:
				var flute := i * TAU / 4.0 + 0.4
				var rib := _cylinder(root, 0.005, 0.5, Vector3(0.0, 0.62, 0.07 + sin(flute) * 0.019), Materials.gun_steel(GUNMETAL.darkened(0.3), 0.5))
				rib.position.x = cos(flute) * 0.019
			_tube_along(root, 0.028, 0.9, 1.0, 0.07, sniper_black)
			_grooves(root, 4, 0.915, 0.985, 0.096, 0.058, 0.016, Materials.gun_steel(DARK_STEEL, 0.5))
			var bolt := _cylinder(root, 0.011, 0.085, Vector3(0.045, 0.13, 0.062), sniper_steel)
			bolt.rotation.z = PI / 2.0 - 0.3
			_sphere(root, 0.013, Vector3(0.08, 0.108, 0.062), sniper_steel)
			_span(root, 0.01, 0.04, 0.07, 0.0, 0.016, Materials.gun_steel(PARKER, 0.5))
			_torus(root, 0.024, 0.0035, Vector3(0.0, 0.05, 0.012), sniper_black, Vector3(0.0, 0.0, PI / 2.0), Vector3(1.0, 1.0, 0.7))
		"red_dot", "holo_sight", "prism_3x", "lpvo_6x", "sniper_scope":
			var glass := Materials.glow(Color(0.35, 0.75, 0.95), 0.6)
			var housing := Materials.gun_steel(Color(0.15, 0.15, 0.16), 0.5)
			var long: bool = id in ["lpvo_6x", "sniper_scope"]
			var tube := 0.3 if id == "sniper_scope" else (0.24 if id == "lpvo_6x" else (0.12 if id == "prism_3x" else 0.07))
			var fat := 0.028 if long else 0.022
			_cylinder(root, fat, tube, Vector3(0.0, 0.05 + tube * 0.5, 0.0), housing, Vector3(PI / 2.0, 0.0, 0.0))
			_cylinder(root, fat * 1.25, 0.03, Vector3(0.0, 0.05 + tube, 0.0), housing, Vector3(PI / 2.0, 0.0, 0.0))
			_cylinder(root, fat * 1.1, 0.01, Vector3(0.0, 0.05, 0.0), glass, Vector3(PI / 2.0, 0.0, 0.0))
			_box(root, Vector3(0.03, 0.05, 0.05), Vector3(0.0, 0.03, 0.0), housing)
			if long:
				_cylinder(root, fat * 0.7, 0.02, Vector3(0.028, 0.05 + tube * 0.45, 0.0), housing, Vector3(0.0, 0.0, PI / 2.0))
		"suppressor", "compensator", "muzzle_brake":
			var can_metal := Materials.gun_steel(Color(0.13, 0.13, 0.14), 0.45)
			var length := 0.2 if id == "suppressor" else 0.07
			var girth := 0.026 if id == "suppressor" else 0.021
			_cylinder(root, girth, length, Vector3(0.0, length * 0.5, 0.0), can_metal)
			if id != "suppressor":
				for cut: float in [0.02, 0.04]:
					_box(root, Vector3(girth * 2.2, 0.006, girth * 1.2), Vector3(0.0, cut, 0.0), Materials.gun_steel(DARK_STEEL))
			else:
				for ring: float in [0.05, 0.1, 0.15]:
					_torus(root, girth, 0.003, Vector3(0.0, ring, 0.0), Materials.gun_steel(DARK_STEEL))
		"vertical_grip", "angled_grip":
			var grip_material := Materials.gun_polymer(Color(0.12, 0.12, 0.13))
			var handle := _box(root, Vector3(0.032, 0.11, 0.032), Vector3(0.0, 0.06, 0.0), grip_material)
			if id == "angled_grip":
				handle.rotation.x = 0.6
			_box(root, Vector3(0.04, 0.02, 0.05), Vector3(0.0, 0.01, 0.0), Materials.gun_steel(DARK_STEEL))
		"bipod":
			var leg_metal := Materials.gun_steel(Color(0.16, 0.16, 0.17), 0.5)
			_box(root, Vector3(0.04, 0.03, 0.06), Vector3(0.0, 0.02, 0.0), leg_metal)
			for side: float in [-1.0, 1.0]:
				var leg := _cylinder(root, 0.006, 0.16, Vector3(side * 0.03, 0.09, 0.0), leg_metal)
				leg.rotation.z = side * 0.35
		"extended_mag", "quickdraw_mag":
			var mag_metal := Materials.gun_steel(Color(0.14, 0.14, 0.15), 0.5)
			var tall := 0.2 if id == "extended_mag" else 0.12
			var mag := _box(root, Vector3(0.028, tall, 0.05), Vector3(0.0, tall * 0.5, 0.0), mag_metal)
			mag.rotation.x = 0.12
			_box(root, Vector3(0.03, 0.015, 0.052), Vector3(0.0, tall, 0.0), Materials.plain(Color(0.2, 0.2, 0.22), 0.7))
		"light_stock", "heavy_stock", "folding_stock":
			var stock_material := Materials.gun_polymer(Color(0.16, 0.17, 0.15))
			var depth := 0.16 if id == "heavy_stock" else 0.12
			_box(root, Vector3(0.045, 0.1, depth), Vector3(0.0, 0.1, 0.0), stock_material)
			_box(root, Vector3(0.03, 0.09, 0.05), Vector3(0.0, 0.03, -0.03), Materials.gun_steel(DARK_STEEL))
			if id == "folding_stock":
				_torus(root, 0.018, 0.004, Vector3(0.0, 0.05, -0.05), Materials.gun_steel(STEEL), Vector3(0.0, PI / 2.0, 0.0))
		"laser", "flashlight":
			var body_metal := Materials.gun_steel(Color(0.15, 0.15, 0.16), 0.5)
			_cylinder(root, 0.015, 0.08, Vector3(0.0, 0.05, 0.0), body_metal)
			_cylinder(root, 0.012, 0.008, Vector3(0.0, 0.09, 0.0),
				Materials.glow(Color(0.95, 0.15, 0.12) if id == "laser" else Color(1.0, 0.95, 0.8), 2.0))
			_box(root, Vector3(0.03, 0.02, 0.04), Vector3(0.0, 0.01, 0.0), body_metal)
		"cleaning_kit":
			_box(root, Vector3(0.12, 0.05, 0.07), Vector3(0.0, 0.03, 0.0), Materials.cloth(Color(0.32, 0.34, 0.30)))
			_cylinder(root, 0.004, 0.16, Vector3(0.03, 0.08, 0.0), Materials.gun_steel(STEEL), Vector3(0.0, 0.0, 0.2))
			_cylinder(root, 0.014, 0.04, Vector3(-0.03, 0.06, 0.0), Materials.plain(Color(0.45, 0.35, 0.2), 0.6))
		"survival_book", "logbook", "journal":
			var cover: Color = {"survival_book": Color(0.18, 0.34, 0.24), "logbook": Color(0.36, 0.22, 0.12), "journal": Color(0.45, 0.32, 0.18)}[id]
			_box(root, Vector3(0.15, 0.21, 0.035), Vector3(0.0, 0.1, 0.0), Materials.cloth(PAPER))
			for z: float in [-0.02, 0.02]:
				_box(root, Vector3(0.16, 0.22, 0.006), Vector3(0.005, 0.1, z), Materials.leather(cover))
			_box(root, Vector3(0.012, 0.22, 0.046), Vector3(-0.078, 0.1, 0.0), Materials.leather(cover.darkened(0.2)))
			if id == "logbook":
				_box(root, Vector3(0.02, 0.23, 0.05), Vector3(0.03, 0.1, 0.0), Materials.leather(LEATHER.darkened(0.3)))
		"peg_leg":
			_cylinder(root, 0.05, 0.1, Vector3(0.0, 0.62, 0.0), Materials.leather(LEATHER))
			_cylinder(root, 0.028, 0.6, Vector3(0.0, 0.3, 0.0), Materials.wood(WOOD), Vector3.ZERO, 0.02)
			for y: float in [0.5, 0.56]:
				_torus(root, 0.05, 0.006, Vector3(0.0, y, 0.0), Materials.cloth(ROPE))
		"hook_hand":
			_cylinder(root, 0.04, 0.14, Vector3(0.0, 0.07, 0.0), Materials.leather(LEATHER))
			_cylinder(root, 0.008, 0.08, Vector3(0.0, 0.18, 0.0), Materials.metal(DARK_STEEL, 0.5))
			_torus(root, 0.035, 0.008, Vector3(0.03, 0.24, 0.0), Materials.metal(DARK_STEEL, 0.5), Vector3(PI / 2.0, 0.0, 0.0))
		"book_page_shelter", "book_page_camp", "book_page_prosthetics":
			var page := _box(root, Vector3(0.14, 0.19, 0.003), Vector3(0.0, 0.09, 0.0), Materials.cloth(PAPER))
			page.rotation.z = 0.08
			for i in 5:
				_box(root, Vector3(0.1, 0.004, 0.001), Vector3(0.0, 0.14 - i * 0.022, -0.002), Materials.plain(Color(0.3, 0.3, 0.35)))
		"sea_chart":
			_cylinder(root, 0.03, 0.26, Vector3(0.0, 0.12, 0.0), Materials.cloth(PAPER))
			_torus(root, 0.032, 0.005, Vector3(0.0, 0.12, 0.0), Materials.cloth(Color(0.6, 0.12, 0.1)))
		"compartment_key":
			_torus(root, 0.018, 0.005, Vector3(0.0, 0.0, 0.0), Materials.metal(BRASS, 0.3), Vector3(PI / 2.0, 0.0, 0.0))
			_cylinder(root, 0.004, 0.06, Vector3(0.0, 0.05, 0.0), Materials.metal(BRASS, 0.3))
			for y: float in [0.065, 0.075]:
				_box(root, Vector3(0.012, 0.006, 0.004), Vector3(0.008, y, 0.0), Materials.metal(BRASS, 0.3))
		"coconut":
			_rock(root, 9, Vector3(0.15, 0.17, 0.15), Vector3(0.0, 0.08, 0.0), Materials.bark(Color(0.42, 0.28, 0.15)), 0.08, 1.0)
			for i in 3:
				_sphere(root, 0.012, Vector3(cos(i * TAU / 3.0) * 0.018, 0.16, sin(i * TAU / 3.0) * 0.018), Materials.plain(Color(0.12, 0.08, 0.05)))
		"berries", "red_berries", "dried_berries":
			var tone: Color = {"berries": Color(0.25, 0.18, 0.55), "red_berries": Color(0.85, 0.1, 0.12), "dried_berries": Color(0.30, 0.16, 0.22)}[id]
			var leaf := MeshInstance3D.new()
			leaf.mesh = MeshKit.leaf(0.12, 0.06, 0.1)
			leaf.material_override = Materials.foliage(Color(0.25, 0.45, 0.2))
			leaf.rotation = Vector3(-0.2, 0.6, 0.0)
			root.add_child(leaf)
			for i in 7:
				var a := i * 2.4
				_sphere(root, 0.017 if id != "dried_berries" else 0.013, Vector3(cos(a) * 0.025 * (i % 3), 0.02 + (i % 2) * 0.018, sin(a) * 0.025 * (i % 3)), Materials.plain(tone, 0.35))
		"raw_fish", "cooked_fish", "dried_fish":
			var tone: Color = {"raw_fish": Color(0.55, 0.64, 0.70), "cooked_fish": Color(0.66, 0.44, 0.22), "dried_fish": Color(0.55, 0.40, 0.25)}[id]
			var fish := MeshInstance3D.new()
			fish.mesh = _unit_sphere()
			fish.material_override = Materials.metal(tone, 0.4) if id == "raw_fish" else Materials.leather(tone)
			fish.scale = Vector3(0.05, 0.24, 0.022 if id == "dried_fish" else 0.07)
			fish.position.y = 0.12
			root.add_child(fish)
			var tail := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.09, 0.07, 0.01)
			tail.mesh = prism
			tail.material_override = fish.material_override
			tail.position.y = -0.005
			root.add_child(tail)
			_sphere(root, 0.008, Vector3(0.018, 0.2, -0.02), Materials.plain(Color(0.05, 0.05, 0.05), 0.2))
		"raw_sardine", "raw_mullet", "raw_pufferfish", "raw_snapper", "raw_grouper", "raw_barracuda", "raw_mahi_mahi", "raw_tuna", "cooked_pufferfish":
			_fish(root, id)
		"fish_steak":
			_rock(root, 15, Vector3(0.2, 0.05, 0.12), Vector3(0.0, 0.025, 0.0), Materials.leather(Color(0.72, 0.52, 0.34)), 0.12, 1.0)
			_torus(root, 0.05, 0.006, Vector3(0.0, 0.05, 0.0), Materials.plain(Color(0.9, 0.85, 0.75)), Vector3.ZERO, Vector3(1.4, 1.0, 0.8))
		"grub":
			var body := PackedVector3Array()
			var girth := PackedFloat32Array()
			for k in 9:
				var a := k / 8.0 * PI * 1.2
				body.append(Vector3(cos(a) * 0.035, 0.012, sin(a) * 0.035))
				girth.append(0.011 * (0.6 + 0.4 * sin(k / 8.0 * PI)) + 0.002 * (k % 2))
			var grub := MeshInstance3D.new()
			grub.mesh = MeshKit.tube(body, girth, 8, "grub_item")
			grub.material_override = Materials.plain(Color(0.93, 0.86, 0.68), 0.45)
			root.add_child(grub)
			_sphere(root, 0.01, Vector3(0.035, 0.014, 0.0), Materials.plain(Color(0.45, 0.28, 0.12), 0.4))
		"cut_bait":
			for i in 3:
				_rock(root, 16 + i, Vector3(0.05, 0.025, 0.04), Vector3((i - 1) * 0.045, 0.014, (i % 2) * 0.02), Materials.plain(Color(0.84, 0.45, 0.45), 0.35), 0.25, 1.0)
		"jig":
			_sphere(root, 0.014, Vector3(0.0, 0.1, 0.0), Materials.plain(Color(0.95, 0.75, 0.15), 0.3))
			for i in 7:
				var feather := MeshInstance3D.new()
				feather.mesh = MeshKit.leaf(0.08, 0.012, 0.02, 4, 0.0)
				feather.material_override = Materials.foliage(Color(0.95, 0.95, 0.9) if i % 2 == 0 else Color(0.2, 0.55, 0.85))
				feather.position = Vector3(0.0, 0.09, 0.0)
				feather.rotation = Vector3(PI * 0.85, i * TAU / 7.0, 0.0)
				root.add_child(feather)
			_torus(root, 0.012, 0.0025, Vector3(0.0, 0.02, 0.0), Materials.metal(Color(0.55, 0.55, 0.56), 0.4), Vector3(PI / 2.0, 0.0, 0.0))
		"raw_meat", "cooked_meat", "dried_meat", "spoiled_food", "raw_shark_meat", "cooked_shark":
			var tone: Color = {"raw_meat": Color(0.72, 0.18, 0.2), "cooked_meat": Color(0.45, 0.25, 0.13), "dried_meat": Color(0.35, 0.18, 0.1),
				"spoiled_food": Color(0.35, 0.42, 0.22), "raw_shark_meat": Color(0.86, 0.66, 0.66), "cooked_shark": Color(0.62, 0.44, 0.28)}[id]
			if id == "dried_meat":
				for i in 3:
					_box(root, Vector3(0.03, 0.15, 0.008), Vector3((i - 1) * 0.035, 0.07, i * 0.004), Materials.leather(tone)).rotation.z = (i - 1) * 0.15
			else:
				_rock(root, 12, Vector3(0.16, 0.05, 0.12), Vector3(0.0, 0.025, 0.0), Materials.leather(tone), 0.18, 1.0)
				if id == "raw_meat":
					_torus(root, 0.06, 0.008, Vector3(0.0, 0.03, 0.0), Materials.plain(Color(0.92, 0.85, 0.78)), Vector3.ZERO, Vector3(1.2, 1.0, 0.9))
		"fiber":
			for i in 9:
				var blade := MeshInstance3D.new()
				blade.mesh = MeshKit.leaf(0.24, 0.018, 0.25, 5, 0.0)
				blade.material_override = Materials.foliage(Color(0.52, 0.62, 0.30))
				blade.rotation = Vector3(-PI / 2.0 + 0.1 * (i % 3), i * 0.7, 0.0)
				root.add_child(blade)
			_torus(root, 0.02, 0.006, Vector3(0.0, 0.06, 0.0), Materials.cloth(Color(0.44, 0.5, 0.25)))
		"stone":
			_rock(root, 1, Vector3(0.12, 0.09, 0.1), Vector3(0.0, 0.045, 0.0), Materials.stone(Color(0.58, 0.56, 0.53)))
		"flint":
			_rock(root, 7, Vector3(0.11, 0.06, 0.08), Vector3(0.0, 0.03, 0.0), Materials.metal(Color(0.16, 0.16, 0.19), 0.25), 0.5)
		"driftwood":
			var stick := MeshInstance3D.new()
			stick.mesh = MeshKit.branch(4, 0.9, 0.05, 0.022, 0.25)
			stick.material_override = Materials.wood(Color(0.72, 0.67, 0.60))
			root.add_child(stick)
		"log":
			# A slightly crooked, lumpy log with bevelled ends, a couple of knots and ringed cuts.
			var length := 1.0
			var spine := PackedVector3Array()
			var girth := PackedFloat32Array()
			for k in 13:
				var t := k / 12.0
				spine.append(Vector3(0.035 * sin(t * PI), t * length, 0.012 * sin(t * TAU)))
				var bevel := minf(1.0, minf(t, 1.0 - t) / 0.03)
				girth.append(lerpf(0.105, 0.124 - 0.01 * t + 0.006 * sin(t * 23.0), clampf(bevel, 0.0, 1.0)))
			var trunk := MeshInstance3D.new()
			trunk.mesh = MeshKit.tube(spine, girth, 14, "log_item")
			trunk.material_override = Materials.bark(BARK)
			root.add_child(trunk)
			for knot: Array in [[0.32, 0.6], [0.71, 3.4]]:
				var ky: float = knot[0]
				var ka: float = knot[1]
				_rock(root, 14, Vector3(0.05, 0.07, 0.05), Vector3(cos(ka) * 0.12 + 0.035 * sin(ky * PI), ky, sin(ka) * 0.12), Materials.bark(BARK.darkened(0.2)), 0.2, 1.0)
			for y: float in [0.0, length]:
				_cylinder(root, 0.104, 0.008, Vector3(0.0, y + (0.002 if y > 0.0 else -0.002), 0.0), Materials.tree_rings(Color(0.72, 0.56, 0.36)))
		"rope", "paracord":
			var tone := ROPE if id == "rope" else Color(0.95, 0.45, 0.12)
			var loops := 5 if id == "rope" else 4
			for i in loops:
				_torus(root, 0.07 if id == "rope" else 0.045, 0.011 if id == "rope" else 0.006, Vector3(0.0, i * 0.018, 0.0), Materials.cloth(tone), Vector3(0.0, i * 0.6, 0.0))
		"tarp":
			_box(root, Vector3(0.3, 0.06, 0.24), Vector3(0.0, 0.03, 0.0), Materials.cloth(Color(0.18, 0.34, 0.58)))
			for x: float in [-0.08, 0.08]:
				_box(root, Vector3(0.012, 0.062, 0.245), Vector3(x, 0.03, 0.0), Materials.cloth(Color(0.14, 0.28, 0.5)))
			_torus(root, 0.012, 0.003, Vector3(0.14, 0.062, 0.1), Materials.metal(STEEL))
		"lure":
			var body := MeshInstance3D.new()
			body.mesh = _unit_sphere()
			body.material_override = Materials.metal(Color(0.9, 0.75, 0.2), 0.2)
			body.scale = Vector3(0.02, 0.07, 0.012)
			body.position.y = 0.04
			root.add_child(body)
			_torus(root, 0.01, 0.0025, Vector3(0.0, -0.005, 0.0), Materials.metal(STEEL), Vector3(0.0, PI / 2.0, 0.0))
		"ammo_45", "ammo_9mm", "ammo_556", "ammo_12ga", "ammo_408":
			_box(root, Vector3(0.1, 0.05, 0.07), Vector3(0.0, 0.025, 0.0), Materials.cloth(Color(0.30, 0.34, 0.24)))
			for i in 4:
				_cylinder(root, 0.006, 0.03, Vector3(-0.03 + i * 0.02, 0.06, 0.0), Materials.metal(BRASS, 0.3))
		"flare":
			_cylinder(root, 0.02, 0.14, Vector3(0.0, 0.07, 0.0), Materials.plain(Color(0.85, 0.15, 0.12), 0.5))
			_cylinder(root, 0.021, 0.025, Vector3(0.0, 0.15, 0.0), Materials.plain(Color(0.95, 0.95, 0.92)))
		"bandage":
			_cylinder(root, 0.04, 0.06, Vector3(0.0, 0.03, 0.0), Materials.cloth(Color(0.95, 0.94, 0.9)))
			_cylinder(root, 0.012, 0.062, Vector3(0.0, 0.03, 0.0), Materials.plain(Color(0.7, 0.7, 0.68)))
		"campfire_kit":
			for i in 5:
				var a := i * TAU / 5.0
				_rock(root, i, Vector3(0.07, 0.05, 0.06), Vector3(cos(a) * 0.1, 0.02, sin(a) * 0.1), Materials.stone(Color(0.5, 0.49, 0.47)))
			for i in 3:
				var stick := MeshInstance3D.new()
				stick.mesh = MeshKit.branch(i + 10, 0.3, 0.018, 0.01, 0.1, 5)
				stick.material_override = Materials.wood(PALE_WOOD)
				stick.rotation = Vector3(0.9, i * TAU / 3.0, 0.0)
				stick.position.y = 0.02
				root.add_child(stick)
		"lean_to_kit", "tent_kit", "drying_rack_kit":
			var cloth_tone := Color(0.2, 0.35, 0.55) if id == "lean_to_kit" else Color(0.34, 0.42, 0.28)
			if id != "drying_rack_kit":
				_cylinder(root, 0.07, 0.3, Vector3(0.0, 0.07, 0.0), Materials.cloth(cloth_tone), Vector3(0.0, 0.0, PI / 2.0))
			for i in 3:
				_cylinder(root, 0.012, 0.42, Vector3(-0.03 + i * 0.03, 0.16 if id != "drying_rack_kit" else 0.02, 0.0), Materials.wood(WOOD), Vector3(0.0, 0.0, PI / 2.0))
			_torus(root, 0.05, 0.006, Vector3(0.1, 0.08, 0.0), Materials.cloth(ROPE), Vector3(0.0, 0.0, PI / 2.0))
		"storage_crate_kit":
			_crate(root, Vector3(0.24, 0.18, 0.18))
		"tshirt", "rain_jacket", "wool_sweater":
			_shirt(root, id)
		"shorts", "cargo_pants":
			_pants(root, id)
		"sandals", "hiking_boots":
			_footwear(root, id)
		"wool_beanie", "sun_hat", "combat_helmet":
			_hat(root, id)
		"plate_carrier":
			_plate_carrier(root)
		"daypack", "satchel":
			_bag(root, id)
		_:
			_box(root, Vector3(0.08, 0.08, 0.08), Vector3(0.0, 0.04, 0.0), Materials.plain(Color(0.6, 0.55, 0.45)))
	return root


# --- clothing and gear ------------------------------------------------------------

static func _clothing_color(id: String) -> Color:
	if id in ["tshirt", "plate_carrier"]:
		var crew := AppearanceTable.crew_color(GameState.crew_color)
		return crew.lerp(Color(0.30, 0.32, 0.26), 0.55) if id == "plate_carrier" else crew
	var color: Color = CharacterModel.CLOTHING_COLORS.get(id, Color(0.5, 0.5, 0.5))
	return color


static func _shirt(root: Node3D, id: String) -> void:
	var color := _clothing_color(id)
	var material := Materials.cloth(color)
	var body := MeshInstance3D.new()
	body.mesh = _unit_sphere()
	body.material_override = material
	body.scale = Vector3(0.34, 0.4, 0.07)
	body.position.y = 0.2
	root.add_child(body)
	var sleeve_length := 0.13 if id == "tshirt" else 0.3
	for side: float in [-1.0, 1.0]:
		var sleeve := _capsule(root, 0.045, sleeve_length, Vector3(side * (0.17 + sleeve_length * 0.35), 0.3 - sleeve_length * 0.3, 0.0), material)
		sleeve.rotation.z = side * (1.1 if id == "tshirt" else 0.55)
	_torus(root, 0.05, 0.012, Vector3(0.0, 0.39, -0.01), Materials.cloth(color.darkened(0.2)), Vector3(PI / 2.0 - 0.3, 0.0, 0.0))
	if id == "rain_jacket":
		_box(root, Vector3(0.008, 0.36, 0.074), Vector3(0.0, 0.2, -0.003), Materials.plain(Color(0.2, 0.2, 0.2)))
		var hood := MeshInstance3D.new()
		hood.mesh = _unit_sphere()
		hood.material_override = material
		hood.scale = Vector3(0.16, 0.09, 0.08)
		hood.position = Vector3(0.0, 0.42, 0.02)
		root.add_child(hood)
	if id == "tshirt" and GameState.emblem > 0:
		var badge := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.09, 0.09)
		badge.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = Emblem.texture(GameState.emblem, Emblem.contrast(color))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		badge.material_override = mat
		badge.position = Vector3(-0.07, 0.28, 0.037)
		root.add_child(badge)


static func _pants(root: Node3D, id: String) -> void:
	var material := Materials.cloth(_clothing_color(id))
	var length := 0.2 if id == "shorts" else 0.5
	var waist := _box(root, Vector3(0.3, 0.07, 0.1), Vector3(0.0, length + 0.03, 0.0), material)
	waist.name = "Waist"
	for side: float in [-1.0, 1.0]:
		var leg := _capsule(root, 0.07, length, Vector3(side * 0.08, length * 0.5, 0.0), material)
		leg.rotation.z = side * 0.06
		if id == "cargo_pants":
			_box(root, Vector3(0.05, 0.08, 0.02), Vector3(side * 0.13, length * 0.55, -0.055), Materials.cloth(_clothing_color(id).darkened(0.15)))
	_box(root, Vector3(0.3, 0.015, 0.105), Vector3(0.0, length + 0.05, 0.0), Materials.leather(LEATHER))


static func _footwear(root: Node3D, id: String) -> void:
	for side: float in [-1.0, 1.0]:
		if id == "sandals":
			var sole := _box(root, Vector3(0.09, 0.02, 0.25), Vector3(side * 0.07, 0.01, 0.0), Materials.leather(CharacterModel.CLOTHING_COLORS.sandals))
			sole.rotation.y = side * 0.08
			_torus(root, 0.035, 0.007, Vector3(side * 0.07, 0.025, -0.04), Materials.leather(LEATHER), Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.6))
		else:
			var tone: Color = CharacterModel.CLOTHING_COLORS.hiking_boots
			var foot := MeshInstance3D.new()
			foot.mesh = _unit_sphere()
			foot.material_override = Materials.leather(tone)
			foot.scale = Vector3(0.1, 0.09, 0.26)
			foot.position = Vector3(side * 0.07, 0.045, -0.03)
			root.add_child(foot)
			_cylinder(root, 0.05, 0.12, Vector3(side * 0.07, 0.11, 0.04), Materials.leather(tone))
			_box(root, Vector3(0.1, 0.02, 0.27), Vector3(side * 0.07, 0.005, -0.03), Materials.plain(Color(0.12, 0.1, 0.09)))


static func _hat(root: Node3D, id: String) -> void:
	var color := _clothing_color(id)
	match id:
		"wool_beanie":
			var dome := MeshInstance3D.new()
			dome.mesh = _unit_hemisphere()
			dome.material_override = Materials.cloth(color)
			dome.scale = Vector3(0.24, 0.3, 0.24)
			root.add_child(dome)
			_torus(root, 0.12, 0.022, Vector3(0.0, 0.01, 0.0), Materials.cloth(color.darkened(0.2)))
		"sun_hat":
			_cylinder(root, 0.24, 0.012, Vector3.ZERO, Materials.cloth(color))
			var crown := MeshInstance3D.new()
			crown.mesh = _unit_hemisphere()
			crown.material_override = Materials.cloth(color)
			crown.scale = Vector3(0.24, 0.2, 0.24)
			root.add_child(crown)
			_torus(root, 0.12, 0.01, Vector3(0.0, 0.015, 0.0), Materials.cloth(Color(0.35, 0.22, 0.12)))
		"combat_helmet":
			var shell := MeshInstance3D.new()
			shell.mesh = _unit_hemisphere()
			shell.material_override = Materials.cloth(color)
			shell.scale = Vector3(0.27, 0.34, 0.3)
			root.add_child(shell)
			_torus(root, 0.14, 0.012, Vector3(0.0, 0.005, 0.0), Materials.plain(color.darkened(0.2)), Vector3.ZERO, Vector3(1.0, 1.0, 1.1))
			_box(root, Vector3(0.05, 0.04, 0.025), Vector3(0.0, 0.1, -0.145), Materials.metal(DARK_STEEL, 0.6))
			for side: float in [-1.0, 1.0]:
				_box(root, Vector3(0.015, 0.03, 0.08), Vector3(side * 0.133, 0.07, 0.0), Materials.plain(Color(0.15, 0.15, 0.15)))


static func _plate_carrier(root: Node3D) -> void:
	var color := _clothing_color("plate_carrier")
	var plate := MeshInstance3D.new()
	plate.mesh = _unit_sphere()
	plate.material_override = Materials.cloth(color)
	plate.scale = Vector3(0.34, 0.4, 0.09)
	plate.position.y = 0.2
	root.add_child(plate)
	for x: float in [-0.09, 0.0, 0.09]:
		_box(root, Vector3(0.075, 0.1, 0.05), Vector3(x, 0.1, -0.05), Materials.cloth(color.darkened(0.2)))
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.06, 0.12, 0.03), Vector3(side * 0.11, 0.42, 0.0), Materials.cloth(color.darkened(0.12)))
	_box(root, Vector3(0.12, 0.05, 0.005), Vector3(-0.07, 0.3, -0.046), Materials.plain(Color(0.15, 0.15, 0.15)))
	if GameState.emblem > 0:
		var badge := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.06, 0.06)
		badge.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = Emblem.texture(GameState.emblem, Emblem.contrast(color))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		badge.material_override = mat
		badge.rotation.y = PI
		badge.position = Vector3(0.08, 0.3, -0.047)
		root.add_child(badge)


static func _bag(root: Node3D, id: String) -> void:
	var color: Color = CharacterModel.CLOTHING_COLORS.get("daypack", Color(0.22, 0.25, 0.3)) if id == "daypack" else Color(0.55, 0.47, 0.32)
	var body := MeshInstance3D.new()
	body.mesh = _unit_sphere()
	body.material_override = Materials.cloth(color)
	body.scale = Vector3(0.3, 0.38, 0.16) if id == "daypack" else Vector3(0.28, 0.22, 0.08)
	body.position.y = body.scale.y * 0.5
	root.add_child(body)
	_box(root, Vector3(body.scale.x * 0.85, body.scale.y * 0.3, body.scale.z * 0.55), Vector3(0.0, body.scale.y * 0.78, -body.scale.z * 0.3), Materials.cloth(color.darkened(0.2)))
	_torus(root, body.scale.x * 0.45, 0.012, Vector3(0.0, body.scale.y * 0.9, 0.02), Materials.leather(LEATHER), Vector3(PI / 2.0, 0.0, 0.0))
	if id == "daypack":
		_box(root, Vector3(0.18, 0.12, 0.04), Vector3(0.0, 0.12, -0.085), Materials.cloth(color.darkened(0.1)))


static func _crate(root: Node3D, size: Vector3) -> void:
	var wood := Materials.wood(Color(0.58, 0.43, 0.26))
	_box(root, size * 0.94, Vector3(0.0, size.y * 0.5, 0.0), wood)
	for y: float in [0.1, 0.9]:
		_box(root, Vector3(size.x, size.y * 0.12, size.z), Vector3(0.0, size.y * y, 0.0), Materials.wood(Color(0.46, 0.33, 0.2)))
	for x: float in [-0.45, 0.45]:
		_box(root, Vector3(size.x * 0.1, size.y, size.z + 0.004), Vector3(size.x * x, size.y * 0.5, 0.0), Materials.wood(Color(0.46, 0.33, 0.2)))


# --- primitives -----------------------------------------------------------------

static var _sphere_mesh: SphereMesh
static var _hemisphere: SphereMesh


static func _unit_sphere() -> SphereMesh:
	if _sphere_mesh == null:
		_sphere_mesh = SphereMesh.new()
		_sphere_mesh.radius = 0.5
		_sphere_mesh.height = 1.0
		_sphere_mesh.radial_segments = 20
		_sphere_mesh.rings = 12
	return _sphere_mesh


static func _unit_hemisphere() -> SphereMesh:
	if _hemisphere == null:
		_hemisphere = SphereMesh.new()
		_hemisphere.radius = 0.5
		_hemisphere.height = 0.5
		_hemisphere.is_hemisphere = true
		_hemisphere.radial_segments = 20
		_hemisphere.rings = 8
	return _hemisphere


## A whole fish, nose up along +Y like the other fish models: body, paler belly,
## dorsal and tail fins, eyes — coloured and proportioned by species.
static func _fish(parent: Node3D, id: String) -> void:
	# [back colour, belly colour, length, depth (back to belly), thickness]
	var looks := {
		"raw_sardine": [Color(0.25, 0.42, 0.62), Color(0.85, 0.88, 0.9), 0.16, 0.035, 0.022],
		"raw_mullet": [Color(0.42, 0.46, 0.48), Color(0.82, 0.84, 0.82), 0.3, 0.07, 0.045],
		"raw_pufferfish": [Color(0.62, 0.58, 0.38), Color(0.92, 0.9, 0.82), 0.16, 0.13, 0.12],
		"cooked_pufferfish": [Color(0.55, 0.38, 0.2), Color(0.7, 0.52, 0.32), 0.16, 0.12, 0.11],
		"raw_snapper": [Color(0.82, 0.28, 0.26), Color(0.95, 0.72, 0.68), 0.34, 0.12, 0.05],
		"raw_grouper": [Color(0.42, 0.33, 0.24), Color(0.62, 0.55, 0.44), 0.5, 0.18, 0.1],
		"raw_barracuda": [Color(0.5, 0.55, 0.58), Color(0.88, 0.9, 0.9), 0.62, 0.07, 0.05],
		"raw_mahi_mahi": [Color(0.2, 0.58, 0.42), Color(0.92, 0.82, 0.25), 0.55, 0.16, 0.06],
		"raw_tuna": [Color(0.12, 0.18, 0.36), Color(0.82, 0.84, 0.86), 0.7, 0.2, 0.14],
	}
	var look: Array = looks.get(id, looks.raw_sardine)
	var back: Color = look[0]
	var belly: Color = look[1]
	var length: float = look[2]
	var depth: float = look[3]
	var thick: float = look[4]
	var cooked := id.begins_with("cooked")
	var skin := Materials.leather(back) if cooked else Materials.metal(back, 0.45)
	var pale := Materials.leather(belly) if cooked else Materials.metal(belly, 0.4)
	# The fish lies in the XY plane, back toward +X and its flat side facing Z, so
	# icons (photographed from +Z) and the hand show it side-on like a blade.
	var y := length * 0.5 + 0.02
	_add(parent, _unit_sphere(), Vector3(0.0, y, 0.0), skin).scale = Vector3(depth, length, thick)
	_add(parent, _unit_sphere(), Vector3(-depth * 0.16, y - length * 0.03, 0.0), pale).scale = Vector3(depth * 0.7, length * 0.82, thick * 0.92)
	var fin := Materials.metal(back.darkened(0.25), 0.5) if not cooked else skin
	# Dorsal fin along the back, anal fin under the belly, a pectoral fin behind each gill.
	_add(parent, _unit_sphere(), Vector3(depth * 0.5, y + length * 0.04, 0.0), fin).scale = Vector3(depth * 0.4, length * 0.34, 0.006)
	_add(parent, _unit_sphere(), Vector3(-depth * 0.46, y - length * 0.22, 0.0), fin).scale = Vector3(depth * 0.26, length * 0.16, 0.006)
	for s: float in [-1.0, 1.0]:
		# Forked tail: two lobes fanning out from the tail stock.
		_add(parent, _unit_sphere(), Vector3(s * depth * 0.2, y - length * 0.56, 0.0), fin, Vector3(0.0, 0.0, s * 0.6)).scale = Vector3(depth * 0.3, length * 0.26, 0.006)
		_add(parent, _unit_sphere(), Vector3(-depth * 0.05, y + length * 0.2, s * thick * 0.5), fin, Vector3(0.0, 0.0, -0.5)).scale = Vector3(depth * 0.14, length * 0.12, 0.005)
		_sphere(parent, maxf(0.006, depth * 0.09), Vector3(depth * 0.12, y + length * 0.36, s * thick * 0.42), Materials.plain(Color(0.04, 0.04, 0.05), 0.2))
	match id:
		"raw_pufferfish", "cooked_pufferfish":
			var rng := RandomNumberGenerator.new()
			rng.seed = 91
			for i in 18:
				var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
				_add(parent, _unit_sphere(), Vector3(0.0, y, 0.0) + dir * Vector3(depth, length, thick) * 0.5, fin).scale = Vector3.ONE * 0.012
		"raw_tuna":
			for i in 5:
				_sphere(parent, 0.008, Vector3(depth * 0.36, y - length * (0.18 + i * 0.07), 0.0), Materials.plain(Color(0.95, 0.8, 0.2), 0.4))
				_sphere(parent, 0.008, Vector3(-depth * 0.36, y - length * (0.18 + i * 0.07), 0.0), Materials.plain(Color(0.95, 0.8, 0.2), 0.4))
		"raw_barracuda":
			for i in 4:
				_add(parent, _unit_sphere(), Vector3(depth * 0.12, y + length * (0.2 - i * 0.14), 0.0), Materials.plain(back.darkened(0.5), 0.5)).scale = Vector3(depth * 0.6, length * 0.03, thick * 1.02)
		"raw_mahi_mahi":
			# The bull mahi's tall, blunt forehead.
			_add(parent, _unit_sphere(), Vector3(depth * 0.18, y + length * 0.33, 0.0), skin).scale = Vector3(depth * 0.85, length * 0.2, thick * 0.95)



# --- gun parts ---------------------------------------------------------------------
# Guns are built barrel along +Y, sights up on +Z, the grip at the origin.

## A length of picatinny rail: the base, with slots cut across it.
static func _rail(parent: Node3D, from_y: float, to_y: float, z: float, width: float) -> void:
	var length := to_y - from_y
	if length <= 0.0:
		return
	_box(parent, Vector3(width, length, 0.008), Vector3(0.0, (from_y + to_y) * 0.5, z), Materials.metal(PARKER, 0.55))
	var slots := maxi(2, int(length / 0.018))
	for i in slots:
		var y := lerpf(from_y + 0.008, to_y - 0.008, float(i) / maxf(1.0, float(slots - 1)))
		_box(parent, Vector3(width * 1.02, 0.005, 0.014), Vector3(0.0, y, z + 0.005), Materials.metal(PARKER.darkened(0.3), 0.7))


## Grooves cut across something, like slide serrations or a pump's ribs.
static func _grooves(parent: Node3D, count: int, from_y: float, to_y: float, z: float, width: float, depth: float, mat: Material) -> void:
	for i in count:
		var y := lerpf(from_y, to_y, float(i) / maxf(1.0, float(count - 1)))
		_box(parent, Vector3(width, 0.005, depth), Vector3(0.0, y, z), mat)


## An iron sight: a post at the front, a notch at the back.
static func _sight(parent: Node3D, y: float, z: float, front: bool, mat: Material) -> void:
	if front:
		_box(parent, Vector3(0.006, 0.008, 0.022), Vector3(0.0, y, z + 0.011), mat)
		for side: float in [-1.0, 1.0]:
			_box(parent, Vector3(0.005, 0.01, 0.03), Vector3(side * 0.013, y, z + 0.015), mat)
	else:
		for side: float in [-1.0, 1.0]:
			_box(parent, Vector3(0.007, 0.01, 0.02), Vector3(side * 0.011, y, z + 0.01), mat)
		_box(parent, Vector3(0.03, 0.01, 0.006), Vector3(0.0, y, z + 0.004), mat)


## A shape drawn from the side (along the gun, up) and pushed out to `width`.
static func _profile(parent: Node3D, outline: Array, width: float, mat: Material, key: String = "") -> MeshInstance3D:
	var points := PackedVector2Array()
	for point: Vector2 in outline:
		points.append(point)
	return _add(parent, MeshKit.extrude(points, width, key), Vector3.ZERO, mat)


## A box given by the space it fills rather than its middle: `y` from/to along
## the gun, `z` from/to across its height. Parts built this way actually meet,
## instead of leaving a gap where two centres were guessed.
static func _span(parent: Node3D, width: float, y_from: float, y_to: float, z_from: float, z_to: float, mat: Material) -> MeshInstance3D:
	var size := Vector3(width, absf(y_to - y_from), absf(z_to - z_from))
	return _box(parent, size, Vector3(0.0, (y_from + y_to) * 0.5, (z_from + z_to) * 0.5), mat)


## The same, for a round part: a tube from `y_from` to `y_to` at height `z`.
static func _tube_along(parent: Node3D, radius: float, y_from: float, y_to: float, z: float, mat: Material) -> MeshInstance3D:
	return _cylinder(parent, radius, absf(y_to - y_from), Vector3(0.0, (y_from + y_to) * 0.5, z), mat)


## A part of a gun that hangs off it at an angle — a grip, a magazine, a stock.
## Everything added to the returned node is laid out along its own axes, so it
## stays in one piece instead of stepping out of line.
static func _assembly(parent: Node3D, at: Vector3, lean: float) -> Node3D:
	var node := Node3D.new()
	node.position = at
	node.rotation.x = lean
	parent.add_child(node)
	return node


## A magazine hanging below the receiver from `top`, `lean` back from upright.
static func _magazine(parent: Node3D, top: Vector3, length: float, width: float, depth: float, lean: float, mat: Material) -> void:
	var mag := _assembly(parent, top, lean)
	# Starts above the feed point so it sits inside the magwell, not below it.
	_box(mag, Vector3(width, depth, length + 0.03), Vector3(0.0, 0.0, -length * 0.5 + 0.015), mat)
	_box(mag, Vector3(width * 1.08, depth * 1.05, 0.012), Vector3(0.0, 0.0, -length), Materials.plain(PARKER.darkened(0.2), 0.7))
	# A witness rib down the side, so it doesn't read as a plain block.
	_box(mag, Vector3(width * 1.02, depth * 0.35, length * 0.8), Vector3(0.0, depth * 0.36, -length * 0.5), Materials.plain(PARKER.darkened(0.35), 0.8))


## The pistol grip with its trigger and guard, hanging from `at`.
static func _grip_and_trigger(parent: Node3D, grip_size: Vector3, at: Vector3, lean: float, mat: Material, panels: Material = null) -> void:
	var grip := _assembly(parent, at, lean)
	var length: float = grip_size.y
	# Reaches up into the receiver so there's no seam at the top.
	_box(grip, Vector3(grip_size.x, grip_size.z, length + 0.035), Vector3(0.0, 0.0, -length * 0.5 + 0.018), mat)
	_box(grip, Vector3(grip_size.x * 1.06, grip_size.z * 0.5, 0.014), Vector3(0.0, 0.0, -length), Materials.plain(PARKER.darkened(0.25), 0.8))
	if panels != null:
		for side: float in [-1.0, 1.0]:
			_box(grip, Vector3(0.004, grip_size.z * 0.8, length * 0.8), Vector3(side * grip_size.x * 0.52, 0.0, -length * 0.5), panels)
	# Trigger and guard sit just in front of the grip, on the gun itself.
	_box(parent, Vector3(0.008, 0.03, 0.012), Vector3(0.0, at.y + 0.035, at.z + 0.012), Materials.metal(PARKER, 0.5)).rotation.x = 0.35
	_torus(parent, 0.023, 0.0035, Vector3(0.0, at.y + 0.03, at.z + 0.016), Materials.metal(PARKER, 0.5), Vector3(0.0, 0.0, PI / 2.0), Vector3(1.0, 1.0, 0.7))


## A shoulder stock running back from `at`: the wrist, then the comb and butt,
## dropping a little as it goes.
static func _stock(parent: Node3D, at: Vector3, length: float, width: float, mat: Material, comb: bool = true) -> void:
	var stock := _assembly(parent, at, 0.0)
	# The wrist reaches forward into the receiver so the join is solid.
	_box(stock, Vector3(width * 0.82, length * 0.5, 0.062), Vector3(0.0, -length * 0.2, -0.014), mat)
	_box(stock, Vector3(width, length * 0.5, 0.08), Vector3(0.0, -length * 0.72, -0.026), mat)
	if comb:
		_box(stock, Vector3(width * 0.78, length * 0.46, 0.028), Vector3(0.0, -length * 0.66, 0.02), mat)
	_box(stock, Vector3(width * 1.05, 0.022, 0.1), Vector3(0.0, -length, -0.03), Materials.plain(PARKER.darkened(0.2), 0.9))


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, material, rot)


static func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return _add(parent, mesh, pos, material, rot)


static func _capsule(parent: Node3D, radius: float, length: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0)
	mesh.radial_segments = 14
	mesh.rings = 4
	return _add(parent, mesh, pos, material)


static func _sphere(parent: Node3D, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := _add(parent, _unit_sphere(), pos, material)
	instance.scale = Vector3.ONE * radius * 2.0
	return instance


static func _torus(parent: Node3D, radius: float, thickness: float, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 20
	mesh.ring_segments = 8
	var instance := _add(parent, mesh, pos, material, rot)
	instance.scale = stretch
	return instance


static func _rock(parent: Node3D, variant: int, size: Vector3, pos: Vector3, material: Material, roughness: float = 0.3, squash: float = 1.0) -> MeshInstance3D:
	var instance := _add(parent, MeshKit.rock(variant, roughness, squash), pos, material)
	instance.scale = size
	return instance


# --- blades, bow, motor, rod --------------------------------------------------------
# Blades are drawn as side profiles (y along the blade, z across it) and extruded
# to their thickness, so handle, guard and blade are each one solid piece and meet.

## A belt knife: a shaped wooden handle with brass rivets, a steel bolster, and a
## drop-point blade with a grind line.
static func _knife(root: Node3D) -> void:
	var steel := Materials.metal(Color(0.6, 0.6, 0.59), 0.42)
	var edge := Materials.metal(Color(0.8, 0.8, 0.78), 0.3)
	var handle := [Vector2(-0.065, -0.008), Vector2(-0.07, 0.0), Vector2(-0.066, 0.011), Vector2(-0.02, 0.013), Vector2(0.03, 0.012),
		Vector2(0.055, 0.013), Vector2(0.055, -0.012), Vector2(0.03, -0.013), Vector2(0.0, -0.01), Vector2(-0.03, -0.014)]
	_profile(root, handle, 0.02, Materials.wood(Color(0.36, 0.22, 0.12)), "knife_handle")
	_profile(root, [Vector2(0.052, -0.016), Vector2(0.052, 0.016), Vector2(0.064, 0.015), Vector2(0.064, -0.015)], 0.024, Materials.metal(DARK_STEEL, 0.4), "knife_bolster")
	var blade := [Vector2(0.062, -0.013), Vector2(0.062, 0.012), Vector2(0.15, 0.012), Vector2(0.19, 0.002), Vector2(0.2, -0.001),
		Vector2(0.18, -0.009), Vector2(0.12, -0.014)]
	_profile(root, blade, 0.004, steel, "knife_blade")
	# The ground edge: a lighter strip along the cutting side.
	_profile(root, [Vector2(0.066, -0.013), Vector2(0.12, -0.0135), Vector2(0.18, -0.0085), Vector2(0.196, -0.001), Vector2(0.18, -0.004), Vector2(0.12, -0.008), Vector2(0.066, -0.008)], 0.0046, edge, "knife_edge")
	for y: float in [-0.04, 0.0, 0.035]:
		_cylinder(root, 0.0035, 0.024, Vector3(0.0, y, 0.0), Materials.metal(BRASS, 0.35), Vector3(0.0, 0.0, PI / 2.0))


## A machete: a long blade, widening toward the tip, on a two-slab wooden handle.
static func _machete(root: Node3D) -> void:
	var steel := Materials.metal(Color(0.5, 0.5, 0.49), 0.55)
	var edge := Materials.metal(Color(0.76, 0.76, 0.74), 0.35)
	var handle := [Vector2(-0.085, -0.012), Vector2(-0.092, 0.004), Vector2(-0.085, 0.017), Vector2(0.0, 0.015), Vector2(0.06, 0.016),
		Vector2(0.06, -0.016), Vector2(0.0, -0.014), Vector2(-0.04, -0.017)]
	_profile(root, handle, 0.026, Materials.wood(Color(0.30, 0.19, 0.11)), "machete_handle")
	var blade := [Vector2(0.05, -0.016), Vector2(0.05, 0.016), Vector2(0.36, 0.016), Vector2(0.49, 0.012), Vector2(0.52, 0.0),
		Vector2(0.5, -0.03), Vector2(0.42, -0.04), Vector2(0.25, -0.03), Vector2(0.1, -0.02)]
	_profile(root, blade, 0.0035, steel, "machete_blade")
	_profile(root, [Vector2(0.1, -0.02), Vector2(0.25, -0.03), Vector2(0.42, -0.04), Vector2(0.5, -0.03), Vector2(0.49, -0.022), Vector2(0.42, -0.031), Vector2(0.25, -0.022), Vector2(0.1, -0.013)],
		0.004, edge, "machete_edge")
	for y: float in [-0.055, -0.01, 0.035]:
		_cylinder(root, 0.004, 0.03, Vector3(0.0, y, 0.0), Materials.metal(BRASS, 0.35), Vector3(0.0, 0.0, PI / 2.0))


## The thief's dagger: a leather-wrapped grip, a wide crossguard and a
## double-edged, ridged blade.
static func _dagger(root: Node3D) -> void:
	var steel := Materials.metal(Color(0.62, 0.62, 0.62), 0.38)
	_profile(root, [Vector2(-0.07, -0.014), Vector2(-0.075, 0.0), Vector2(-0.07, 0.014), Vector2(-0.06, 0.016), Vector2(-0.06, -0.016)], 0.03, Materials.metal(DARK_STEEL, 0.4), "dagger_pommel")
	_profile(root, [Vector2(-0.062, -0.011), Vector2(-0.062, 0.011), Vector2(0.05, 0.012), Vector2(0.05, -0.012)], 0.02, Materials.leather(Color(0.2, 0.13, 0.08)), "dagger_grip")
	for i in 6:
		_torus(root, 0.0125, 0.0022, Vector3(0.0, -0.05 + i * 0.019, 0.0), Materials.leather(Color(0.14, 0.09, 0.05)), Vector3.ZERO, Vector3(0.85, 1.0, 1.0))
	_profile(root, [Vector2(0.048, -0.038), Vector2(0.044, -0.03), Vector2(0.044, 0.03), Vector2(0.048, 0.038), Vector2(0.062, 0.034), Vector2(0.062, -0.034)], 0.022, Materials.metal(BRASS, 0.4), "dagger_guard")
	_profile(root, [Vector2(0.06, -0.016), Vector2(0.06, 0.016), Vector2(0.2, 0.01), Vector2(0.27, 0.0), Vector2(0.2, -0.01)], 0.004, steel, "dagger_blade")
	_profile(root, [Vector2(0.06, -0.0025), Vector2(0.06, 0.0025), Vector2(0.25, 0.0005), Vector2(0.25, -0.0005)], 0.0065, Materials.metal(Color(0.78, 0.78, 0.77), 0.3), "dagger_ridge")


## A recurve bow: laminated limbs curving back from the riser and flicking forward
## at the tips, a leather grip, and the string. Arrow flies +Y; limbs run ±Z.
static func _bow(root: Node3D) -> void:
	var wood := Materials.wood(Color(0.42, 0.26, 0.14))
	var tips: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in 13:
			var t := float(i) / 12.0
			# Back from the riser, then the recurve flicks the tip forward again.
			# Back toward the archer, then the recurve flicks the tip forward again:
			# the string sits a hand's width behind the grip (the brace height).
			var back := -0.26 * sin(t * PI * 0.5) + 0.06 * smoothstep(0.7, 1.0, t)
			points.append(Vector3(0.0, back, side * (0.1 + t * 0.62)))
			radii.append(lerpf(0.016, 0.006, t))
		var limb := MeshInstance3D.new()
		limb.mesh = MeshKit.tube(points, radii, 6, "bow_limb_%d" % int(side))
		limb.material_override = wood
		limb.scale = Vector3(1.6, 0.7, 1.0)  # limbs are flat and wide, not round
		root.add_child(limb)
		tips.append(points[points.size() - 1] * Vector3(1.6, 0.7, 1.0))
	_profile(root, [Vector2(-0.03, -0.12), Vector2(0.012, -0.11), Vector2(0.03, -0.04), Vector2(0.02, 0.04), Vector2(0.012, 0.11), Vector2(-0.03, 0.12), Vector2(-0.018, 0.0)],
		0.03, wood, "bow_riser")
	_cylinder(root, 0.021, 0.1, Vector3(-0.004, 0.0, 0.0), Materials.leather(LEATHER), Vector3(PI / 2.0, 0.0, 0.0))
	# The string, tip to tip.
	var string := MeshInstance3D.new()
	string.name = "String"
	root.set_meta("tips", tips)
	string.mesh = MeshKit.tube(PackedVector3Array([tips[0], (tips[0] + tips[1]) * 0.5, tips[1]]), PackedFloat32Array([0.0015, 0.0015, 0.0015]), 4, "bow_string")
	string.material_override = Materials.plain(Color(0.85, 0.82, 0.72))
	root.add_child(string)


## One arrow along +Y from `base`: shaft, broadhead and three fletches.
static func _arrow(root: Node3D, base: Vector3) -> void:
	_cylinder(root, 0.004, 0.72, base + Vector3(0.0, 0.36, 0.0), Materials.wood(Color(0.7, 0.58, 0.4)))
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.011
	head.height = 0.05
	head.radial_segments = 4
	_add(root, head, base + Vector3(0.0, 0.745, 0.0), Materials.metal(DARK_STEEL, 0.45))
	for i in 3:
		var a := i * TAU / 3.0
		_box(root, Vector3(0.0015, 0.09, 0.016), base + Vector3(cos(a) * 0.009, 0.06, sin(a) * 0.009), Materials.plain(Color(0.75, 0.15, 0.1) if i == 0 else Color(0.9, 0.88, 0.8)), Vector3(0.0, -a, 0.0))


## An outboard motor, standing as it would on a transom: the cowling on top, the
## shaft down to the lower unit, the propeller, the clamp bracket and the tiller.
static func _outboard(root: Node3D) -> void:
	var cowl := Materials.plain(Color(0.16, 0.18, 0.2), 0.35)
	var grey := Materials.metal(Color(0.45, 0.46, 0.47), 0.5)
	var dark := Materials.metal(Color(0.12, 0.12, 0.13), 0.5)
	var cover := MeshInstance3D.new()
	cover.mesh = _unit_sphere()
	cover.material_override = cowl
	cover.scale = Vector3(0.34, 0.36, 0.46)
	cover.position = Vector3(0.0, 0.86, 0.0)
	root.add_child(cover)
	_box(root, Vector3(0.3, 0.16, 0.4), Vector3(0.0, 0.72, 0.0), cowl)
	_box(root, Vector3(0.31, 0.02, 0.41), Vector3(0.0, 0.8, 0.0), Materials.plain(Color(0.85, 0.35, 0.1), 0.4))
	_box(root, Vector3(0.12, 0.46, 0.16), Vector3(0.0, 0.42, 0.02), grey)
	var foot := MeshInstance3D.new()
	foot.mesh = _unit_sphere()
	foot.material_override = grey
	foot.scale = Vector3(0.1, 0.1, 0.32)
	foot.position = Vector3(0.0, 0.12, 0.02)
	root.add_child(foot)
	_box(root, Vector3(0.03, 0.14, 0.08), Vector3(0.0, 0.2, 0.08), grey)
	for i in 3:
		_box(root, Vector3(0.02, 0.13, 0.05), Vector3(0.0, 0.12, 0.2), dark, Vector3(0.0, 0.0, i * TAU / 3.0))
	_cylinder(root, 0.025, 0.05, Vector3(0.0, 0.12, 0.19), dark, Vector3(PI / 2.0, 0.0, 0.0))
	_box(root, Vector3(0.18, 0.2, 0.06), Vector3(0.0, 0.6, -0.12), dark)
	for x: float in [-0.06, 0.06]:
		_cylinder(root, 0.012, 0.1, Vector3(x, 0.55, -0.18), dark, Vector3(PI / 2.0, 0.0, 0.0))
	# The tiller reaches forward into the boat (-Z); the propeller is aft (+Z).
	_cylinder(root, 0.018, 0.42, Vector3(0.0, 0.72, -0.38), dark, Vector3(PI / 2.0 + 0.15, 0.0, 0.0), 0.022)
	_capsule(root, 0.026, 0.12, Vector3(0.0, 0.75, -0.6), Materials.plain(Color(0.08, 0.08, 0.08), 0.8)).rotation.x = PI / 2.0 + 0.15


## A 20-litre steel fuel drum, red, with rolling hoops, a filler cap and a handle.
static func _fuel_drum(root: Node3D) -> void:
	var paint := Materials.metal(Color(0.62, 0.12, 0.08), 0.5)
	var dark := Materials.metal(Color(0.18, 0.17, 0.16), 0.5)
	_cylinder(root, 0.15, 0.44, Vector3(0.0, 0.22, 0.0), paint)
	for y: float in [0.04, 0.16, 0.28, 0.4]:
		_torus(root, 0.152, 0.008, Vector3(0.0, y, 0.0), paint)
	_cylinder(root, 0.03, 0.03, Vector3(0.07, 0.455, 0.0), dark)
	_box(root, Vector3(0.16, 0.02, 0.025), Vector3(-0.04, 0.47, 0.0), dark)
	_box(root, Vector3(0.12, 0.08, 0.002), Vector3(0.0, 0.25, 0.151), Materials.plain(Color(0.9, 0.85, 0.2)))


## A spinning rod: a tapered two-piece blank, cork grip and reel seat, a spinning
## reel hung under it, line guides getting smaller toward the tip, and the line.
## The tip is at (0, 1.27, 0) (Angler casts from there).
static func _fishing_rod(root: Node3D) -> void:
	var blank := Materials.plain(Color(0.1, 0.13, 0.2), 0.25)
	var cork := Materials.wood(Color(0.74, 0.6, 0.42))
	var metal := Materials.metal(Color(0.7, 0.71, 0.73), 0.35)
	var dark := Materials.plain(Color(0.08, 0.08, 0.09), 0.4)
	var rod := MeshInstance3D.new()
	rod.mesh = MeshKit.tube(PackedVector3Array([Vector3(0.0, -0.08, 0.0), Vector3(0.0, 0.4, 0.0), Vector3(0.0, 0.9, 0.0), Vector3(0.0, 1.27, 0.0)]),
		PackedFloat32Array([0.012, 0.009, 0.006, 0.0025]), 8, "rod_blank")
	rod.material_override = blank
	root.add_child(rod)
	_cylinder(root, 0.017, 0.2, Vector3(0.0, 0.0, 0.0), cork, Vector3.ZERO, 0.015)
	_cylinder(root, 0.014, 0.08, Vector3(0.0, 0.14, 0.0), dark)
	_cylinder(root, 0.016, 0.05, Vector3(0.0, 0.21, 0.0), cork, Vector3.ZERO, 0.013)
	_cylinder(root, 0.013, 0.012, Vector3(0.0, 0.47, 0.0), metal)  # the ferrule where the pieces join
	# The reel: foot to the seat, body, spool, bail and handle.
	_box(root, Vector3(0.008, 0.05, 0.03), Vector3(0.0, 0.14, -0.025), metal)
	_box(root, Vector3(0.03, 0.05, 0.04), Vector3(0.0, 0.13, -0.06), dark)
	_cylinder(root, 0.024, 0.03, Vector3(0.0, 0.17, -0.065), metal)
	_cylinder(root, 0.02, 0.012, Vector3(0.0, 0.19, -0.065), Materials.plain(Color(0.9, 0.9, 0.85)))
	_torus(root, 0.026, 0.0015, Vector3(0.0, 0.195, -0.065), metal, Vector3(PI / 2.0, 0.0, 0.0))
	_cylinder(root, 0.003, 0.05, Vector3(0.025, 0.13, -0.06), metal, Vector3(0.0, 0.0, PI / 2.0))
	_capsule(root, 0.006, 0.025, Vector3(0.05, 0.13, -0.06), dark)
	# Guides, stepping down in size, all on the same side as the reel.
	var guides := [[0.36, 0.014], [0.58, 0.011], [0.78, 0.009], [0.96, 0.007], [1.12, 0.006], [1.26, 0.005]]
	for guide: Array in guides:
		var y: float = guide[0]
		var r: float = guide[1]
		_box(root, Vector3(0.002, 0.02, r * 1.4), Vector3(0.0, y, -r * 0.7), metal)
		_torus(root, r, 0.0012, Vector3(0.0, y, -r * 1.5), metal, Vector3(PI / 2.0, 0.0, 0.0))
	# The line from the spool up through the guides.
	var line := PackedVector3Array([Vector3(0.0, 0.19, -0.065)])
	var widths := PackedFloat32Array([0.0006])
	for guide: Array in guides:
		line.append(Vector3(0.0, float(guide[0]), -float(guide[1]) * 1.5))
		widths.append(0.0006)
	var thread := MeshInstance3D.new()
	thread.mesh = MeshKit.tube(line, widths, 3, "rod_line")
	thread.material_override = Materials.plain(Color(0.9, 0.9, 0.85))
	root.add_child(thread)


## A knife-style blade: a flat slab with a pointed tip, pointing +Y from `base`.
static func _blade(parent: Node3D, thickness: float, length: float, width: float, base: Vector3) -> void:
	# Worn, satin steel: a flat mirror-bright blade just reflects the blue sky.
	var steel := Materials.metal(Color(0.56, 0.56, 0.55), 0.5)
	_box(parent, Vector3(thickness, length * 0.85, width), base + Vector3(0.0, length * 0.425, 0.0), steel)
	var tip := PrismMesh.new()
	tip.size = Vector3(width, length * 0.18, thickness)
	tip.left_to_right = 0.0
	_add(parent, tip, base + Vector3(0.0, length * 0.94, 0.0), steel, Vector3(0.0, PI / 2.0, 0.0))
	_box(parent, Vector3(thickness * 1.05, length * 0.8, width * 0.12), base + Vector3(0.0, length * 0.42, width * 0.44), Materials.metal(Color(0.78, 0.78, 0.76), 0.38))


static func _flame(parent: Node3D, pos: Vector3, size: float) -> void:
	for i in 2:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = size * (1.0 - i * 0.35)
		cone.height = size * (2.6 - i * 0.8)
		cone.radial_segments = 8
		_add(parent, cone, pos + Vector3(0.0, cone.height * 0.5, 0.0), Materials.glow(Color(1.0, 0.55 + i * 0.3, 0.15)))
