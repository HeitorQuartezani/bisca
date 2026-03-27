# Localização: scripts/systems/CardData.gd
class_name CardData
extends RefCounted

var suit: String
var value: int
var points: int
var strength: int

const POINT_MAP = { 1: 11, 7: 10, 13: 4, 11: 3, 12: 2 }
const STRENGTH_MAP = { 1: 10, 7: 9, 13: 8, 12: 7, 11: 6, 10: 5, 9: 4, 8: 3, 6: 2, 5: 1, 4: 0, 3: -1, 2: -2 }

func _init(s: String, v: int):
	self.suit = s
	self.value = v
	self.points = POINT_MAP.get(v, 0)
	self.strength = STRENGTH_MAP.get(v, 0)

func _to_string() -> String:
	return "Card(%s, %s)" % [suit, value]
