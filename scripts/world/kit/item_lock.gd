class_name ItemLock
extends KitPiece
## Something stuck that one piece of gear opens: a hatch pried with the crowbar, a
## cabinet's rusted catch. With no item (""), anyone can work it once: a hand chain
## that lifts a roll-up door once its gear is free. The floor gives its words (what it says when you carry the
## item, and when you don't) and wires what opening it does (`opened`).

## Every machine: player `peer_id` opened it.
signal opened(peer_id: int)

var item := "crowbar"
## Opening it uses the item up (it stays in the lock).
var uses_up := false
var is_open := false
var use_text := ""
var need_text := ""
## Its sound when it gives.
var sound := "clatter"


## An aim box `size` big at `center`. `use` is the prompt with the item, `need` without.
static func make(parent: Node, id: String, center: Vector3, size: Vector3, item_id: String, use: String, need: String) -> ItemLock:
	var l := ItemLock.new()
	l.name = "Lock_" + id
	l.position = center
	l.item = item_id
	l.use_text = use
	l.need_text = need
	l.kind = "lever"
	l._shape(size)
	parent.add_child(l)
	l.add_to_group("interactable")
	return l


func prompt_for(hand: Dictionary) -> String:
	if is_open:
		return ""
	return use_text if can_use(hand) else need_text


func can_use(hand: Dictionary) -> bool:
	return not is_open and (item == "" or KitPiece.carries(hand, item))


func decide(peer: int, _hand: Dictionary) -> void:
	play("_open", [peer])


func _open(peer: int) -> void:
	if is_open:
		return
	is_open = true
	if uses_up and item != "":
		_take(peer, item)
	_sound(peer, sound)
	opened.emit(peer)
