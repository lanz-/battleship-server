class_name Game
extends RefCounted

enum {WAITING_OPPONENT, PLACING_SHIPS, PLAYING}
enum {HOST, OPPONENT, UNKNOWN}

var name: String = ""
var peer_id: int = -1
var opponent_id: int = -1

var state = WAITING_OPPONENT

var _host_placed = false
var _opponent_placed = false


func get_peer_role(id: int):
	if opponent_id == id:
		return OPPONENT
	
	if peer_id == id:
		return HOST
	
	return UNKNOWN


func opponent_found(id: int):
	opponent_id = id
	state = PLACING_SHIPS


func placement_complete(id: int):
	if id == opponent_id:
		_opponent_placed = true
	elif id == peer_id:
		_host_placed = true
	
	if _host_placed and _opponent_placed:
		state = PLAYING

