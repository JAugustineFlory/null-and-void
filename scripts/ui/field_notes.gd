extends Control
## End-of-level Field Notes: the notebook, opened on its Field Notes page, with the
## buttons to carry on.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pages := NotebookPages.new()
	pages.end_of_level = true
	add_child(pages)
	pages.show_page(NotebookPages.Page.FIELD_NOTES)
