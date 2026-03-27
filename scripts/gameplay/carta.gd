# Localização: scripts/gameplay/Carta.gd
# AÇÃO: Substituir o script inteiro por este.
extends Area2D

signal card_was_clicked(card_node)

const BACK_TEXTURE = preload("res://assets/images/ui/card_back.png")
# ... (@onready vars) ...
@onready var visuals: Node2D = $Visuals
@onready var carta_sprite: Sprite2D = $Visuals/CartaSprite
@onready var valor_label: Label = $Visuals/ValorLabel

var card_data: CardData
var is_face_up = false
var is_playable = false

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if not is_playable or not is_face_up: return
		
		emit_signal("card_was_clicked", self)
		
		# MUDANÇA: Faz a chamada RPC para o servidor (ID 1)
		# Passamos dados primitivos (string, int) em vez do objeto CardData
		Server.player_action_play_card.rpc_id(1, card_data.suit, card_data.value)
		
		get_viewport().set_input_as_handled()

# (O resto do script Carta.gd permanece o mesmo)
# ...
func setup(data: CardData):
	self.card_data = data
	update_visuals()
func flip(face_up: bool):
	if is_face_up == face_up: return
	is_face_up = face_up
	update_visuals()
func update_visuals():
	if is_face_up:
		if card_data:
			valor_label.text = str(card_data.value)
			var image_path = "res://assets/images/cards/%s_%s.png" % [card_data.suit, card_data.value]
			var texture = load(image_path)
			if texture: carta_sprite.texture = texture
	else:
		valor_label.text = ""
		carta_sprite.texture = BACK_TEXTURE
func _on_mouse_entered():
	if not is_face_up or not is_playable: return
	z_index = 10
	var tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "position:y", -20, 0.15)
	tween.tween_property(visuals, "scale", Vector2(1.1, 1.1), 0.15)
func _on_mouse_exited():
	if not is_face_up: return
	z_index = 0
	var tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "position:y", 0, 0.15)
	tween.tween_property(visuals, "scale", Vector2(1.0, 1.0), 0.15)
