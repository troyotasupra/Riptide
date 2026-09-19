extends "res://tests/test_case.gd"

const Weapons = preload("res://data/weapon_table.gd")
const Attachments = preload("res://data/attachment_table.gd")
const Math = preload("res://items/weapon_math.gd")
const Shot = preload("res://items/ballistics.gd")


func test_every_gun_is_whole() -> void:
	for id: String in Weapons.WEAPONS:
		var gun: Dictionary = Weapons.WEAPONS[id]
		check(Weapons.CALIBERS.has(gun.caliber), "%s has a real calibre" % id)
		check(gun.mag > 0 and gun.damage > 0.0 and gun.velocity > 0.0, "%s shoots something" % id)
		check(not Array(gun.modes).is_empty(), "%s has a fire mode" % id)
		# Every gun can be sighted: an optic slot, or a scope built in.
		check(Array(gun.slots).has("optic") or float(gun.get("zoom", 1.0)) > 1.0, "%s can take or has an optic" % id)
	check(Weapons.ammo_item("m4") == "ammo_556" and Weapons.ammo_item("m1911") == "ammo_45", "each gun eats its own rounds")
	check(Weapons.manual_action("intervention") and Weapons.manual_action("mossberg"), "the bolt gun and the pump are worked by hand")
	check(not Weapons.manual_action("uzi"), "the Uzi works its own action")


func test_attachments_only_go_where_they_fit() -> void:
	check(Attachments.fits("m4", "sniper_scope"), "the scope fits the M4")
	check(not Attachments.fits("m1911", "sniper_scope"), "but not the pistol")
	check(not Attachments.fits("m1911", "vertical_grip"), "a pistol has no underbarrel")
	check(Attachments.fits("uzi", "suppressor"), "the Uzi takes a can")
	check(Attachments.for_weapon("m1911").size() > 0, "the pistol has something to fit")
	for id: String in Attachments.ATTACHMENTS:
		var fitted := false
		for weapon: String in Weapons.WEAPONS:
			fitted = fitted or Attachments.fits(weapon, id)
		check(fitted, "%s goes on something" % id)


func test_attachments_trade_one_thing_for_another() -> void:
	var bare := Math.stats("m4")
	var comped := Math.stats("m4", {"muzzle": "compensator"})
	check(comped.recoil_up < bare.recoil_up, "a compensator tames the kick")
	var quiet := Math.stats("m4", {"muzzle": "suppressor"})
	check(Math.loudness(quiet) < Math.loudness(bare) * 0.5, "a suppressor halves how far it carries")
	check(quiet.wear > bare.wear, "and fouls the gun faster")
	check(Math.ads_seconds(quiet, 0.0) > Math.ads_seconds(bare, 0.0), "and slows the sights coming up")
	var big := Math.stats("m4", {"magazine": "extended_mag"})
	check(big.mag == bare.mag + 10, "an extended magazine holds ten more")
	check(Math.reload_seconds(big, true) > Math.reload_seconds(bare, true), "but takes longer to change")
	var scoped := Math.stats("m4", {"optic": "sniper_scope"})
	check(scoped.zoom > 8.0, "a scope magnifies")
	check(scoped.aim_spread < bare.aim_spread, "and puts shots closer together")


func test_a_pistol_is_not_a_rifle() -> void:
	var pistol := Math.stats("m1911")
	var rifle := Math.stats("m4")
	check(pistol.velocity < rifle.velocity * 0.4, "the .45 is slow")
	check(Shot.drop(100.0, pistol.velocity) > Shot.drop(100.0, rifle.velocity) * 5.0, "and drops far more at 100 m")
	check(Shot.drop(60.0, rifle.velocity) < 0.3, "the rifle is nearly flat inside its zero")
	var buck := Math.stats("mossberg")
	check(buck.pellets > 1 and buck.aim_spread > rifle.aim_spread * 5.0, "buckshot throws a spread of pellets")


func test_holding_still_shoots_straighter() -> void:
	var gun := Math.stats("m4")
	var hip := Math.spread(gun, 0.0, 0.0, false, 0.0)
	var aimed := Math.spread(gun, 1.0, 0.0, false, 0.0)
	var running := Math.spread(gun, 1.0, 5.0, false, 0.0)
	var crouched := Math.spread(gun, 1.0, 0.0, true, 0.0)
	var winded := Math.spread(gun, 1.0, 0.0, false, 1.0)
	check(aimed < hip, "sights beat the hip")
	check(running > aimed, "running spreads your shots")
	check(crouched < aimed, "crouching steadies them")
	check(winded > aimed, "so does not being out of breath")


func test_recoil_climbs_and_settles() -> void:
	var gun := Math.stats("uzi")
	var first := Math.recoil_kick(gun, 0, 0.5)
	var tenth := Math.recoil_kick(gun, 10, 0.5)
	check(first.y > 0.0, "the first shot kicks up")
	check(tenth.y > first.y, "and it gets worse as you hold it down")
	check(tenth.y < first.y * 3.0, "but not forever")
	check(Math.recoil_kick(gun, 0, 0.0).x < 0.0 and Math.recoil_kick(gun, 0, 1.0).x > 0.0, "it throws both ways")
	var settled := Math.settle(Vector2(0.0, 4.0), gun, 0.5)
	check(settled.y < 4.0 and settled.y > 0.0, "the sights come back down")
	var braced := Math.stats("m4", {"underbarrel": "bipod"})
	check(Math.recoil_kick(braced, 3, 0.5).y < Math.recoil_kick(Math.stats("m4"), 3, 0.5).y, "a bipod holds it down")


func test_sights_wander_less_when_you_hold_your_breath() -> void:
	var gun := Math.stats("intervention")
	var loose := 0.0
	var held := 0.0
	for i in 40:
		var t := i * 0.1
		loose = maxf(loose, Math.sway_at(gun, t, 1.0, 0.0, 0.0).length())
		held = maxf(held, Math.sway_at(gun, t, 1.0, 1.0, 0.0).length())
	check(held < loose * 0.25, "holding your breath all but stops the wander")
	check(loose > 0.1, "and it does wander otherwise")


func test_a_neglected_gun_jams() -> void:
	check(Math.jam_chance(1.0) < 0.002, "a clean gun is as good as certain")
	check(Math.jam_chance(1.0) > 0.0, "but never quite certain")
	check(Math.jam_chance(0.1) > 0.02, "a neglected one starts failing")
	check(Math.jam_chance(0.0) > Math.jam_chance(0.3), "the worse it gets the worse it gets")
	var gun := Math.stats("m4")
	var condition := 1.0
	for i in 100:
		condition = Math.wear_from_shot(gun, condition)
	check(condition < 1.0 and condition > 0.7, "a hundred rounds wears it in, not out")


func test_bullets_take_time_and_fall() -> void:
	var rifle := Math.stats("m4")
	check(Shot.flight_time(200.0, rifle.velocity) > 0.2, "a 200 m shot is not instant")
	check(Shot.flight_time(200.0, rifle.velocity) < 0.45, "but it's quick")
	var position := Vector3.ZERO
	var velocity := Vector3(0.0, 0.0, -float(rifle.velocity))
	var travelled := 0.0
	var time := 0.0
	while travelled < 300.0 and time < Shot.MAX_FLIGHT:
		var next: Array = Shot.step(position, velocity, 1.0 / 60.0)
		travelled += (Vector3(next[0]) - position).length()
		position = next[0]
		velocity = next[1]
		time += 1.0 / 60.0
	check(position.y < -0.3, "it has dropped by 300 m")
	check(velocity.length() < rifle.velocity, "and slowed down")


func test_zeroing_puts_the_round_on_the_crosshair() -> void:
	var rifle := Math.stats("m4")
	var direction: Vector3 = Shot.aim_direction(Vector3.FORWARD, rifle.velocity, Weapons.ZERO_DISTANCE)
	check(direction.y > 0.0, "the barrel sits a little above the sights")
	var position := Vector3.ZERO
	var velocity: Vector3 = direction * float(rifle.velocity)
	# Walk the round out to the zero and read off how far from the sight line it is.
	var height := 99.0
	for i in 4000:
		var previous := position
		var next: Array = Shot.step(position, velocity, 1.0 / 2000.0)
		position = next[0]
		velocity = next[1]
		if -position.z >= Weapons.ZERO_DISTANCE:
			var span := -position.z - -previous.z
			var part: float = 0.0 if span <= 0.0 else (Weapons.ZERO_DISTANCE - -previous.z) / span
			height = lerpf(previous.y, position.y, part)
			break
	check(absf(height) < 0.12, "and the round crosses the sight line at the zero (%.3f m off)" % height)


func test_fire_modes_cycle() -> void:
	var rifle := Math.stats("m4")
	check(Math.next_mode(rifle, "auto") == "semi" and Math.next_mode(rifle, "semi") == "auto", "the M4 switches between auto and semi")
	var pistol := Math.stats("m1911")
	check(Math.next_mode(pistol, "semi") == "semi", "the 1911 only does one thing")
