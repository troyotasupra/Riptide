extends Node
## Co-op session over ENet. The host (peer 1) owns the world; up to five
## friends join by IP. The roster lives here so every peer knows who is in the
## world and whose world has finished loading ("ready").
##
## Join flow:
##   client connects -> loads world scene -> asks host for a welcome
##   host replies with seed + clock -> client builds the same world
##   client reports ready -> host spawns everyone for everyone

signal status(message: String)
signal roster_changed
signal welcomed
signal peer_ready(peer_id: int)
signal peer_left(peer_id: int)

const DEFAULT_PORT := 24570
const MAX_PLAYERS := 6
const MENU_SCENE := "res://ui/main_menu.tscn"
const WORLD_SCENE := "res://world/world.tscn"
const CLOCK_INTERVAL := 1.0

var local_name := "Sailor"
var port := DEFAULT_PORT
## peer_id -> {"name": String, "ready": bool}
var roster := {}
## Shown on the menu after being sent back to it.
var last_message := ""

var _clock_accum := 0.0
var _leaving := false


func _ready() -> void:
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
	roster = {1: {"name": local_name, "ready": false}}
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


# --- world handshake -------------------------------------------------------

func request_welcome() -> void:
	_request_welcome.rpc_id(1, local_name)


func report_world_ready() -> void:
	if multiplayer.is_server():
		_mark_ready(1)
	else:
		_world_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_welcome(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	roster[id] = {"name": _clean_name(player_name), "ready": false}
	_welcome.rpc_id(id, GameState.world_seed, Ocean.time, GameState.day_offset)
	_push_roster()


@rpc("authority", "call_remote", "reliable")
func _welcome(world_seed: int, host_time: float, day_offset: float) -> void:
	GameState.world_seed = world_seed
	GameState.day_offset = day_offset
	Ocean.time = host_time - Ocean.PRESENTATION_DELAY
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
	roster.erase(id)
	_push_roster()
	peer_left.emit(id)


static func _clean_name(value: String) -> String:
	var cleaned := value.strip_edges().left(16)
	return cleaned if not cleaned.is_empty() else "Sailor"
