class_name Lobby
extends Node


var _games = []


# Called when the node enters the scene tree for the first time.
func _ready():
	var peer = WebSocketMultiplayerPeer.new()
	peer.create_server(5858, "127.0.0.1")
	multiplayer.multiplayer_peer = peer
	
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(id: int):
	print("Connected ", id)

	_update_game_list_on_peers()


func _on_peer_disconnected(id: int):
	print("Disonnected ", id)
	
	var game: Game = _find_game(id)
	if game:
		_games.erase(game)
		var peer_id = game.get_peer_id(id)
		peer_left_the_game.rpc_id(peer_id)
		_update_game_list_on_peers()


func _update_game_list_on_peers():
	var game_list = []
	for game in _games:
		if game.state != Game.WAITING_OPPONENT:
			continue
		
		game_list.append(game.name)
	
	print("Updating game list on peers: %s" % [game_list])
	set_game_list.rpc(game_list)


func _find_game(peer_id: int):
	for game in _games:
		if game.get_peer_role(peer_id) != Game.UNKNOWN:
			return game
	
	return null


@rpc("any_peer", "reliable")
func set_game_list(_game_list: Array):
	var sender_id = multiplayer.get_remote_sender_id()
	
	print("Game list set on %s" % sender_id)


@rpc("any_peer", "reliable")
func create_game(game_name: String):
	if len(_games) > 256:
		print("Too many games already created")
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	var game = _find_game(sender_id)
	if game:
		print("Peer %s is already participates in a game %s" % game.name)
		return
	
	game = Game.new()
	game.name = game_name
	game.peer_id = sender_id
	
	_games.append(game)
	print("%s created new game [%s]" % [sender_id, game_name])
	
	_update_game_list_on_peers()
	create_game.rpc_id(sender_id, game_name)


@rpc("any_peer", "reliable")
func join_game(game_name: String):
	var sender_id = multiplayer.get_remote_sender_id()
	
	for game in _games:
		if game.name != game_name:
			continue
		
		if game.state == Game.WAITING_OPPONENT:
			print("%s joined %s" % [sender_id, game_name])
			game.opponent_found(sender_id)
			join_game.rpc_id(sender_id, game_name)
			join_game.rpc_id(game.peer_id, game_name)
			_update_game_list_on_peers()
			return
	
	print("Couldn find game %s for peer %s" % [game_name, sender_id])


@rpc("any_peer", "reliable")
func placement_completed(ship_list):
	var sender_id = multiplayer.get_remote_sender_id()
	var game: Game = _find_game(sender_id)
	if not game:
		print("No game found for %s" % sender_id)
		return
	
	game.placement_complete(sender_id, ship_list)
	
	if game.state == Game.PLAYING:
		print("Starting game %s between %s and %s" % [game.name, game.peer_id, game.opponent_id])
		placement_completed.rpc_id(game.peer_id, game.opponent_ships)
		placement_completed.rpc_id(game.opponent_id, game.host_ships)


@rpc("any_peer", "reliable")
func fire_at(pos: Vector2i):
	var sender_id = multiplayer.get_remote_sender_id()
	var game: Game = _find_game(sender_id)
	if not game:
		print("No game found for %s" % sender_id)
		return
	
	var peer_id = game.get_peer_id(sender_id)
	print("%s firing at %s" % [sender_id, pos])
	fire_at.rpc_id(peer_id, pos)


@rpc("any_peer", "reliable")
func fence_fire_remote():
	var sender_id = multiplayer.get_remote_sender_id()
	var game: Game = _find_game(sender_id)
	if not game:
		print("No game found for %s" % sender_id)
		return
	
	print("Fire fence for %s" % sender_id)
	fence_fire_remote.rpc_id(game.get_peer_id(sender_id))


@rpc("reliable")
func peer_left_the_game():
	pass
