extends Reference

class_name TutorialStep
const BLINK_SHOW_TIME = 1
const BLINK_HIDE_TIME = 1
const BLINK_STAY_TIME = 0.3

var text = ''
var nodes = []
var run_cues = []
var stop_cues = []
var node_click = null
var node_drag_from: Control = null
var node_drag_to: Control = null
var indicator_click: Control = null
var indicator_drag: Control = null
var node_frame_pairs = {} # [control_node, frame]
var frame_blink_tween: SceneTreeTween = null

var drag_anim_tween: SceneTreeTween = null
var drag_anim_speed: float = 250 # pixels per second

var active: bool = false

signal prev_requested
signal next_requested
signal skip_requested

func _init(tutorial_step_text: String, control_nodes: Array = []):
	text = tutorial_step_text
	nodes = control_nodes


func drag(from_node: Control, to_node: Control, speed: float = drag_anim_speed):
	if from_node == null:
		l.g("Can't add drag action in tutorial step, node '" + from_node.name + 
		"' is null. Node path: " + from_node.get_path())
		return
	if to_node == null:
		l.g("Can't add drag action in tutorial step, node '" + to_node.name + 
		"' is null. Node path: " + to_node.get_path())
		return
	
	# redundant code, fully delete if nothing happens
#	var distance = from_node.get_global_rect().get_center().distance_to(
#			to_node.get_global_rect().get_center())
#	var time = distance / speed
	node_drag_from = from_node
	node_drag_to = to_node
	drag_anim_speed = speed


func cue_in_run(cue: Cue):
	run_cues.append(cue)


func cue_in_stop(cue: Cue):
	stop_cues.append(cue)


func _execute_cues(cues_array: Array):
	for cue in cues_array:
		if cue is Cue:
			cue.clone().execute()


func click(click: Control):
	node_click = click


func update_position():
	_place_click_indicator()
	_animate_drag_indicator(drag_anim_speed)


func run(tutorial_display: TutorialDisplay, has_prev: bool, 
has_next: bool, allow_skip: bool = true):
	_execute_cues(run_cues)
	tutorial_display.clear()
	frame_blink_tween = tutorial_display.create_tween().set_loops().bind_node(tutorial_display)
	frame_blink_tween.set_trans(Tween.TRANS_LINEAR)
	frame_blink_tween.pause()
	var has_frames = false
	for control_node in nodes:
		has_frames = true
		add_frame(control_node, tutorial_display)
	
	if node_click != null:
		has_frames = true
		add_frame(node_click, tutorial_display)
		indicator_click = add_indicator(node_click, tutorial_display)
		_place_click_indicator()
	
	if node_drag_from != null and node_drag_to != null:
		has_frames = true
		add_frame(node_drag_from, tutorial_display)
		indicator_drag = add_indicator(node_drag_from, tutorial_display)
		add_frame(node_drag_to, tutorial_display)
		_animate_drag_indicator(drag_anim_speed)
	
	var dbox = tutorial_display.display_box(text, has_prev, has_next, allow_skip)
	tutorial_display.connect_box(dbox, self)
	
	active = true
	if has_frames:
		frame_blink_tween.play()
	else:
		frame_blink_tween = null


func stop():
	active = false
	node_frame_pairs.clear()
	if frame_blink_tween != null:
		frame_blink_tween.kill()
		frame_blink_tween = null
	if drag_anim_tween != null:
		drag_anim_tween.kill()
		drag_anim_tween = null
	
	_execute_cues(stop_cues)


func add_frame(control_node: Control, tutorial_display: TutorialDisplay):
	# tutorial_display.add_frame() already controls for null so we are not gonna do it here
	var frame
	if control_node in node_frame_pairs:
		return
	
	frame = tutorial_display.add_frame(control_node)
	if frame is ReferenceRect:
		node_frame_pairs[control_node] = frame
	
	var ini_color = Color(1.0, 1.0, 1.0, 1.0)
	var end_color = Color(0.0, 0.0, 0.0, 0.5)
	if frame_blink_tween != null:
		frame_blink_tween.set_parallel(true)
		frame_blink_tween.tween_property(frame, "modulate", end_color, BLINK_HIDE_TIME
				).from(ini_color)
		frame_blink_tween.tween_property(frame, "modulate", ini_color, BLINK_SHOW_TIME
				).set_delay(BLINK_HIDE_TIME).from(end_color)
		frame_blink_tween.tween_property(frame, "modulate:a", 1, BLINK_STAY_TIME
				).set_delay(BLINK_HIDE_TIME + BLINK_SHOW_TIME).from(1)


func add_indicator(control_node: Control, tutorial_display: TutorialDisplay):
	if control_node == null:
		return null
	
	return tutorial_display.add_indicator(control_node)


func _place_click_indicator():
	if node_click == null:
		return 
	
	if indicator_click == null:
		return
	
	_place_control_on_control_center(indicator_click, node_click)


func _animate_drag_indicator(speed: float):
	if node_drag_from == null or node_drag_to == null:
		return
	
	if indicator_drag == null:
		return
	
	if drag_anim_tween != null and drag_anim_tween.is_running():
		drag_anim_tween.kill()
	
	var start: Vector2 = node_drag_from.get_global_rect().get_center()
	var end: Vector2 = node_drag_to.get_global_rect().get_center()
	var distance = start.distance_to(end)
	var time = distance / speed
	drag_anim_tween = indicator_drag.create_tween()
	_place_control_on_control_center(indicator_drag, node_drag_from)
	drag_anim_tween.tween_property(
			indicator_drag, 
			"rect_global_position", 
			end, 
			time
		).from_current()
	drag_anim_tween.bind_node(indicator_drag)
	drag_anim_tween.connect("finished", self, "_on_drag_anim_finished")


func _place_control_on_control_center(control_to_place: Control, control_target: Control):
	var center_pos: Vector2 = control_target.get_global_rect().get_center()
	control_to_place.rect_global_position = center_pos - (control_to_place.rect_size / 2)


func _on_drag_anim_finished():
	if active:
		_animate_drag_indicator(drag_anim_speed)


func _on_prev_pressed():
	emit_signal("prev_requested")


func _on_next_pressed():
	emit_signal("next_requested")


func _on_skip_pressed():
	emit_signal("skip_requested")
