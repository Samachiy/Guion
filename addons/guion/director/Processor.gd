extends Node

var reader_class = preload("res://addons/guion/reader/Reader.tscn")
var reader: Node


func process_this(text: String, caller: Node = null, skip_id: String = ''):
	var process = new_process()
	if process != null:
		process.is_processing = true
		process.read_this(text, caller, skip_id)
		process.is_processing = true
		while process.is_processing:
			process._process_next()


func new_process():
	var new_reader
	if reader_class != null:
		new_reader = reader_class.instance()
		add_child(new_reader)
		new_reader.connect("process_finished", self, "_free_reader")
		new_reader.manager.roles = reader.manager.clone_roles()
		l.p("new reader's manager owner: " + str(new_reader.manager.director))
		return new_reader
	else:
		return false


func _free_reader(reader_node):
	reader_node.queue_free()
