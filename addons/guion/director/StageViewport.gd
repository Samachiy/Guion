extends CanvasLayer

onready var viewport = $Screen/SubViewport
onready var screen = $Screen
onready var console = $Console
onready var label = $HBoxContainer/Label
onready var animation_player = $AnimationPlayer

var scene = null
var node_with_signal = null
var viewport_changed_emit_signal_method = ""
var role = 'Display'

func _ready():
	screen.texture = viewport.get_texture()
	Director.request_role(self, role)
	if scene != null:
		viewport.add_child(scene)
		get_tree().current_scene = self
		#yield(get_tree(), "idle_frame")
		node_with_signal.call(viewport_changed_emit_signal_method)


func replace_scene(tree):
	var root = tree.root
	var current_scene = tree.current_scene
	scene = current_scene
	root.call_deferred("remove_child",current_scene)
	root.call_deferred("add_child", self)
	if get_parent() == root:
		$Screen/SubViewport.add_child(scene)
		tree.current_scene = self
	
	return $Screen/SubViewport
	#root.remove_child(current_scene)
	#root.add_child(self)


func _process(_delta):
	if Input.is_action_just_released("toggle_console"):
		toggle_console()
	
#	if Director.console.is_console_open():
#		if Input.is_action_just_released("ui_up")


func toggle_console():
	if console.visible:
		console.close()
	else:
		console.open(screen.prev_focus_owner)


func get_scene_in_stage_file_path():
	var resul
	if viewport.get_child_count() > 0:
		resul = viewport.get_child(0).filename
	else:
		resul = ''
	
	return resul


func message(cue: Cue):
	# [text]
	label.text = cue.get_at(0, '')
	animation_player.stop()
	animation_player.play("flash_message")
	pass
