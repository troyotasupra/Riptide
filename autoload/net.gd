extends Node
## Co-op session over ENet. The host (peer 1) owns the world; up to five
## friends join by IP. The roster lives here so every peer knows who is in the
## world, what they look like, and whose world has finished loading ("ready").
##
## Join flow:
##   client connects -> loads world scene -> asks host for a welcome (name, id, look)
##   host replies with seed + clock + crew colours -> client builds the same world
##   client reports ready -> host spawns everyone for everyone

signal status(message: String)
signal roster_changed
signal welcomed
signal peer_ready(peer_id: int)
signal peer_left(peer_id: int)

const DEFAULT_PORT := 24570
const MAX_PLAYERS := 6
## Bump this by hand whenever the netcode, the save format or world generation
## changes shape. Two copies with different numbers can't play together, and the
## host turns the odd one away with a message instead of letting them join and
## quietly fall out of step.
const PROTOCOL_VERSION := 1
const MENU_SCENE := "res://ui/main_menu.tscn"
const WORLD_SCENE := "res://world/world.tscn"
const CLOCK_INTERVAL := 1.0
## How long a joining crew member waits for the host's welcome before giving up.
## Godot refuses to route RPCs between two copies whose methods don't match (its
## "rpc node checksum"), so a host on different netcode can't even tell us why
## it went quiet. Waiting and then saying so is the only thing that always works.
const WELCOME_TIMEOUT := 10.0

var local_name := "Sailor"
var port := DEFAULT_PORT
## peer_id -> {"name": String, "ready": bool, "id": String, "look": Dictionary}
var roster := {}
## Shown on the menu after being sent back to it.
var last_message := ""

var _clock_accum := 0.0
var _leaving := false
var _welcomed := false
## Worked out once, the first time anybody asks.
static var _content_id := ""


func _ready() -> void:
	local_name = Profile.player_name
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if not is_hosting():
		return
	_clock_accum += delta
	if _clock_accum >= CLOCK_INTERVAL:
		_clock_accum = 0.0
		_clock.rpc(Ocean.time)


func is_hosting() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.is_server()


func host_game(p_port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(p_port, MAX_PLAYERS - 1)
	if err != OK:
		status.emit("Could not host on port %d (error %d). Is another copy already hosting?" % [p_port, err])
		return err
	port = p_port
	multiplayer.multiplayer_peer = peer
	GameState.crew_color = SaveGame.pending.get("crew_color", Profile.crew_color)
	GameState.emblem = SaveGame.pending.get("emblem", Profile.emblem)
	roster = {1: {"name": local_name, "ready": false, "id": Profile.player_id, "look": Profile.look.duplicate()}}
	print("[net] hosting on port %d as %s" % [p_port, local_name])
	get_tree().change_scene_to_file.call_deferred(WORLD_SCENE)
	return OK


func join_game(address: String, p_port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, p_port)
	if err != OK:
		status.emit("Could not start connecting to %s:%d (error %d)." % [address, p_port, err])
		return err
	port = p_port
	multiplayer.multiplayer_peer = peer
	status.emit("Connecting to %s:%d..." % [address, p_port])
	return OK


func leave_game(message: String = "") -> void:
	_leaving = true
	if is_hosting() and GameState.world != null:
		GameState.world.save_now()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster.clear()
	last_message = message
	GameState.local_player = null
	GameState.objectives_done.clear()
	Sound.stop_ambience()
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
	_leaving = false


## Send an RPC to every peer whose world is loaded, except ourselves.
func send_to_ready(node: Node, method: StringName, args: Array = []) -> void:
	var me := multiplayer.get_unique_id()
	for id: int in roster:
		if id != me and roster[id].get("ready", false):
			node.callv("rpc_id", [id, method] + args)


func set_local_name(value: String) -> void:
	local_name = _clean_name(value)
	Profile.player_name = local_name
	Profile.save_profile()


func player_id_of(peer_id: int) -> String:
	return roster.get(peer_id, {}).get("id", "peer%d" % peer_id)


func look_of(peer_id: int) -> Dictionary:
	return AppearanceTable.sanitize(roster.get(peer_id, {}).get("look", {}))


# --- world handshake -------------------------------------------------------

func request_welcome() -> void:
	_welcomed = false
	_request_welcome.rpc_id(1, local_name, Profile.player_id, Profile.look, PROTOCOL_VERSION, content_id())
	_give_up_unless_welcomed()


## A host on different netcode never answers at all, and Godot gives us nothing
## to show for it but errors in the log. Say what it almost always means.
func _give_up_unless_welcomed() -> void:
	await get_tree().create_timer(WELCOME_TIMEOUT).timeout
	if _welcomed or _leaving or is_hosting() or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	print("[net] no welcome from the host after %.0fs — giving up" % WELCOME_TIMEOUT)
	leave_game("The host never answered. That usually means you're running different versions of "
		+ "Riptide — make sure you both have the same copy of the game.")


## A fingerprint of the content both sides have to agree on, built from the
## *names* in the data tables and never their values: adding, removing or
## renaming an item, recipe, structure, weapon or resource changes it, while
## tuning a number doesn't. Only sorted strings go in, so two machines on
## different platforms always work out the same answer.
static func content_id() -> String:
	if not _content_id.is_empty():
		return _content_id
	var tables: Array[Dictionary] = [ItemTable.ITEMS, RecipeTable.RECIPES, StructureTable.TYPES,
			WeaponTable.WEAPONS, ResourceTable.KINDS]
	var parts := PackedStringArray()
	for table: Dictionary in tables:
		var ids := PackedStringArray()
		for key: Variant in table:
			ids.append(String(key))
		ids.sort()
		parts.append("|".join(ids))
	_content_id = "#".join(parts).sha256_text().left(8)
	return _content_id


## Empty when `peer` may join, otherwise what to tell them.
static func version_refusal(protocol: int, content: String) -> String:
	if protocol != PROTOCOL_VERSION:
		return ("You and the host are running different versions of Riptide "
			+ "(the host is on build %d, you're on build %d). " % [PROTOCOL_VERSION, protocol]
			+ "Get the same copy of the game as the host and try again.")
	if content != content_id():
		return ("You and the host have different versions of Riptide: the game data doesn't match "
			+ "(the host has %s, you have %s). " % [content_id(), content]
			+ "Get the same copy of the game as the host and try again.")
	return ""


func report_world_ready() -> void:
	if multiplayer.is_server():
		_mark_ready(1)
	else:
		_world_ready.rpc_id(1)


## The two version arguments default to values no real build sends, so a copy
## that doesn't send them is turned away rather than let in.
##
## In practice a build old enough to leave them out never reaches this function:
## Godot compares the RPC methods on both sides first ("rpc node checksum") and
## refuses to route anything at all. That's what WELCOME_TIMEOUT is for. These
## defaults only cover the narrower case of a build that still has the same
## methods but calls this one with fewer arguments.
@rpc("any_peer", "call_remote", "reliable")
func _request_welcome(player_name: String, player_id: String, look: Dictionary,
		protocol: int = 0, content: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var refusal := version_refusal(protocol, content)
	if not refusal.is_empty():
		print("[net] turned peer %d away: build %d/%s, we're build %d/%s" % [
			peer, protocol, content, PROTOCOL_VERSION, content_id()])
		_refused.rpc_id(peer, refusal)
		_drop_later(peer)
		return
	var clean_id := player_id.left(32).validate_filename()
	if clean_id.is_empty():
		clean_id = "peer%d" % peer
	for other: int in roster:
		if roster[other].get("id", "") == clean_id:
			clean_id += "-%d" % peer  # two copies of one profile on the same PC
			break
	roster[peer] = {"name": _clean_name(player_name), "ready": false, "id": clean_id, "look": AppearanceTable.sanitize(look)}
	_welcome.rpc_id(peer, GameState.world_seed, Ocean.time, GameState.day_offset, GameState.crew_color, GameState.emblem)
	_push_roster()


## Host: the refusal is sent first and the peer is dropped a moment later, so the
## message has time to arrive even if their copy is too old to act on it.
func _drop_later(peer: int) -> void:
	await get_tree().create_timer(2.0).timeout
	if is_hosting() and not roster.has(peer):
		multiplayer.multiplayer_peer.disconnect_peer(peer)


@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	print("[net] the host turned us away: %s" % reason)
	leave_game(reason)


@rpc("authority", "call_remote", "reliable")
func _welcome(world_seed: int, host_time: float, day_offset: float, crew_color: int, emblem: int) -> void:
	GameState.world_seed = world_seed
	GameState.day_offset = day_offset
	GameState.crew_color = crew_color
	GameState.emblem = emblem
	Ocean.time = host_time - Ocean.PRESENTATION_DELAY
	_welcomed = true
	print("[net] welcomed: seed %d, host clock %.2f" % [world_seed, host_time])
	welcomed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _world_ready() -> void:
	if multiplayer.is_server():
		_mark_ready(multiplayer.get_remote_sender_id())


func _mark_ready(id: int) -> void:
	if not roster.has(id):
		return
	roster[id]["ready"] = true
	print("[net] peer %d (%s) is in the world" % [id, roster[id]["name"]])
	_push_roster()
	peer_ready.emit(id)


func _push_roster() -> void:
	_set_roster.rpc(roster)
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _set_roster(new_roster: Dictionary) -> void:
	roster = new_roster
	roster_changed.emit()


@rpc("authority", "call_remote", "unreliable")
func _clock(host_time: float) -> void:
	Ocean.sync_from_host(host_time)


# --- connection events -----------------------------------------------------

func _on_connected_to_server() -> void:
	status.emit("Connected. Loading the world...")
	get_tree().change_scene_to_file.call_deferred(WORLD_SCENE)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	status.emit("Could not reach the host. Check the address, port and firewall.")


func _on_server_disconnected() -> void:
	if not _leaving:
		leave_game("The host closed the session.")


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not roster.has(id):
		return
	print("[net] peer %d (%s) left" % [id, roster[id]["name"]])
	roster[id]["ready"] = false  # nobody may send them anything while the world cleans up
	peer_left.emit(id)
	roster.erase(id)
	_push_roster()


static func _clean_name(value: String) -> String:
	var cleaned := value.strip_edges().left(16)
	return cleaned if not cleaned.is_empty() else "Sailor"
