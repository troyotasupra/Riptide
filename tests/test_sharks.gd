extends "res://tests/test_case.gd"

const Sharks = preload("res://creatures/shark_math.gd")


func test_sharks_only_hunt_people_in_the_water() -> void:
	check(Sharks.is_prey(true, false, false, -INF), "a swimmer in open water")
	check(not Sharks.is_prey(false, true, false, -INF), "not someone aboard a boat")
	check(not Sharks.is_prey(true, true, false, -INF), "not even if they're flagged swimming while aboard")
	check(not Sharks.is_prey(true, false, false, -1.0), "not in the shallows")
	check(Sharks.is_prey(false, false, true, -10.0), "a crew member floating downed in deep water")
	check(not Sharks.is_prey(false, false, false, -10.0), "not someone standing on the seabed path or beach")


func test_weapons_matter() -> void:
	check(Sharks.weapon_damage("spear") > Sharks.weapon_damage("knife"), "a spear beats a knife")
	near(Sharks.weapon_damage(""), 0.0, 0.001, "bare hands do nothing")
	check(Sharks.weapon_damage("machete", 0.6) < Sharks.weapon_damage("machete"), "a missing arm weakens a strike")
	check(ceili(Sharks.MAX_HEALTH / Sharks.weapon_damage("spear")) <= 3, "three spear strikes kill a shark")


func test_bites_cost_limbs() -> void:
	check(not Sharks.costs_limb(1, false) and not Sharks.costs_limb(3, false), "a bite or three hurts but you keep your limbs")
	check(Sharks.costs_limb(Sharks.LIMB_BITES, false), "a mauling takes a limb")
	check(Sharks.costs_limb(Sharks.LIMB_BITES_DOWNED, true), "bitten while down, it takes one sooner")


func test_limbs_are_lost_one_at_a_time() -> void:
	var missing: Array = []
	for i in 4:
		var limb: String = Sharks.limb_to_lose(missing, 0.99)
		check(not limb.is_empty() and not missing.has(limb), "a new limb each time (%s)" % limb)
		missing.append(limb)
	check(Sharks.limb_to_lose(missing, 0.5) == "", "nothing left to take")


func test_prosthetics_restore_most_function() -> void:
	near(Sharks.speed_factor([], []), 1.0, 0.001, "two legs")
	check(Sharks.speed_factor(["leg_l"], []) < 0.6, "one leg is slow going")
	check(Sharks.speed_factor(["leg_l"], ["leg_l"]) >= 0.9, "a peg leg gets you most of the way back")
	check(Sharks.arm_factor(["arm_r"], ["arm_r"]) > Sharks.arm_factor(["arm_r"], []), "a hook beats a stump")
	check(Sharks.prosthetic_limb("leg", ["arm_l", "leg_r"], []) == "leg_r", "a peg leg goes on the missing leg")
	check(Sharks.prosthetic_limb("arm", ["leg_r"], []) == "", "no hook without a missing arm")
	check(Sharks.prosthetic_limb("leg", ["leg_r"], ["leg_r"]) == "", "not twice")


func test_downed_rules() -> void:
	check(Sharks.DOWNED_SECONDS >= 45.0, "crewmates get time to reach you")
	check(Sharks.DOWNED_SOLO_SECONDS < 10.0, "alone, you don't wait for help that isn't coming")
	check(Sharks.REVIVE_HEALTH > 0.0 and Sharks.REVIVE_HEALTH < 50.0, "revived, but hurt")
