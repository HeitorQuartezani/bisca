extends Node

# O servidor não emite mais sinais para o PlayerView.
# Ele chama o NetworkManager para fazer isso.

var bot_turn_timer: Timer = Timer.new()

var deck: Array[CardData] = []
var suits = ["hearts", "diamonds", "clubs", "spades"]
var values = [1, 2, 3, 4, 5, 6, 7, 11, 12, 13]

var player_hands_data: Dictionary = { 1: [], 2: [], 3: [], 4: [] }
var cards_on_table: Array = []
var current_player_id = 1

var team_scores = {1: 0, 2: 0}
var vira: CardData = null
var trunfo_suit: String = ""
var vira_has_been_drawn: bool = false

var rounds_played: int = 0
var is_last_hand: bool = false
var is_game_over: bool = false

func _ready():
	add_child(bot_turn_timer)
	bot_turn_timer.wait_time = 1.0
	bot_turn_timer.one_shot = true
	bot_turn_timer.timeout.connect(take_bot_turn)

func reset_game():
	deck.clear()
	player_hands_data = { 1: [], 2: [], 3: [], 4: [] }
	cards_on_table.clear()
	team_scores = {1: 0, 2: 0}
	current_player_id = 1
	vira = null; trunfo_suit = ""; vira_has_been_drawn = false
	rounds_played = 0; is_last_hand = false; is_game_over = false
	create_deck()
	shuffle_deck()
	print("Servidor: Jogo reiniciado. Baralho pronto.")

@rpc("call_local")
func request_start_game():
	print("Host solicitou início do jogo. Distribuindo cartas...")
	reset_game()
	vira = deck.pop_back()
	trunfo_suit = vira.suit
	print("Servidor: A vira é ", vira, ". O trunfo é ", trunfo_suit)
	deal_initial_hands()
	
	NetworkManager.notify_game_start.rpc(get_game_state_for_rpc())

func draw_card() -> CardData:
	if not deck.is_empty(): return deck.pop_front()
	elif not vira_has_been_drawn:
		vira_has_been_drawn = true
		return vira
	return null

@rpc("any_peer", "call_local")
func player_action_play_card(card_suit: String, card_value: int):
	var sender_peer_id = multiplayer.get_remote_sender_id()
	var player_id = NetworkManager.get_player_id_from_peer_id(sender_peer_id)
	
	if player_id == -1: return
	
	var card_to_play = CardData.new(card_suit, card_value)
	_play_card(player_id, card_to_play)

func _play_card(player_id: int, card_to_play: CardData):
	if is_game_over or player_id != current_player_id: return

	var card_found_in_hand = false
	for card in player_hands_data[player_id]:
		if card.suit == card_to_play.suit and card.value == card_to_play.value:
			player_hands_data[player_id].erase(card)
			card_found_in_hand = true
			break
	if not card_found_in_hand: return
		
	var played_card_info = {"player": player_id, "card": _card_data_to_dict(card_to_play)}
	cards_on_table.append(played_card_info)
	print("Servidor: Jogador ", player_id, " jogou ", card_to_play)
	
	if cards_on_table.size() == 4:
		_end_round(played_card_info)
	else:
		current_player_id = (current_player_id % 4) + 1
		emit_game_state()

func _end_round(last_play_info: Dictionary):
	await get_tree().create_timer(0.8).timeout
	var winner_id = determine_round_winner()
	var winner_team = 1 if winner_id in [1, 3] else 2
	var round_points = 0
	for play in cards_on_table:
		round_points += _dict_to_card_data(play["card"]).points
	team_scores[winner_team] += round_points
	print("Servidor: Fim da rodada. Vencedor: Jogador %d. Pontos: %d. Placar: T1[%d] x T2[%d]" % [winner_id, round_points, team_scores[1], team_scores[2]])
	
	var round_data = { "last_play": last_play_info, "winner_id": winner_id, "cards_drawn": [], "is_final_round": false, "scores": team_scores }
	cards_on_table.clear()
	
	var hands_are_empty = true
	for hand in player_hands_data.values():
		if not hand.is_empty():
			hands_are_empty = false
			break
	if is_last_hand and hands_are_empty:
		is_game_over = true
		round_data["is_final_round"] = true
		NetworkManager.sync_round_finished.rpc(round_data)
		return
		
	var cards_drawn_info = []
	var draw_order = []
	for i in range(4): draw_order.append(((winner_id - 1 + i) % 4) + 1)
	
	for player_id in draw_order:
		var new_card = draw_card()
		if new_card:
			if new_card == vira and vira_has_been_drawn:
				NetworkManager.sync_vira_was_drawn.rpc(player_id)
			player_hands_data[player_id].append(new_card)
			cards_drawn_info.append({"player": player_id, "card": _card_data_to_dict(new_card)})
			if not vira_has_been_drawn and new_card.value == 2 and new_card.suit == trunfo_suit and not NetworkManager.is_player_human(player_id):
				get_tree().create_timer(0.5).timeout.connect(_bot_request_swap.bind(player_id))
	
	round_data["cards_drawn"] = cards_drawn_info
	rounds_played += 1
	if deck.is_empty() and vira_has_been_drawn and not is_last_hand:
		is_last_hand = true
		
	current_player_id = winner_id
	NetworkManager.sync_round_finished.rpc(round_data)

func _bot_request_swap(player_id: int):
	if not vira or vira_has_been_drawn: return
	var card_to_swap = CardData.new(trunfo_suit, 2)
	var player_hand = player_hands_data.get(player_id, [])
	var card_found = false
	for card in player_hand:
		if card.suit == card_to_swap.suit and card.value == card_to_swap.value: card_found = true; break
	if card_found: _perform_swap(player_id, card_to_swap)

@rpc("any_peer", "call_local")
func player_request_swap_vira():
	var sender_peer_id = multiplayer.get_remote_sender_id()
	var player_id = NetworkManager.get_player_id_from_peer_id(sender_peer_id)
	if player_id == -1: return
	
	if not vira or vira_has_been_drawn: return
	var card_to_swap = CardData.new(trunfo_suit, 2)
	var player_hand = player_hands_data[player_id]
	var card_found = false
	for card in player_hand:
		if card.suit == card_to_swap.suit and card.value == card_to_swap.value: card_found = true; break
	if card_found: _perform_swap(player_id, card_to_swap)
	
func _perform_swap(player_id: int, card_to_give: CardData):
	if not vira or vira_has_been_drawn: return
	print("Servidor: Jogador ", player_id, " está trocando o 2 pela vira ", vira)
	var old_vira = vira
	for card in player_hands_data[player_id]:
		if card.suit == card_to_give.suit and card.value == card_to_give.value:
			player_hands_data[player_id].erase(card)
			break
	player_hands_data[player_id].append(old_vira)
	vira = card_to_give
	NetworkManager.sync_vira_swapped.rpc(_card_data_to_dict(vira), player_id)

func determine_round_winner() -> int:
	if cards_on_table.is_empty(): return -1
	
	var trumps_played = []
	for play in cards_on_table:
		if _dict_to_card_data(play["card"]).suit == trunfo_suit: trumps_played.append(play)
	
	if not trumps_played.is_empty():
		trumps_played.sort_custom(func(a, b): return _dict_to_card_data(a["card"]).strength > _dict_to_card_data(b["card"]).strength)
		return trumps_played[0].player
	else:
		var lead_suit = _dict_to_card_data(cards_on_table[0]["card"]).suit
		var winning_plays = []
		for play in cards_on_table:
			if _dict_to_card_data(play["card"]).suit == lead_suit: winning_plays.append(play)
		winning_plays.sort_custom(func(a, b): return _dict_to_card_data(a["card"]).strength > _dict_to_card_data(b["card"]).strength)
		return winning_plays[0].player

func request_next_turn():
	if is_game_over: return
	if not multiplayer.is_server(): return
	if not NetworkManager.is_player_human(current_player_id):
		bot_turn_timer.start()

func take_bot_turn():
	if not player_hands_data[current_player_id].is_empty():
		var card_to_play = player_hands_data[current_player_id][0]
		_play_card(current_player_id, card_to_play)

func emit_game_state():
	if is_game_over: return
	NetworkManager.sync_game_state.rpc(get_game_state_for_rpc())

# --- FUNÇÕES DE CONVERSÃO PARA RPC ---
func _card_data_to_dict(card: CardData) -> Dictionary:
	if not card: return {}
	return {"suit": card.suit, "value": card.value}

func _dict_to_card_data(dict: Dictionary) -> CardData:
	if not dict: return null
	return CardData.new(dict.suit, dict.value)

func get_game_state_for_rpc() -> Dictionary:
	var serializable_hands = {}
	for p_id in player_hands_data:
		serializable_hands[p_id] = []
		for card in player_hands_data[p_id]:
			serializable_hands[p_id].append(_card_data_to_dict(card))

	return {
		"hands": serializable_hands,
		"table": cards_on_table, # já está serializado
		"turn": current_player_id,
		"vira": _card_data_to_dict(vira),
		"trunfo": trunfo_suit,
		"scores": team_scores,
		"can_see_partner_hand": rounds_played == 0 or is_last_hand,
		"is_deck_empty": deck.is_empty() and vira_has_been_drawn
	}

func deal_initial_hands():
	for _i in range(3):
		for player_id in range(1, 5):
			var card = draw_card()
			if card:
				player_hands_data[player_id].append(card)

func create_deck():
	deck.clear()
	for s in suits:
		for v in values:
			deck.append(CardData.new(s, v))

func shuffle_deck(): deck.shuffle()
