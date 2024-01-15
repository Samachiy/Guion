extends Object

class_name TutorialSequence


var steps: Dictionary
var flag: String
var step_counter: int = 0
var current_step: TutorialStep
var display: TutorialDisplay = null
var set_text_function: String
var name: String = ''

func _init(step_names: Array, sequence_name: String):
	name = sequence_name
	for step_name in step_names:
		if step_name is String:
			steps[step_name] = null
		else:
			l.g("Couldn't add step name '" + str(step_name) + "' to tutorial sequence")


func add_unnamed_step(text: String, control_nodes: Array = [], 
optional_id: String = '') -> TutorialStep:
	var step = TutorialStep.new(text, control_nodes)
	if optional_id.empty():
		steps[text] = step
	else:
		steps[optional_id] = step
	return step


func add_named_step(step_name: String, text: String, control_nodes: Array = []):
	var step = TutorialStep.new(text, control_nodes)
	if step_name in steps:
		steps[step_name] = step
	else:
		l.g("Couldn't find step of name '" + str(step_name) + "' to assign in tutorial sequence")
	
	return step


func add_tr_named_step(step_name: String, control_nodes: Array = []):
	return add_named_step(step_name, step_name, control_nodes)


func start(tutorial_display_role = TutorialDisplay.DEFAULT_ROLE):
	display = Roles.get_node_by_role(tutorial_display_role)
	if display == null:
		l.g("Can't start tutorial, no TutorialDisplay node specified as role '" + 
				tutorial_display_role + "'")
		return
	
	if steps.empty():
		l.g("Can't start tutorial, no steps specified")
		return
	
	set_text_function = display.dbox_set_text_function
	step_counter = 0
	display.visible = true
	run_current_step()


func stop_current_step():
	if current_step is TutorialStep:
		current_step.stop() # technicaly prev_step since it's not updated yet
	
	display.clear()
	


func run_current_step() -> bool:
	# returns false if this functions needs to be called again to try another step
	if steps.empty():
		l.g("Can't run tutorial sequence, no steps specified")
		return true
	
	var show_next = true
	var show_prev = true
	if step_counter <= 0:
		step_counter = 0
		show_prev = false
	
	if step_counter + 1 == steps.size():
		show_next = false
	
	if step_counter + 1 > steps.size():
		complete_sequence()
		return true # last step was already shown, so the tutorial effectively ends
	
	var step_key = steps.keys()[step_counter]
	var step: TutorialStep = steps[step_key]
	if step != null:
		stop_current_step()
		if not step.is_connected("next_requested", self, "_on_next_pressed"):
			step.connect("prev_requested", self, "_on_prev_pressed")
			step.connect("next_requested", self, "_on_next_pressed")
			step.connect("skip_requested", self, "_on_skip_pressed")
		step.run(display, show_prev, show_next)
		current_step = step
		return true
	else:
		l.g("Missing step of name '" + str(step_key) + "' in tutorial sequence: " + name)
		return false


func complete_sequence():
	Flag.new(name).set_up(true)
	display.visible = false
	stop_current_step()
	call_deferred("free")


func next():
	var success = false
	while not success:
		step_counter += 1
		success = run_current_step()
		if step_counter + 1 > steps.size():
			break


func prev():
	var success = false
	while not success:
		step_counter -= 1
		success = run_current_step()
		if step_counter < 0:
			break


func skip():
	current_step.stop()
	display.clear()
	complete_sequence()


func _on_prev_pressed():
	prev()


func _on_next_pressed():
	next()


func _on_skip_pressed():
	skip()
