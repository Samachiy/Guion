extends Node

onready var reader = $Reader
onready var blackout = $PopUps/Blackout
onready var camera = $Camera3D
onready var jumper = $Reader/Jumper
onready var backlog = $Reader/Backlog

export var actors_padding_h: int = 300 
export var actors_number: int = 5 
export var default_scene: String = ""

var is_stage_showing: bool = false
var just_changed_scene: bool = false
var on_scene_change_cues: Array = Array()
var next_scene_path: String = ''
var positions: Array = Array()
var current_scene: String = '' setget set_current_scene, get_current_scene
var previous_scene: String = ''

signal stage_hidden
signal stage_shown
signal scene_change_started
signal scene_change_succeded
signal scene_change_finished

# VALUES PASSED TO CHILDREN
export var screen_v: int = 720 
export var screen_h: int = 1280 
export var use_project_screen_size: bool = true
func set_screen_v():
	blackout.screen_v = screen_v
func set_screen_h():
	blackout.screen_h = screen_h

func _ready():
	if use_project_screen_size:
		screen_h = ProjectSettings.get("display/window/size/width")
		screen_v = ProjectSettings.get("display/window/size/height")
		
	set_screen_v()
	set_screen_h()
	_calculate_positions()
	blackout.color.a = 0
#	get_tree().current_scene.connect("ready", self, "_on_change_scene_ready")


# FUNCTIONS


func hide_stage(_cue: Cue):
	if not is_stage_showing:
		return
	
	is_stage_showing = false
	emit_signal("stage_hidden")
	set_stage_visibility(false)


func show_stage(cue: Cue):
	# Options:
	#	actors = int; the number of actors in stage
	#	padding = int; The amount of padding of the stage actors
	# [actors, padding] 
	if is_stage_showing:
		return
	
	# will first check the options, if none, will default to the arguments
	# if none, will return the original value
	set_stage_layout(cue)
	is_stage_showing = true
	set_stage_visibility(true)
	emit_signal("stage_shown")


func set_stage_visibility(visible: bool):
	var action
	if visible:
		action = 'show'
	else:
		action = 'hide'
	for role in Roles.roles.values():
		if role.is_stage and not _safe_call(role.node, action):
			role.node.visible = visible


func _safe_call(node: Node, method) -> bool:
	if node.has_method(method):
		node.call(method)
		return true
	else:
		return false



func set_stage_layout(cue: Cue):
	# Options:
	#	actors = int; the number of actors in stage
	#	padding = int; The amount of padding of the stage actors
	# [actors, padding] 
	
	# will first check the options, if none, will default to the arguments
	# if none, will return the original value
	actors_number = cue.get_option('actors', cue.get_at(0, actors_number, false)) 
	actors_padding_h = cue.get_option('padding', cue.get_at(1, actors_padding_h, false))
	_calculate_positions()
	if cue.requires_rollback:
		Director.add_rollback_cue('', 'set_stage_layout', cue._arguments, cue._options)


func start_dialog(cue: Cue):
	# Options:
	#	actors = int; the number of actors in stage
	#	padding = int; The amount of padding of the stage actors
	# [actors, padding] 
	reader.clear_text()
	show_stage(cue)


func end_dialog(cue: Cue):
	var success = jumper.attempt_jump_back()
	if not success:
		backlog.disable_backlog()
		backlog.disable_new_backlog_entry()
		hide_stage(cue)
		reader.abort()


func clear_dialog(cue: Cue):
	reader.clear_text()
	hide_stage(cue)


func kill_dialog(cue: Cue):
	reader.clear_text()
	backlog.disable_backlog()
	backlog.disable_new_backlog_entry()
	hide_stage(cue)
	jumper.jump_in_stack.resize(0)


func _calculate_positions():
# warning-ignore:integer_division
	var y = screen_v / 2
	var pos_h_interval = (screen_h - actors_padding_h * 2.0) / (actors_number - 1)
	var position_zero = Vector2(screen_h / 2.0, y)
	positions = [position_zero]
	var x_pos
	for i in range(actors_number):
		x_pos = i * pos_h_interval + actors_padding_h
		positions.append(Vector2(x_pos, y))


func change_scene_to_file(cue: Cue):
	# [scene_path: String, fast_change: bool = false]
	# Will activate blackout animation (see PopUps node), when the animation ends, it will
	# load the next scene, and when the scene is loaded, it will remove the blackout.
	# It will also forcibly pause the reader, denying inputs to continue, and will
	# only start sgain after blackout, of after setting reader.should_read = false
	# and calling resume function.
	if just_changed_scene:
		return
	
	is_stage_showing = false
	previous_scene = get_current_scene()
	emit_signal("scene_change_started")
	load_scene(cue.get_at(0, ''), cue.bool_at(1, false, false))
	if cue.requires_rollback:
		previous_scene = self.current_scene
	else:
		previous_scene = ''


func load_scene(scene_path: String, fast_change: bool):
	# this functions is used when loading a file, change_scene is for map movements and whatnot
	next_scene_path = scene_path
	if fast_change:
		_on_Blackout_blackout_started()
	else:
		blackout.start_blackout()
	reader.wait()
	reader.should_read = false


func cue_on_scene_change_finished(cue: Cue) -> void:
	on_scene_change_cues.append(cue)


func _on_Blackout_blackout_started():
	if just_changed_scene:
		return
	
	var tree = get_tree()
	if tree.change_scene(next_scene_path) == OK:
#		yield(tree, "idle_frame")
#		var scene_ = tree.current_scene
#		var err = tree.current_scene.connect("ready", self, "_on_change_scene_ready")
		Roles.clear_roles()
		camera.clear_registry()
		just_changed_scene = true
		current_scene = next_scene_path
		emit_signal("scene_change_succeded")
		if previous_scene != '':
			Director.add_rollback_cue('', 'change_scene_to_file', [previous_scene])
			previous_scene = ''
		#read_queued_text()
	else:
		l.g("Couldn't change to scene: '" + next_scene_path + "'.")
		#L.g("Failed scene change cleared all roles")
		reader.should_read = true
		reader.abort()
		next_scene_path = ''
		blackout.end_blackout()
		on_scene_change_cues.resize(0)


#func _on_change_scene_ready():
#	if just_changed_scene:
#		emit_signal("scene_change_finished")


func _on_SaveLoad_load_ready(is_loading_from_file) -> void:
	# This is for when the scene is changed, it uses SaveLoad just because that's
	# the node in change of nloading, since it's only on scene change, we check 
	# if we just changed the scene
	if just_changed_scene:
		just_changed_scene = false
		next_scene_path = ''
		reader.should_read = true
		if not is_loading_from_file:
			reader.resume()
		
		_execute_on_scene_change_cues()
		blackout.end_blackout()
	emit_signal("scene_change_finished")


func _execute_on_scene_change_cues():
	var cue
	while on_scene_change_cues.size() != 0:
		cue = on_scene_change_cues.pop_front()
		if cue is Cue:
			cue.execute()


func set_current_scene(value):
	current_scene = value


func get_current_scene():
	var aux
	if current_scene == '':
		aux = get_tree().current_scene
		if aux.has_method("replace_scene"):
			return aux.get_scene_in_stage_file_path()
		else:
			return aux.filename
	else:
		return current_scene

