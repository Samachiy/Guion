extends Node


var ui_nodes: Array = Array()
var is_ui_hidden: bool = false
export var img_extension: String = '.png'

# VALUES RECEIVED FROM PARENT
#var is_loading: bool = false
var save_dir: String
var save_name: String
var is_current_scene_a_viewport: bool = false

signal ui_registry_cleared

func take_screenshot(img_width, img_height, slot_num):
	var img = Image.new()
	if is_current_scene_a_viewport:
		img = get_tree().current_scene.viewport.get_texture().get_data()
	else:
		hide_ui()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		img = get_viewport().get_texture().get_data()
		show_ui()
	img.flip_y()
	img.resize(img_width, img_height)
	img.save_png(get_img_save_path(slot_num))


func hide_ui():
	is_ui_hidden = true
	for i in range(ui_nodes.size()):
		ui_nodes[i][1].visible = false


func show_ui():
	is_ui_hidden = false
	for i in range(ui_nodes.size()):
		ui_nodes[i][1].visible = true


func register_ui(node, ui_name):
#	if !is_loading:
#		_add_ui_node(node, ui_name)
#	else:
#		for i in range(ui_nodes.size()):
#			if ui_name == ui_nodes[i][0]:
#				ui_nodes[i][1] = node
#				break
	_add_ui_node(node, ui_name)


func _add_ui_node(node, ui_name):
	var should_add = true
	for i in range(ui_nodes.size()):
		if ui_name == ui_nodes[i][0]:
			l.g("'" + str(node.name) + "' can't be registered as '" + str(ui_name) + 
			"'. The UI name is already taken.")
			should_add = false
			break
	
	if should_add:
		ui_nodes.append([ui_name, node, false])


func clear_registry():
	ui_nodes.resize(0)
	emit_signal("ui_registry_cleared")


func get_img_save_path(slot_num = '_q'):
	var path = save_dir + save_name + str(slot_num) + img_extension
	return path

