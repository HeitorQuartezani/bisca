extends Node2D

const CardScene = preload("res://scenes/gameplay/Carta.tscn")

@export var card_spacing_default = 35
@export var card_spacing_expanded = 70

var hand_anchors: Dictionary = {}
var hand_nodes: Dictionary = { 1: [], 2: [], 3: [], 4: [] }
var table_pile_nodes: Array[Node] = []
var deck_pile_nodes: Array[Node] = []

# --- CORREÇÃO: DECLARAÇÕES DE NÓS RESTAURADAS ---
# UI de Conexão
@onready var network_ui: PanelContainer = $NetworkUI
@onready var host_button: Button = $NetworkUI/VBoxContainer/HostButton
@onready var join_button: Button = $NetworkUI/VBoxContainer/JoinButton
@onready var ip_address_edit: LineEdit = $NetworkUI/VBoxContainer/IPAddressEdit

# UI do Lobby
@onready var lobby_ui: PanelContainer = $LobbyUI
@onready var player_list_label: Label = $LobbyUI/VBoxContainer/PlayerListLabel
@onready var start_game_button: Button = $LobbyUI/VBoxContainer/StartGameButton

# UI de Fim de Jogo
@onready var game_over_screen: ColorRect = $GameOverScreen
@onready var result_message_label: Label = $GameOverScreen/ResultMessageLabel
@onready var final_score_label: Label = $GameOverScreen/FinalScoreLabel
@onready var restart_button: Button = $GameOverScreen/RestartButton

# Nós do Tabuleiro de Jogo
@onready var table_pile_anchor: Node2D = $TablePileAnchor
@onready var deck_pile_node: TextureRect = $DeckPile
@onready var vira_anchor: Node2D = $ViraAnchor
@onready var vira_click_area: Area2D = $ViraAnchor/Area2D
@onready var score_label_team1: Label = $ScoreLabel_Team1
@onready var score_label_team2: Label = $ScoreLabel_Team2
# --- FIM DA CORREÇÃO ---

var my_player_id: int = -1
var vira_card_node: Node = null
var is_interactive = false
var is_reconciling = false
var can_see_partner_hand: bool = false
var current_game_state: Dictionary = {}

func _ready():
	if not host_button.is_connected("pressed", _on_host_button_pressed):
		host_button.pressed.connect(_on_host_button_pressed)
	if not join_button.is_connected("pressed", _on_join_button_pressed):
		join_button.pressed.connect(_on_join_button_pressed)
	if not start_game_button.is_connected("pressed", _on_start_game_button_pressed):
		start_game_button.pressed.connect(_on_start_game_button_pressed)
	if not restart_button.is_connected("pressed", _on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)
	
	if not NetworkManager.assigned_player_id.is_connected(_on_assigned_player_id):
		NetworkManager.assigned_player_id.connect(_on_assigned_player_id)
	if not NetworkManager.player_list_changed.is_connected(_on_player_list_changed):
		NetworkManager.player_list_changed.connect(_on_player_list_changed)
	if not NetworkManager.game_started_for_client.is_connected(_on_game_started_for_client):
		NetworkManager.game_started_for_client.connect(_on_game_started_for_client)
	if not NetworkManager.game_state_updated_on_client.is_connected(_on_game_state_updated):
		NetworkManager.game_state_updated_on_client.connect(_on_game_state_updated)
	if not NetworkManager.round_finished_on_client.is_connected(_on_round_finished):
		NetworkManager.round_finished_on_client.connect(_on_round_finished)
	if not NetworkManager.vira_swapped_on_client.is_connected(_on_vira_swapped):
		NetworkManager.vira_swapped_on_client.connect(_on_vira_swapped)
	if not NetworkManager.vira_was_drawn_on_client.is_connected(_on_vira_was_drawn):
		NetworkManager.vira_was_drawn_on_client.connect(_on_vira_was_drawn)

	game_over_screen.visible = false
	lobby_ui.visible = false
	for i in range(1, 5): hand_anchors[i] = get_node("HandAnchor_" + str(i))

func _on_host_button_pressed():
	network_ui.hide()
	lobby_ui.show()
	NetworkManager.create_server()

func _on_join_button_pressed():
	network_ui.hide()
	lobby_ui.show()
	start_game_button.hide()
	var ip = ip_address_edit.text
	if ip.is_empty(): ip = "127.0.0.1"
	NetworkManager.join_server(ip)
	
func _on_start_game_button_pressed():
	if my_player_id == 1:
		lobby_ui.hide()
		Server.request_start_game.rpc_id(1)

func _on_assigned_player_id(p_id: int):
	my_player_id = p_id
	if my_player_id == 1:
		start_game_button.visible = true
	
func _on_player_list_changed(players: Dictionary):
	var text = ""
	for p_id in players:
		text += "Jogador %d: %s\n" % [p_id, players[p_id].name]
	player_list_label.text = text

func _on_game_started_for_client(initial_game_state: Dictionary):
	lobby_ui.hide()
	draw_initial_deck_pile()
	# Conecta o sinal apenas uma vez para a primeira animação de distribuição
	if not AnimationManager.deal_animation_finished.is_connected(_on_deal_animation_finished):
		AnimationManager.deal_animation_finished.connect(_on_deal_animation_finished)
	_on_game_state_updated(initial_game_state)

func _dict_to_card(dict: Dictionary) -> CardData:
	if dict.is_empty(): return null
	return CardData.new(dict.suit, dict.value)

func _on_game_state_updated(game_state: Dictionary):
	current_game_state = game_state
	if is_reconciling: return

	if is_interactive:
		if game_state.get("turn") == my_player_id: _unlock_player_input()
		else: _lock_player_input()
		reconcile_mid_game_state(game_state)
	else:
		_display_initial_vira(_dict_to_card(game_state.get("vira")))
		
		var hands_data_for_anim = {}
		for p_id_str in game_state.get("hands", {}):
			var p_id = int(p_id_str)
			hands_data_for_anim[p_id] = []
			for card_dict in game_state.hands[p_id_str]:
				hands_data_for_anim[p_id].append(_dict_to_card(card_dict))
		
		for p_id in hand_nodes:
			for card_node in hand_nodes[p_id]:
				if is_instance_valid(card_node): card_node.queue_free()
			hand_nodes[p_id].clear()

		AnimationManager.play_initial_deal(deck_pile_nodes, hands_data_for_anim, self)

	_update_score_display(game_state.get("scores", {1:0, 2:0}))
	_update_hands_visibility()
	_update_deck_visibility(game_state)

func _on_deal_animation_finished():
	for p_id in range(1, 5):
		update_hand_layout(p_id)

	is_interactive = true
	_update_hands_visibility()
	_update_deck_visibility(current_game_state)
	
	if current_game_state.get("turn") == my_player_id: _unlock_player_input()
	else: _lock_player_input()
	
	if multiplayer.is_server():
		Server.request_next_turn()

func _on_round_finished(round_data: Dictionary):
	is_reconciling = true
	_lock_player_input()
	
	current_game_state.scores = round_data.scores
	current_game_state.turn = round_data.winner_id
	if round_data.has("scores"): _update_score_display(round_data.scores)
	
	var last_play = round_data.get("last_play")
	if last_play:
		var card_data = _dict_to_card(last_play.card)
		var card_node_to_animate = find_card_node_by_data(last_play.player, card_data)
		if card_node_to_animate:
			hand_nodes[last_play.player].erase(card_node_to_animate)
			await AnimationManager.animate_play_card(card_node_to_animate, self)
			
	await get_tree().create_timer(0.5).timeout
	for card_node in table_pile_nodes:
		var tween = create_tween()
		tween.tween_property(card_node, "modulate:a", 0.0, 0.3)
		tween.tween_callback(card_node.queue_free)
	await get_tree().create_timer(0.4).timeout
	table_pile_nodes.clear()
	
	if round_data.get("is_final_round", false):
		_show_game_over_screen()
		return
		
	var cards_drawn = round_data.get("cards_drawn", [])
	if not cards_drawn.is_empty():
		for draw_info in cards_drawn:
			var new_card_data = _dict_to_card(draw_info.card)
			# Adiciona o card data no estado local para `find_card_node_by_data` funcionar
			if not current_game_state.hands.has(str(draw_info.player)):
				current_game_state.hands[str(draw_info.player)] = []
			current_game_state.hands[str(draw_info.player)].append(draw_info.card)
			
			var new_card_node = spawn_card(new_card_data, self)
			new_card_node.global_position = deck_pile_node.global_position
			hand_nodes[draw_info.player].append(new_card_node)
			await AnimationManager.animate_draw_card(new_card_node, draw_info.player, self)
			
	await get_tree().create_timer(0.1).timeout
	for player_id in hand_anchors.keys(): update_hand_layout(player_id)
	
	_update_hands_visibility()
	_update_deck_visibility(current_game_state)
	is_reconciling = false
	
	if current_game_state.get("turn") == my_player_id: _unlock_player_input()
	
	if multiplayer.is_server():
		Server.request_next_turn()

func _on_vira_swapped(new_vira_data: CardData, player_id: int):
	is_reconciling = true
	var old_vira_node = self.vira_card_node
	var two_node = find_card_node_by_data(player_id, new_vira_data)
	if not is_instance_valid(two_node) or not is_instance_valid(old_vira_node):
		is_reconciling = false
		if current_game_state.get("turn") == my_player_id: _unlock_player_input()
		return
	var swap_tween = create_tween().set_parallel()
	two_node.reparent(self)
	swap_tween.tween_property(two_node, "global_position", vira_anchor.global_position, 0.5)
	swap_tween.tween_property(two_node, "rotation_degrees", vira_anchor.rotation_degrees, 0.5)
	old_vira_node.reparent(self)
	var hand_anchor = hand_anchors[player_id]
	var target_pos = hand_anchor.global_position
	var target_rot = hand_anchor.rotation_degrees
	swap_tween.tween_property(old_vira_node, "global_position", target_pos, 0.5)
	swap_tween.tween_property(old_vira_node, "rotation_degrees", target_rot, 0.5)
	await swap_tween.finished
	hand_nodes[player_id].erase(two_node)
	hand_nodes[player_id].append(old_vira_node)
	self.vira_card_node = two_node
	two_node.reparent(vira_anchor)
	update_hand_layout(player_id)
	_update_hands_visibility()
	is_reconciling = false
	if current_game_state.get("turn") == my_player_id: _unlock_player_input()

func _on_vira_was_drawn(player_id: int):
	if not is_instance_valid(vira_card_node): return
	var card_to_animate = vira_card_node
	self.vira_card_node = null
	hand_nodes[player_id].append(card_to_animate)
	await AnimationManager.animate_draw_card(card_to_animate, player_id, self)
	update_hand_layout(player_id)

func spawn_card(card_data: CardData, parent_node: Node) -> Node:
	var new_card_instance = CardScene.instantiate()
	parent_node.add_child(new_card_instance)
	new_card_instance.setup(card_data)
	if not new_card_instance.card_was_clicked.is_connected(_on_player_card_clicked):
		new_card_instance.card_was_clicked.connect(_on_player_card_clicked)
	return new_card_instance

func draw_initial_deck_pile():
	for card in deck_pile_nodes:
		if is_instance_valid(card): card.queue_free()
	deck_pile_nodes.clear()
	for i in range(40):
		var new_card = CardScene.instantiate()
		add_child(new_card)
		new_card.global_position = deck_pile_node.global_position + Vector2(randf_range(-1,1), randf_range(-1,1))
		deck_pile_nodes.append(new_card)
	deck_pile_node.visible = true

func _show_game_over_screen():
	_lock_player_input()
	var final_scores = current_game_state.get("scores", {})
	var my_team_id = 1 if my_player_id in [1, 3] else 2
	var opponent_team_id = 2 if my_team_id == 1 else 1
	var my_team_score = final_scores.get(my_team_id, 0)
	var opponent_team_score = final_scores.get(opponent_team_id, 0)

	if my_team_score > opponent_team_score: result_message_label.text = "VOCÊ VENCEU!"
	elif opponent_team_score > my_team_score: result_message_label.text = "Você Perdeu"
	else: result_message_label.text = "EMPATE!"
	final_score_label.text = "Placar Final: %d a %d" % [final_scores.get(1, 0), final_scores.get(2, 0)]
	game_over_screen.z_index = 100
	game_over_screen.visible = true

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

func _on_player_card_clicked(_card_node: Node):
	_lock_player_input()

func _lock_player_input():
	if my_player_id == -1: return
	for card_node in hand_nodes.get(my_player_id, []):
		if is_instance_valid(card_node): card_node.is_playable = false
	if is_instance_valid(vira_click_area): vira_click_area.input_event.disconnect(_on_vira_click_area_input_event)

func _unlock_player_input():
	if my_player_id == -1: return
	for card_node in hand_nodes.get(my_player_id, []):
		if is_instance_valid(card_node): card_node.is_playable = true
	if is_instance_valid(vira_click_area) and not vira_click_area.input_event.is_connected(_on_vira_click_area_input_event):
		vira_click_area.input_event.connect(_on_vira_click_area_input_event)

func _update_hands_visibility():
	if not current_game_state: return
	self.can_see_partner_hand = current_game_state.get("can_see_partner_hand", false)
	var partner_id = -1
	if my_player_id in [1, 3]: partner_id = 4 - my_player_id
	if my_player_id in [2, 4]: partner_id = 6 - my_player_id
	
	for p_id in hand_nodes:
		var face_up = (p_id == my_player_id) or (p_id == partner_id and self.can_see_partner_hand)
		for card_node in hand_nodes[p_id]:
			if is_instance_valid(card_node): card_node.flip(face_up)
	
	# Lógica para mostrar a mão do parceiro
	var partner_hand_detection_anchor_3 = get_node_or_null("HandAnchor_3/PartnerHandDetectionArea")
	if is_instance_valid(partner_hand_detection_anchor_3):
		partner_hand_detection_anchor_3.get_parent().visible = (partner_id == 3)
		partner_hand_detection_anchor_3.monitoring = self.can_see_partner_hand
	
func _update_deck_visibility(game_state: Dictionary):
	var is_deck_empty = game_state.get("is_deck_empty", false)
	deck_pile_node.visible = not is_deck_empty
	if is_deck_empty and is_instance_valid(vira_card_node):
		vira_card_node.visible = false

func _on_partner_hand_detection_area_mouse_entered():
	if not can_see_partner_hand: return
	var partner_id = -1
	if my_player_id in [1, 3]: partner_id = 4 - my_player_id
	if my_player_id in [2, 4]: partner_id = 6 - my_player_id
	if partner_id != -1: update_hand_layout(partner_id, true)

func _on_partner_hand_detection_area_mouse_exited():
	if not can_see_partner_hand: return
	var partner_id = -1
	if my_player_id in [1, 3]: partner_id = 4 - my_player_id
	if my_player_id in [2, 4]: partner_id = 6 - my_player_id
	if partner_id != -1: update_hand_layout(partner_id, false)

func update_hand_layout(player_id: int, expanded: bool = false):
	var layout = calculate_hand_layout(player_id, expanded)
	for card_instance in layout:
		if not is_instance_valid(card_instance): continue
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.set_parallel()
		tween.tween_property(card_instance, "position", layout[card_instance].position, 0.3)
		tween.tween_property(card_instance, "rotation_degrees", layout[card_instance].rotation, 0.3)

func _display_initial_vira(vira_data: CardData):
	if not vira_data or is_instance_valid(vira_card_node): return
	vira_card_node = spawn_card(vira_data, self)
	vira_card_node.flip(true)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(vira_card_node, "global_position", vira_anchor.global_position, 0.3)
	tween.tween_property(vira_card_node, "rotation_degrees", vira_anchor.rotation_degrees, 0.3)
	await tween.finished
	vira_card_node.reparent(vira_anchor)
	vira_card_node.z_index = -1
	deck_pile_node.z_index = 0

func _update_score_display(scores: Dictionary):
	if not scores: return
	score_label_team1.text = "Dupla 1 (1 e 3): %d" % scores.get(1, 0)
	score_label_team2.text = "Dupla 2 (2 e 4): %d" % scores.get(2, 0)

func _on_vira_click_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_lock_player_input()
		Server.player_request_swap_vira.rpc_id(1)

func find_card_node_by_data(player_id: int, card_data: CardData) -> Node:
	if not hand_nodes.has(player_id) or not card_data: return null
	for card_node in hand_nodes[player_id]:
		if card_node.card_data.suit == card_data.suit and card_node.card_data.value == card_data.value: return card_node
	return null

func reconcile_mid_game_state(game_state: Dictionary):
	is_reconciling = true
	var server_hands = game_state.get("hands", {})
	
	for p_id_str in server_hands:
		var p_id = int(p_id_str)
		var server_count = server_hands[p_id_str].size()
		var client_count = hand_nodes.get(p_id, []).size()
		
		if client_count > server_count:
			var server_cards_in_hand_data = []
			for card_dict in server_hands[p_id_str]:
				server_cards_in_hand_data.append(_dict_to_card(card_dict))
			
			var card_to_animate = null
			for client_card_node in hand_nodes[p_id]:
				var found = false
				for server_card in server_cards_in_hand_data:
					if client_card_node.card_data.suit == server_card.suit and client_card_node.card_data.value == server_card.value:
						found = true
						break
				if not found:
					card_to_animate = client_card_node
					break
			
			if card_to_animate:
				hand_nodes[p_id].erase(card_to_animate)
				await AnimationManager.animate_play_card(card_to_animate, self)
			break
			
	is_reconciling = false
	if multiplayer.is_server():
		Server.request_next_turn()

func _on_my_hand_entered():
	if not is_interactive: return
	var can_expand = false
	for card_node in hand_nodes.get(my_player_id, []):
		if is_instance_valid(card_node) and card_node.is_playable:
			can_expand = true
			break
	if can_expand: update_hand_layout(my_player_id, true)

func _on_my_hand_exited():
	if not is_interactive: return
	update_hand_layout(my_player_id, false)

func calculate_hand_layout(player_id: int, expanded: bool = false) -> Dictionary:
	var layout = {}
	var hand_node_array = hand_nodes.get(player_id, [])
	if not hand_node_array: return layout
	
	var num_cards = hand_node_array.size()
	if num_cards == 0: return layout
	
	var current_spacing = card_spacing_default
	var my_partner_id = -1
	if my_player_id in [1, 3]: my_partner_id = 4 - my_player_id
	if my_player_id in [2, 4]: my_partner_id = 6 - my_player_id

	if (player_id == my_player_id or (player_id == my_partner_id and can_see_partner_hand)) and expanded:
		current_spacing = card_spacing_expanded
		
	var total_size = (num_cards - 1) * current_spacing
	var start_pos_val = -total_size / 2.0
	for i in range(num_cards):
		var card_instance = hand_node_array[i]
		if not is_instance_valid(card_instance): continue
		var new_pos: Vector2; var new_rot: float = 0.0
		match player_id:
			1: new_pos = Vector2(start_pos_val + i * current_spacing, 0); new_rot = 0
			2: new_pos = Vector2(0, start_pos_val + i * current_spacing); new_rot = -90
			3: new_pos = Vector2(start_pos_val + i * current_spacing, 0); new_rot = 180
			4: new_pos = Vector2(0, start_pos_val + i * current_spacing); new_rot = 90
		layout[card_instance] = {"position": new_pos, "rotation": new_rot}
	return layout
