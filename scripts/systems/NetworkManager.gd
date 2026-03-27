extends Node

# Sinais que o PlayerView vai ouvir
signal player_list_changed(players_data)
signal game_started_for_client(initial_game_state)
signal assigned_player_id(player_id)
signal game_state_updated_on_client(game_state)
signal round_finished_on_client(round_data)
signal vira_swapped_on_client(new_vira_data, player_id)
signal vira_was_drawn_on_client(player_id)


# Mapeia o peer_id (ID de rede) para o player_id (1-4)
var peer_to_player_map: Dictionary = {}
# Mapeia o player_id (1-4) para os dados do jogador (nome, peer_id)
var players_data: Dictionary = {}

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func create_server():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(7777, 3) # Max 3 clientes + 1 host
	if error != OK:
		print("ERRO: Não foi possível criar o servidor.")
		return
	multiplayer.multiplayer_peer = peer
	print("Servidor criado. Esperando jogadores...")
	_add_player(1, "Host (Jogador 1)")

func join_server(ip_address: String):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, 7777)
	if error != OK:
		print("ERRO: Não foi possível conectar ao servidor.")
		return
	multiplayer.multiplayer_peer = peer
	print("Conectando ao servidor em ", ip_address)

func get_player_id_from_peer_id(peer_id: int) -> int:
	# Para chamadas locais do servidor, o peer_id é 0. Tratamos como 1.
	if peer_id == 0: return 1
	return peer_to_player_map.get(peer_id, -1)

func is_player_human(player_id: int) -> bool:
	return player_id in players_data

func _on_connected_to_server():
	print("Conectado ao servidor. Aguardando ID...")

func _on_peer_connected(peer_id: int):
	if not multiplayer.is_server(): return
	print("Peer %d se conectou." % peer_id)
	var player_name = "Jogador %d" % peer_id
	var new_player_id = _add_player(peer_id, player_name)
	if new_player_id != -1:
		assign_player_id.rpc_id(peer_id, new_player_id)
		update_player_list_on_clients.rpc(players_data)

func _on_peer_disconnected(peer_id: int):
	if not multiplayer.is_server(): return
	print("Peer %d se desconectou." % peer_id)
	var player_id_to_remove = get_player_id_from_peer_id(peer_id)
	if player_id_to_remove != -1:
		players_data.erase(player_id_to_remove)
		peer_to_player_map.erase(peer_id)
		print("Jogador %d removido." % player_id_to_remove)
		update_player_list_on_clients.rpc(players_data)

func _add_player(peer_id: int, player_name: String) -> int:
	var new_player_id = -1
	for i in range(1, 5):
		if not i in players_data:
			new_player_id = i
			break
	if new_player_id != -1:
		players_data[new_player_id] = { "name": player_name, "peer_id": peer_id }
		peer_to_player_map[peer_id] = new_player_id
		print("Peer %d atribuído como Jogador %d" % [peer_id, new_player_id])
		if peer_id == 1:
			emit_signal("player_list_changed", players_data)
			emit_signal("assigned_player_id", 1)
	else:
		print("Não há slots de jogador vagos.")
	return new_player_id

# --- RPCs que o CLIENTE chama ou recebe ---
@rpc("any_peer")
func assign_player_id(p_id: int):
	print("Recebi meu ID de jogador: ", p_id)
	emit_signal("assigned_player_id", p_id)

@rpc("any_peer")
func update_player_list_on_clients(new_players_data: Dictionary):
	self.players_data = new_players_data
	print("Lista de jogadores atualizada: ", players_data)
	emit_signal("player_list_changed", players_data)

@rpc("any_peer")
func notify_game_start(initial_game_state: Dictionary):
	print("Notificação de início de jogo recebida.")
	emit_signal("game_started_for_client", initial_game_state)

# --- RPCs que o SERVIDOR chama para atualizar os clientes ---
@rpc("any_peer", "call_local")
func sync_game_state(game_state: Dictionary):
	emit_signal("game_state_updated_on_client", game_state)

@rpc("any_peer", "call_local")
func sync_round_finished(round_data: Dictionary):
	emit_signal("round_finished_on_client", round_data)

@rpc("any_peer", "call_local")
func sync_vira_swapped(new_vira_data_dict: Dictionary, player_id: int):
	# Dicionários são mais seguros para RPCs do que objetos customizados
	var new_vira_data = CardData.new(new_vira_data_dict.suit, new_vira_data_dict.value)
	emit_signal("vira_swapped_on_client", new_vira_data, player_id)

@rpc("any_peer", "call_local")
func sync_vira_was_drawn(player_id: int):
	emit_signal("vira_was_drawn_on_client", player_id)
