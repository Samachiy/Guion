extends Panel


onready var line = $MarginContainer/HBoxContainer/LineEdit
onready var blocking = $MarginContainer/HBoxContainer/CheckBox


func _on_Button_pressed():
	var text = line.text
	var arguments: Array = text.split(',', false)
	var output = []
	l.g("Running: " + str(arguments))
	var script = arguments.pop_front()
	if blocking.pressed:
		var exit_code = OS.execute(script, arguments, blocking.pressed, output)
		l.g("Output: " + str(output), l.DEBUG)
		l.error(exit_code, "-> Exit code from kill.py")
	else:
		yield(Python.run(script, arguments), "script_finished")
