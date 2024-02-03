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
	
	var game = _find_game(id)
	if game:
		_games.erase(game)
		_update_game_list_on_peers()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


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
func set_game_list(game_list: Array):
	var sender_id = multiplayer.get_remote_sender_id()
	
	print("Game list set on %s" % sender_id)


@rpc("any_peer", "reliable")
func create_game(name: String):
	if len(_games) > 256:
		print("Too many games already created")
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	var game = _find_game(sender_id)
	if game:
		print("Peer %s is already participates in a game %s" % game.name)
		return
	
	game = Game.new()
	game.name = name
	game.peer_id = sender_id
	
	_games.append(game)
	print("%s created new game [%s]" % [sender_id, name])
	
	_update_game_list_on_peers()
	create_game.rpc_id(sender_id, name)


@rpc("any_peer", "reliable")
func join_game(name: String):
	var sender_id = multiplayer.get_remote_sender_id()
	
	for game in _games:
		if game.name != name:
			continue
		
		if game.state == Game.WAITING_OPPONENT:
			print("%s joined %s" % [sender_id, name])
			game.opponent_found(sender_id)
			join_game.rpc_id(sender_id, name)
			_update_game_list_on_peers()
			return
	
	print("Couldn find game %s for peer %s" % [name, sender_id])


@rpc("any_peer", "reliable")
func placement_completed(_goes_first: bool):
	var sender_id = multiplayer.get_remote_sender_id()
	var game = _find_game(sender_id)
	if not game:
		print("No game found for %s" % sender_id)
		return
	
	game.placement_complete(sender_id)
	var goes_first = (game.get_peer_role(sender_id) == Game.HOST)
	print("Placement completed for %s, goes first %s" % [sender_id, goes_first])
	placement_completed.rpc_id(sender_id, goes_first)
