extends VBoxContainer

onready var output = $TextEdit
onready var input = $LineEdit
onready var timer = $Timer

const NEW_CONTROL_DELAY = 0.2
#var entries: Array = []
#var displayed_entries: int = -1
var previous_focus: Control
var accept_consol_control: bool = true
signal console_opened
signal console_closed


func _ready():
	visible = false
	output.text = 'Debug version:'
	output.wrap_enabled = true
	timer.connect("timeout", self, "allow_new_incoming_console_controls")
	input.caret_blink = false


func add_entry(text: String):
	#var displayed_entries =  Director.console.displayed_entries
	output.text += '\n' + text
	Director.console.entries.append(text)
	Director.console.entries_cursor = Director.console.entries.size()
	output.set_caret_line(output.get_line_count())


func run_text(text: String):
	Director.console.entries.append(text)
	Director.console.entries_cursor = Director.console.entries.size()
	var parse_resul: Array
	if text.strip_edges() != '':
		parse_resul = Director.parse(text)
		for fragment in parse_resul:
			process_parse_resul_fragment(fragment)
	
	output.set_caret_line(output.get_line_count())


func process_parse_resul_fragment(fragment: Array):
	var resul
	match fragment[1]:
		Director.parser.ROLE:
			output.text += '\n' + str(fragment[0]) + ": " + str(fragment[0].node)
		Director.parser.TEXT:
			output.text += '\n' + str(fragment[0])
		Director.parser.CUE:
			output.text += '\n' + str(fragment[0])
			resul = Director.execute_cue(fragment[0])
			if resul != null:
				output.text += ': ' + str(resul)


func append_text(text):
	output.text += text
	output.set_caret_line(output.get_line_count())


func _on_LineEdit_text_entered(new_text):
	run_text(new_text)
	input.text = ''


func open(prev_focus_owner):
	previous_focus = prev_focus_owner
	visible = true
	input.grab_focus()
	input.text = ''
	emit_signal("console_opened")
	output.set_caret_line(output.get_line_count())


func close():
	visible = false
	input.text = ''
	if is_instance_valid(previous_focus):
		previous_focus.grab_focus()
	
	emit_signal("console_closed")



func _on_LineEdit_gui_input(event):
	if not event is InputEventKey:
		return
	
	if not accept_consol_control:
		return
	
	var new_text
	match event.keycode:
		KEY_UP:
			new_text = Director.console.get_prev_entry()
			set_input(new_text)
			deny_new_incoming_console_controls()
		KEY_DOWN:
			new_text = Director.console.get_next_entry()
			set_input(new_text)
			deny_new_incoming_console_controls()
	


func set_input(text):
	if text != null:
		input.text = text
		input.caret_column = text.length()


func allow_new_incoming_console_controls():
	accept_consol_control = true

func deny_new_incoming_console_controls():
	accept_consol_control = false
	timer.start(NEW_CONTROL_DELAY)

