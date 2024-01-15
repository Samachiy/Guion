extends Node


var console: Control
var current_scene: CanvasLayer

var entries: Array = []
var displayed_entries: int = -1
var entries_cursor = 0

func _on_SaveLoad_game_viewport_changed(_viewport):
	current_scene = get_tree().current_scene
	console = current_scene.console


func is_console_open():
	if is_instance_valid(console):
		return console.visible
	else:
		return false

func add_entry(text):
	if is_instance_valid(console):
		console.add_entry(text)


func get_prev_entry():
	if entries_cursor > 0:
		entries_cursor -= 1
		return entries[entries_cursor]
	else:
		return null


func get_next_entry():
	if entries_cursor < entries.size() - 1:
		entries_cursor += 1
		return entries[entries_cursor]
	elif entries_cursor == entries.size() - 1:
		entries_cursor += 1
		return ''
	else:
		return null


func append_text(text):
	if is_instance_valid(console):
		console.append_text(text)
