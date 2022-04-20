extends Control

const DEFAULT_PORT = 8910

var chatters_info = {}
var my_info = { name = "" }

var peer = null

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	$chat_panel/connect_dialog.popup()

func _player_connected(id):
	# Called on both clients and server when a peer connects. Send my info to it.
	rpc_id(id, "register_chatter", my_info)

func _player_disconnected(id):
	print("Chatter " + chatters_info[id].name + " left")
	rpc("display_notification", "Chatter " + chatters_info[id].name + " left\n")
	var chatter_id = get_index_by_text($chat_panel/VBoxContainer/HBoxContainer2/chatter_list, chatters_info[id].name)
	$chat_panel/VBoxContainer/HBoxContainer2/chatter_list.remove_item(chatter_id)
	chatters_info.erase(id) # Erase chatter from info.

func _connected_ok():
	pass # Only called on clients, not server. Will go unused; not useful here.

func _server_disconnected():
	pass # Server kicked us; show error and abort.

func _connected_fail():
	display_error("Couldn't connect\n")
	get_tree().set_network_peer(null) # Remove peer.

remote func register_chatter(info):
	# Get the id of the RPC sender.
	var id = get_tree().get_rpc_sender_id()
	# Store the info
	chatters_info[id] = info
	print("New chatter: " + info.name)
	display_notification("New chatter: " + info.name + "\n")
	$chat_panel/VBoxContainer/HBoxContainer2/chatter_list.add_item(info.name, null, false)

remotesync func display_chat(name, chat_text):
	var chatBox = $chat_panel/VBoxContainer/HBoxContainer2/read_text
	chatBox.add_text(name + ": " + chat_text + "\n")

func display_error(error_text):
	$chat_panel/VBoxContainer/HBoxContainer2/read_text.add_text("Error: " + error_text + "\n")

func get_index_by_text(chatters, search) -> int:
	if not chatters:
		return -1
	var item_count = chatters.get_item_count()
	for i in range(item_count):
		var item_text = chatters.get_item_text(i)
		if item_text == search:
			return i
	return -1

remotesync func display_notification(notification):
	$chat_panel/VBoxContainer/HBoxContainer2/read_text.add_text(notification)

func _on_host_button_pressed():
	peer = NetworkedMultiplayerENet.new()
	peer.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_RANGE_CODER)
	var err = peer.create_server(DEFAULT_PORT, 10) # Maximum of 1 peer, since it's a 2-player game.
	if err != OK:
		# Is another server running?
		display_error("Can't host, address already in use?\n")
		print("Can't host, address in use.")
		return

	get_tree().set_network_peer(peer)
	my_info.name = $chat_panel/connect_dialog/MarginContainer/VBoxContainer/HBoxContainer/name_edit.get_text()
	$chat_panel/connect_dialog.hide()

func _on_join_button_pressed():
	var ip = $chat_panel/connect_dialog/MarginContainer/VBoxContainer/HBoxContainer/address_edit.get_text()
	if not ip.is_valid_ip_address():
		print("IP address is invalid")
		display_error("IP address invalid\n")
		return

	peer = NetworkedMultiplayerENet.new()
	peer.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_RANGE_CODER)
	peer.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(peer)
	my_info.name = $chat_panel/connect_dialog/MarginContainer/VBoxContainer/HBoxContainer/name_edit.get_text()

	print("Connecting...")
	display_notification("Connecting...\n")
	$chat_panel/connect_dialog.hide()

func _on_send_button_pressed():
	var send_text = $chat_panel/VBoxContainer/HBoxContainer/send_text.get_text()
	$chat_panel/VBoxContainer/HBoxContainer/send_text.clear()
	rpc("display_chat", my_info.name, send_text)

func _on_send_text_text_entered(new_text):
	$chat_panel/VBoxContainer/HBoxContainer/send_text.clear()
	rpc("display_chat", my_info.name, new_text)


func _on_name_edit_text_changed(new_text):
	if(new_text != ""):
		$chat_panel/connect_dialog/MarginContainer/VBoxContainer/HBoxContainer2/CenterContainer2/join_button.disabled = false
	else:
		$chat_panel/connect_dialog/MarginContainer/VBoxContainer/HBoxContainer2/CenterContainer2/join_button.disabled = true
