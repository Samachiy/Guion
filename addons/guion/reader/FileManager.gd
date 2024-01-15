extends Node

# COMMON INTERFACES OF MANAGED FILES
#
# get_next_raw_line() -> String
#	Gets the next text line separated by a line break
#
# get_next_dialog_line() -> String
#	Gets the next text line separated by the parser's 'dialog_separator'. Used
#	in this node's get_next_line() as the default.
#
# eof_reached() -> bool
#	Returns true or false depending on whether or not the end of file was reached
#
# get_reference_array() -> Array
#	Gets an array with the necessary information to restore the file state when
#	sent to load_file(args: Array)
#
# load_file(args: Array)
#	Restore the file state using the array generated by get_reference_array()
#
# open(...)
#	Creates/open a file of the specific type. A separate wrapper functions should
#	be created in this node's script per file type and return a bool indicating success
#	or not at opening the file
#
# seek(line_number: int, ...)
#	Moves the file to an specific line number, if there are more arguments added, 
#	those should be optional
#
# line_num
#	An int that at any moment in time contains the current line position of the
#	file 
#
# base
#	An instanced object of the class BaseFile. It is importante to use it's
#	set_open() and set_close() functions to indicate whether or not there's
#	a file open to read
#
# There's a funcion called _test_common_interfaces(file: Node) that will make 
# sure that the functions and variables are there; it will not, however, test the 
# proper inner working of said functions.

onready var normal_file = $NormalFile
onready var temporal_file = $TempFile
onready var skipper = $Skipper

const NORMAL_FILE_TYPE = 'normal'
const TEMPORAL_FILE_TYPE = 'temporal'

var current_file_type: String = 'none'
var load_file_func: String = "load_file"
var soft_load_file_option: String = "soft"
#var soft_option: String = "soft"
var file = null
var parser: Parser
#var backlog: Node

var types: Dictionary

signal spotlight_loaded(spotlight)


func _ready():
	types = {
		NORMAL_FILE_TYPE: normal_file,
		TEMPORAL_FILE_TYPE: temporal_file,
	}


func get_next_line() -> String:
	if is_open():
		return file.get_next_dialog_line()
	else:
		return ''


func eof_reached() -> bool:
	if _check_valid_file(false):
		_end_skip_entry()
		return file.eof_reached()
	else:
		return true


func load_file(cue: Cue):
	var is_soft = cue.get_bool_option(soft_load_file_option, false)
	var args: Array = cue.get_args()
	var disassembled_base: Array = args.pop_back()
	var type: String = args.pop_back()
	var success: bool = false
	_end_skip_entry()
	file = types[type]
	current_file_type = type
	if is_soft:
		file.base.merge_assemble(disassembled_base)
	else:
		file.base = BaseFile.new()
		file.base.assemble(disassembled_base)
	success = file.load_file(args)
	_start_skip_entry(success)
	if not success:
		l.g("Couldn't load file of type '" + type + "' with cue: " + str(cue))
	else:
		emit_signal("spotlight_loaded", file.base.current_spotlight)
	return success


func get_reference_cue(_current_line = false) -> Cue:
	if is_open():
		var arguments: Array 
#		if current_line:
#			arguments = file.get_current_line_reference_array()
#		else:
		arguments = file.get_reference_array()
		arguments.push_back(current_file_type)
		arguments.push_back(file.base.disassemble())
		var cue: Cue = Cue.new('', load_file_func).args(arguments)
		return cue
	else:
		return null


func get_soft_reference_cue() -> Cue:
	var cue: Cue = get_reference_cue()
	if cue != null:
		cue.options[soft_load_file_option] = true
		return cue
	else:
		return null


func open_normal_file(file_path: String, line_number: int = 0, file_cursor: int = 0) -> bool:
	if is_open():
		_end_skip_entry()
	current_file_type = NORMAL_FILE_TYPE
	file = normal_file
	var success = file.open(file_path, line_number, file_cursor)
	_start_skip_entry(success)
	return success


func open_temporal_file(text_to_read: String, id: String = '', line_number: int = 0) -> bool:
	if is_open():
		_end_skip_entry()
	current_file_type = TEMPORAL_FILE_TYPE
	file = temporal_file
	var success = file.open(text_to_read, id, line_number)
	_start_skip_entry(success)
	return success


func instance_temporal_file(text_to_read: String):
	var new_temp_file = temporal_file.get_script().new()
	new_temp_file.dialog_separator = temporal_file.dialog_separator
	var success = new_temp_file.open(text_to_read)
	if success:
		return new_temp_file
	else:
		return null


func is_open() -> bool:
	if _check_valid_file(false):
		return file.base.is_open
	else:
		return false


func get_line_num() -> int:
	if _check_valid_file():
		return file.line_num
	else:
		return 0


func get_indent() -> int:
	if _check_valid_file():
		return file.base.current_indent_level
	else:
		return -1


func set_indent(indent_level: int):
	if _check_valid_file():
		file.base.current_indent_level = indent_level


func get_spotlight() -> String:
	if _check_valid_file():
		return file.base.current_spotlight
	else:
		return ''


func set_spotlight(spotlight: String):
	if _check_valid_file():
		file.base.current_spotlight = spotlight


func get_abr_array() -> Array:
	if _check_valid_file():
		return file.base.abr_array
	else:
		return []


func get_id() -> String:
	if _check_valid_file():
		return file.base.skip_id
	else:
		return ''


func go_to(goal_markers: Array, indentation_level: int = -1, 
can_circle_back: bool = true, allow_end_as_stop: bool = false, 
exclude_outside_indent: bool = false) -> bool:
	# Search any of the goal_markers in current file with matching indent level, 
	# if it finds any, it will stop there. 
	# By adding ~ before the # to a marker, it will find a matching indent line
	# that doesn't have the marker
	# Markers only work at the beginning of a line
	
	# Will advance the current position in the file until meeting the first 
	# matching marker. If no matching marker it's found, it will simply circle
	# back to the starting point, print an error and return false
	
	if not is_open():
		return false
	
	var line
	var line_num_backup = file.line_num
	var new_line_num: int
	var has_marker = false
	var outside_indent_scope_reached = false
	var aux_resul
	var success = false
	_end_skip_entry()
	# search first coincidence from actual position to end of file
	while not eof_reached():
		new_line_num = file.line_num
		line = file.get_next_dialog_line() + "\n"
		aux_resul = _check_marker(line, goal_markers, indentation_level)
		has_marker = aux_resul[0]
		outside_indent_scope_reached = aux_resul[1] and exclude_outside_indent
		if has_marker or outside_indent_scope_reached:
			success = true
			break
	
	# if marker wasn't found search first coincidence from file start to actual position
	# but only if it can circle back, otherwise it will return to it's original position
	if not success and can_circle_back:
		file.seek(0)
		while file.line_num < line_num_backup:
			new_line_num = file.line_num
			line = file.get_next_dialog_line() + "\n"
			aux_resul = _check_marker(line, goal_markers, indentation_level)
			has_marker = aux_resul[0]
			outside_indent_scope_reached = aux_resul[1] and exclude_outside_indent
			if has_marker or outside_indent_scope_reached:
				break
	elif not success and not allow_end_as_stop:
		file.seek(line_num_backup)
	
	# if marker wasn't found, print error
	if success:
		file.seek(new_line_num)
	else:
		if not allow_end_as_stop:
			l.g("None of the following markers was found: " + str(goal_markers) + ".")
		else:
			success = true
	
	_start_skip_entry()
	#_start_backlog_entry()
	return success#has_marker and not outside_indent_scope_reached


func _check_valid_file(send_error: bool = true) -> bool:
	if file != null:
		return true
	
	if send_error:
		var error: String = "There's no file loaded in file manager. Current type: "
		error += current_file_type
		l.g(error)
	return false


func _check_marker(line: String, markers: Array, indentation_level: int) -> Array:
	return parser.check_marker_and_indent(line, markers, indentation_level)


func _start_skip_entry(should_start: bool = true):
	# Places where this should be:
	# 1. Right after opening a file - Done
	# 2. Right after loading a file - Done
	# 3. Right after jumping to a marker or indentation level - Review
	# 4. Right after exiting backlog - Done
	if should_start:
		skipper.start_skip_entry(get_id(), get_line_num())


func _end_skip_entry():
	# Places where this should be:
	# 1. Right before opening a file - Done
	# 2. Right before loading a file - Done
	# 3. Right before jumping to a marker or indentation level - Done
	# 4. Right before entering backlog - Done
	# 5. If end of line reached - Review
	skipper.end_skip_entry(get_id(), get_line_num())


func create_parser_event(metadata: String):
	file.base.create_parser_event(metadata)


func add_event_task(indent: int, marker: String, cues: Array):
	file.base.add_event_task(indent, marker, cues)


func push_parser_event(generate_rollback: bool):
	var success = file.base.push_parser_event()
	if generate_rollback and success:
		Director.add_rollback_cue('', "pop_parser_event")


func pop_parser_event(_cue: Cue = null):
	file.base.pop_parser_event()


func remove_all_parser_events():
	file.base.remove_parser_events()


func _on_Parser_parser_ready(parser_) -> void:
	parser = parser_


func _on_Jumper_jumper_ready(jumper_node) -> void:
	jumper_node.file = self


func _on_Backlog_entered_backlog() -> void:
	_end_skip_entry()


func _on_Backlog_exited_backlog() -> void:
	_start_skip_entry()


func _on_Parser_marker_found(marker: String, indent_level) -> void:
	var event_cues: Array = file.base.pop_matching_event_cues(indent_level, marker)
	# If there's no event, it will return an empty array, and if the array is empty,
	# the 'for' below won't execute anything
	var aux_cue: Cue
	for disassembled_cue in event_cues:
		aux_cue = Cue.new('', '').assemble(disassembled_cue.duplicate(true))
		aux_cue.set_reader(owner)
		aux_cue.execute()


func _on_Parser_indentation_change(_old_indent, new_indent) -> void:
	var event_cues = file.base.pop_matching_event_cues(new_indent, '')
	var aux_cue: Cue
	for disassembled_cue in event_cues:
		aux_cue = Cue.new('', '').assemble(disassembled_cue.duplicate(true))
		aux_cue.set_reader(owner)
		aux_cue.execute()


