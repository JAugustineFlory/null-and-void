class_name LightPanelLink
extends Node
## Keeps a ceiling light's glowing panel in step with the light itself, so a red
## lockdown turns the tubes red and a light switched off in the `lights` table
## goes visibly dark. Checks a few times a second; the materials are shared.

const CHECK_EVERY := 0.1

var light: Light3D
var panel: MeshInstance3D
var _t := 0.0
var _shown := ""


static func attach(target: Light3D, glow_panel: MeshInstance3D) -> LightPanelLink:
	var link := LightPanelLink.new()
	link.name = "PanelLink"
	link.light = target
	link.panel = glow_panel
	target.add_child(link)
	link.refresh()
	return link


func _process(delta: float) -> void:
	_t += delta
	if _t < CHECK_EVERY:
		return
	_t = 0.0
	refresh()


func refresh() -> void:
	if not is_instance_valid(panel):
		return
	# The lights table hides a light; this node, its child, keeps running regardless.
	var lit := light.visible and light.light_energy > 0.05
	var key := "%s|%s" % [lit, light.light_color.to_html()]
	if key == _shown:
		return
	_shown = key
	if lit:
		panel.material_override = ArtPalette.glow(light.light_color, 2.5)
	else:
		panel.material_override = ArtPalette.flat(Color(0.32, 0.33, 0.33), 0.35)
