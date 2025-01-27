extends Node


signal server_created                          # when server is successfully created
signal server_not_created                      # I made this
signal join_success                            # When the peer successfully joins a server
signal join_fail                               # Failed to join a server
signal player_list_changed                     # List of players has been changed

var server_info = {
	name = "Server",      # Holds the name of the server
	max_players = 8,      # Maximum allowed connections
	used_port = 4546  #11011         # Listening port
}

var players = {}

func _ready():
	get_tree().connect("network_peer_connected", self, "_on_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_player_disconnected")
	get_tree().connect("connected_to_server", self, "_on_connected_to_server")
	get_tree().connect("connection_failed", self, "_on_connection_failed")
	get_tree().connect("server_disconnected", self, "_on_disconnected_from_server")



	print("singleton runs by itself but you can call me " + self.get_name())

func create_server():
	# Initialize the networking system
	var net = NetworkedMultiplayerENet.new()

	# Try to create the server
	if (net.create_server(server_info.used_port, server_info.max_players) != OK):
		print("Failed to create server")
		emit_signal("server_not_created")
		return
	else:
		print ("server data inputed")
	# Assign it into the tree
	get_tree().set_network_peer(net)

	# Signals the servers creation
	emit_signal("server_created")

	# Register the server's player in the local player list
	register_player(Gamestate.player_info)

func join_server(ip, port):
	var net = NetworkedMultiplayerENet.new()
	if (net.create_client(ip, port) != OK):
		print("Failed to join server")
		emit_signal("join_fail")
		return
	else:
		print("joining server...")
		#emit_signal("join_success")
	get_tree().set_network_peer(net)

remote func register_player(pinfo):
	if (get_tree().is_network_server()):
		# We are on the server, so distribute the player list information throughout the connected players
		for id in players:
			# Send currently iterated player info to the new player
			rpc_id(pinfo.net_id, "register_player", players[id])
			# Send new player info to currently iterated player, skipping the server (which will get the info shortly)
			if (id != 1):
				rpc_id(id, "register_player", pinfo)
			else:
				print("hey at least the server get the message")
	# Now to code that will be executed regardless of being on client or server
	print("Registering player ", pinfo.name, " (", pinfo.net_id, ") to internal player table")
	players[pinfo.net_id] = pinfo          # Create the player entry in the dictionary
	emit_signal("player_list_changed")     # And notify that the player list has been changed


# Everyone gets notified whenever a new client joins the server
func _on_player_connected(id):
	emit_signal("join_success")

	# Update the player_info dictionary with the obtained unique network ID
	Gamestate.player_info.net_id = get_tree().get_network_unique_id()
	# Request the server to register this new player across all connected players
	rpc_id(1, "register_player", Gamestate.player_info)
	# And register itself on the local list
	register_player(Gamestate.player_info)

# Everyone gets notified whenever someone disconnects from the server
func _on_player_disconnected(id):
	pass
# Peer trying to connect to server is notified on success
func _on_connected_to_server():
	print("you've connected")
	emit_signal("join_success")
# Peer trying to connect to server is notified on failure
func _on_connection_failed():
	emit_signal("join_fail")
	get_tree().set_network_peer(null)
# Peer is notified when disconnected from server
func _on_disconnected_from_server():
	pass
