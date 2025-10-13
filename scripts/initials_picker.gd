extends Control
class_name InitialsPicker
signal initials_changed(text: String)

@onready var l1: OptionButton = %L1
@onready var l2: OptionButton = %L2
@onready var l3: OptionButton = %L3

var _letters: Array[String] = []

func _ready() -> void:
	_build_letters()
	_populate_option(l1)
	_populate_option(l2)
	_populate_option(l3)
	_emit()

func _build_letters() -> void:
	_letters.clear()
	for code in range(65, 91): # 'A'..'Z'
		_letters.append(String.chr(code))

func _populate_option(ob: OptionButton) -> void:
	ob.clear()
	for i in range(_letters.size()):
		ob.add_item(_letters[i], i) # id == index
	ob.select(0)
	ob.item_selected.connect(_on_item_selected)

func _on_item_selected(_index: int) -> void:
	_emit()

func _emit() -> void:
	emit_signal("initials_changed", get_initials())

func get_initials() -> String:
	var idx1: int = l1.get_selected_id()
	var idx2: int = l2.get_selected_id()
	var idx3: int = l3.get_selected_id()
	var last: int = max(0, _letters.size() - 1)

	idx1 = clampi((idx1 if idx1 != -1 else 0), 0, last)
	idx2 = clampi((idx2 if idx2 != -1 else 0), 0, last)
	idx3 = clampi((idx3 if idx3 != -1 else 0), 0, last)

	return _letters[idx1] + _letters[idx2] + _letters[idx3]

func set_initials(text: String) -> void:
	var t := text.strip_edges().to_upper()
	while t.length() < 3:
		t += "A"
	if t.length() > 3:
		t = t.substr(0, 3)
	var chars := [String(t[0]), String(t[1]), String(t[2])]
	for i in range(3):
		var idx := _letters.find(chars[i])
		if idx == -1:
			idx = 0
		match i:
			0: l1.select(idx)
			1: l2.select(idx)
			2: l3.select(idx)
	_emit()

func _unhandled_input(ev: InputEvent) -> void:
	if not has_focus():
		return
	var current := get_viewport().gui_get_focus_owner()
	if current == null or not (current is OptionButton):
		return
	if ev.is_action_pressed("ui_left"):
		_cycle(current as OptionButton, -1)
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("ui_right"):
		_cycle(current as OptionButton, +1)
		get_viewport().set_input_as_handled()

func _cycle(ob: OptionButton, delta: int) -> void:
	var id := ob.get_selected_id()
	if id == -1:
		id = 0
	var count := _letters.size()
	id = (id + delta) % count
	if id < 0:
		id = count - 1
	ob.select(id)
	_emit()
