# Localização: scripts/systems/AnimationManager.gd
extends Node

signal deal_animation_finished

func play_initial_deal(deck_pile_nodes: Array, hands_data: Dictionary, player_view: Node):
	if not is_instance_valid(player_view): return
	_run_deal_sequence(deck_pile_nodes, hands_data, player_view)

func _run_deal_sequence(deck_pile_nodes: Array, hands_data: Dictionary, player_view: Node):
	for _round in range(3):
		for player_id in range(1, 5):
			if _round < hands_data[player_id].size():
				var card_data = hands_data[player_id][_round]
				var card_node = deck_pile_nodes.pop_back()
				if not is_instance_valid(card_node): continue
				player_view.hand_nodes[player_id].append(card_node)
				await animate_card_to_hand(card_node, card_data, player_id, player_view)
				await get_tree().create_timer(0.08).timeout
	await get_tree().create_timer(0.4).timeout
	deal_animation_finished.emit()

func animate_card_to_hand(card_node: Node, card_data: CardData, player_id: int, player_view: Node):
	card_node.setup(card_data)
	var target_anchor = player_view.hand_anchors[player_id]
	var hand_layout = player_view.calculate_hand_layout(player_id)
	var card_layout_data = hand_layout.get(card_node, {"position": Vector2.ZERO, "rotation": 0.0})
	var target_global_position = target_anchor.to_global(card_layout_data.position)
	var target_rotation = target_anchor.rotation_degrees + card_layout_data.rotation
	var tween = card_node.create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card_node, "global_position", target_global_position, 0.45)
	tween.tween_property(card_node, "rotation_degrees", target_rotation, 0.45)
	await tween.finished
	card_node.reparent(target_anchor)
	card_node.position = card_layout_data.position
	card_node.rotation_degrees = card_layout_data.rotation

func animate_play_card(card_node: Node, player_view: Node):
	if not is_instance_valid(card_node): return
	card_node.flip(true)
	var target_pos = player_view.table_pile_anchor.global_position
	target_pos += Vector2(randf_range(-5, 5), randf_range(-5, 5))
	var target_rot = randf_range(-10, 10)
	card_node.z_index = 100 
	var tween = card_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel()
	tween.tween_property(card_node, "global_position", target_pos, 0.4)
	tween.tween_property(card_node, "rotation_degrees", target_rot, 0.4)
	await tween.finished
	if is_instance_valid(card_node):
		card_node.reparent(player_view.table_pile_anchor)
		card_node.z_index = 0
		if not card_node in player_view.table_pile_nodes:
			player_view.table_pile_nodes.append(card_node)
	return tween.finished

func animate_draw_card(card_node: Node, player_id: int, player_view: Node):
	var target_anchor = player_view.hand_anchors[player_id]
	var hand_layout = player_view.calculate_hand_layout(player_id)
	var card_layout_data = hand_layout.get(card_node, {"position": Vector2.ZERO, "rotation": 0.0})
	var target_global_pos = target_anchor.to_global(card_layout_data.position)
	var target_global_rot = target_anchor.rotation_degrees + card_layout_data.rotation
	var tween = card_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(card_node, "global_position", target_global_pos, 0.4)
	tween.tween_property(card_node, "rotation_degrees", target_global_rot, 0.4)
	await tween.finished
	if is_instance_valid(card_node):
		card_node.reparent(target_anchor)
		card_node.position = card_layout_data.position
		card_node.rotation_degrees = card_layout_data.rotation
	return tween.finished
