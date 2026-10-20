class_name Vitals
extends CanvasLayer
## Your health and stamina, as two bars in the bottom-left corner above the keys
## line: health red, stamina amber. No numbers or words. Stamina dims while it's
## full and turns grey while you're winded. Both step aside at terminals.

const WIDTH := 240.0
const HEALTH_COLOR := Color(0.78, 0.16, 0.14)
const STAMINA_COLOR := Color(1.0, 0.75, 0.3)
const WINDED_COLOR := Color(0.55, 0.55, 0.55)

var player: Player

var _root: Control
var _health: ColorRect
var _stamina: ColorRect


static func create(parent: Node, for_player: Player) -> Vitals:
	var v := Vitals.new()
	v.name = "Vitals"
	v.player = for_player
	parent.add_child(v)
	return v


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_root.position = Vector2(28, -84)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_health = _bar(0.0, 10.0, HEALTH_COLOR)
	_stamina = _bar(16.0, 6.0, STAMINA_COLOR)
	_process(0.0)


func _bar(y: float, height: float, color: Color) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.5)
	back.position = Vector2(-2, y - 2)
	back.size = Vector2(WIDTH + 4, height + 4)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(0, y)
	fill.size = Vector2(WIDTH, height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fill)
	return fill


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_root.visible = false
		return
	_root.visible = not player.is_using_terminal()
	_health.size.x = WIDTH * clampf(player.health / 100.0, 0.0, 1.0)
	_stamina.size.x = WIDTH * clampf(player.stamina / Player.STAMINA_MAX, 0.0, 1.0)
	var c := WINDED_COLOR if player.winded else STAMINA_COLOR
	c.a = 0.45 if player.stamina >= Player.STAMINA_MAX else 1.0
	_stamina.color = c


## How full each bar is drawn, 0..1 (for tests).
func health_fill() -> float:
	return _health.size.x / WIDTH


func stamina_fill() -> float:
	return _stamina.size.x / WIDTH
