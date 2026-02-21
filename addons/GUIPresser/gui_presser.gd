tool
extends Node

class_name GUIPresser

const MASK: Dictionary = {BUTTON_LEFT : BUTTON_MASK_LEFT, BUTTON_RIGHT : BUTTON_MASK_RIGHT, BUTTON_MIDDLE: BUTTON_MASK_MIDDLE}

signal hover_state_changed(state)
signal pressed_state_changed(state, button)
signal activated(button)

export var disabled: bool = false setget _set_disabled
export(int, FLAGS, "Mouse Left", "Mouse Right", "Mouse Middle") var button_mask: int = 7 setget _set_button_mask

var parent: Control = null

var pressed: int = 0
var hovered: bool = false

func _set_disabled(state: bool) -> void:
	disabled = state
	if disabled: _disconnect_parent()
	else: _connect_parent()

func _set_button_mask(value: int) -> void:
	var changes: int = (value ^ button_mask)
	var values: Array = MASK.values()
	for i in values.size():
		var m: int = values[i]
		if changes & m && !(value & m) && pressed & m: 
			pressed &= ~m
			emit_signal("pressed_state_changed", false, MASK.keys()[i])
	button_mask = value

func _disconnect_parent() -> void:
	if parent:
		if parent.is_connected("gui_input", self, "_gui_processing"):
			parent.disconnect("gui_input", self, "_gui_processing")
		if parent.is_connected("mouse_entered", self, "_hover_state_changed"):
			parent.disconnect("mouse_entered", self, "_hover_state_changed")
		if parent.is_connected("mouse_exited", self, "_hover_state_changed"):
			parent.disconnect("mouse_exited", self, "_hover_state_changed")

func _connect_parent() -> void:
	if parent:
		if !parent.is_connected("gui_input", self, "_gui_processing"):
			parent.connect("gui_input", self, "_gui_processing")
		if !parent.is_connected("mouse_entered", self, "_hover_state_changed"):
			parent.connect("mouse_entered", self, "_hover_state_changed", [true])
		if !parent.is_connected("mouse_exited", self, "_hover_state_changed"):
			parent.connect("mouse_exited", self, "_hover_state_changed", [false])

func _get_configuration_warning() -> String:
	var _parent = get_parent()
	if _parent && _parent is Control : return "" 
	return "A parent of the Control class is required"

func _process(_delta: float) -> void: update_hovered()

func update_hovered() -> void:
	var cursor: Vector2 = parent.get_local_mouse_position()
	var new_state: bool = (
		cursor.x >= 0 && cursor.x <= parent.rect_size.x && \
		cursor.y >= 0 && cursor.y <= parent.rect_size.y
	)
	if new_state != hovered:
		hovered = new_state
		emit_signal("hover_state_changed", hovered)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY: set_process(false)
		NOTIFICATION_PARENTED:
			var _parent = get_parent()
			if !_parent || !(_parent is Control):
				parent = null
				update_configuration_warning()
				return
			parent = _parent
			if !disabled: _connect_parent()
		NOTIFICATION_UNPARENTED:
			if parent:
				_disconnect_parent()
				parent = null

func _hover_state_changed(value: bool) -> void:
	if hovered != value:
		hovered = value
		emit_signal("hover_state_changed", value)

func _gui_processing(event: InputEvent) -> void:
	if event is InputEventMouseButton && MASK.has(event.button_index):
		if event.pressed && !hovered: return
		var current_mask: int = MASK[event.button_index]
		if !(button_mask & current_mask): return
		if bool(pressed & current_mask) == event.pressed: return
		if event.pressed: pressed |= current_mask
		else: pressed &= ~current_mask
		emit_signal("pressed_state_changed", event.pressed, event.button_index)
		set_process(pressed)
		if !event.pressed && hovered: emit_signal("activated", event.button_index)
