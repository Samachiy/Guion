extends Node

const AUTO_TIME_FACTOR_DEFAULT = 0.06
const AUTO_TIME_PADDING_DEFAULT = 0.2

onready var line = $Line
onready var normalfile = $FileManager/NormalFile
onready var tempfile = $FileManager/TempFile
onready var file = $FileManager
onready var backlog = $Backlog
onready var parser = $Parser
onready var wait_timer = $Wait
onready var skipper = $FileManager/Skipper
onready var jumper = $Jumper
onready var auto_timer = $AutoTimer

export var text_speed: float = 0.03
export var can_skip_unread_text: bool = false
export var csv_translations_on_file: bool = false
export var allow_empty: bool = false
export var read_this_caller: String = 'self'

var is_reading: bool = false setget _set_is_reading
var should_read: bool = true # Whether or not the reader should continue reading
var is_waiting: bool = false setget _set_is_waiting
#var forced_waiting: bool = false
var is_force_flushing: bool = false # Whether or not should flush ignoring wait cues
var should_skip: bool = false # Turns true on skip(), and false when signal finished_reading is emited
var current_text: String = ""
# Abbreviations prority order from first to last: File, spotlight, global
var global_abr_array: Dictionary # Get it's abbreviations from cues, loses it from cues
var is_preparing_to_read: bool = false # indicates that reader is parsing
var discarded_read: bool = false
var is_auto_enabled: bool = false
var auto_time_factor: float = AUTO_TIME_FACTOR_DEFAULT
var auto_time_padding: float = AUTO_TIME_PADDING_DEFAULT
var new_text_counter: int = 0 # amount of characters added since last request_auto(), used to calculate the auto time
var current_line_start_reference_cue
var is_processing: bool = false
var is_aborted: bool = false
signal spotlight_changed(role)
signal text_changed(text)
signal finished_reading
signal process_finished(self_node)

func _ready():
	parser = parser.parser
	normalfile.dialog_separator = parser.dialog_separator
	tempfile.dialog_separator = parser.dialog_separator
	jumper.marker_sign = parser.marker_sign
	line.text_type_int = parser.TEXT
	global_abr_array = {}


func skip():
	if not should_skip:
		should_skip = _check_if_skip()
		read()


func _check_if_skip() -> bool:
	var allow_skip = false
	if can_skip_unread_text:
		allow_skip = true
	else:
		allow_skip = skipper.should_skip(file.get_id(), file.get_line_num())
	
	return allow_skip


func read():
	is_aborted = false
	if should_read:
		if is_processing:
			_process_next()
		if is_waiting:
			resume()
		elif is_reading: 
			_flush()
		else:
			_read_next()
	else:
		l.g("Reader is currently paused", l.WARNING)


func _process_next():
	should_skip = true
	# since read next returns false if theres not file loaded or no file left to read
	# when it returns false, that means that is_processing is also done for
	is_processing = _read_next()
	if not is_processing:
		emit_signal("process_finished", self)


func wait(cue: Cue = null):
	#L.p(get_stack())
	var time = -1
	if cue != null:
		time = cue.get_float(0, -1, false)
	
	if not is_force_flushing and not should_skip:
		line.stop()
		self.is_waiting = true
		if time != -1:
			wait_timer.start(time)
		elif is_auto_enabled:
			request_auto()


func resume():
	if should_skip:
		force_flush()
	elif is_waiting:
		self.is_waiting = false
		if line.is_finished(false):
			read()
		elif not line.resume():
			# if resume within the line failed, the we execute normal reading just to be safe
			read()


func abort(_cue: Cue = null):
	# Forcibly stop the reading process, will also discarg current backlog entry
	is_aborted = true
	line.stop()
	self.is_reading = false
	is_preparing_to_read = false
	line.array.resize(0)
	backlog.discard_backlog_entry()


func discard(_cue: Cue = null):
	# This function does nothing different from abort, and discarded_read use is 
	# beyond questionable, pending remove in a next version
	# Forcibly abort current reading process and starts again
	abort(_cue)
	discarded_read = true


func _flush():
	while not line.is_finished():
		if is_waiting and is_force_flushing:
			is_waiting = false
		elif is_waiting:
			break
		line._on_Line_timeout()


func force_flush():
	self.is_waiting = false
	is_force_flushing = true
	_flush()
	is_force_flushing = false


func read_this(text: String, caller: Node = null, skip_id: String = ''):
	if _can_open_file(text):
		Roles.request_role(caller, read_this_caller, true)
		if file.open_temporal_file(text, skip_id):
			read()


func read_file(text_file_path):
	if _can_open_file(text_file_path):
		if file.open_text_file(text_file_path):
			read()


func _can_open_file(not_empty_file_info) -> bool:
	var success: bool = false
	if !is_reading and not_empty_file_info.strip_edges() != '':
		success = true
	elif not should_read:
		l.g("Reader paused, can't read text right now.", l.WARNING)
	else:
		l.g("Couldn't read:\n" + not_empty_file_info + "\n\n" +
		"Currently reading file '" + str(file.get_reference_cue())+ "'.")
	
	return success


func _read_next():
	# return true if managed to read next or false if it doesn't
	if not file.is_open():
		return false
	
	if file.eof_reached():
		return false
	
	_start_backlog_entry()
	var line_string = file.get_next_line()
	is_preparing_to_read = true
	var line_array = _parse_line(line_string, file.get_indent(), file.get_spotlight())
	l.p(line_array)
	file.set_indent(line_array.pop_back())
	if is_preparing_to_read:
		self.is_reading = true
		discarded_read = false
		clear_text()
		is_preparing_to_read = false
		_start_reading(line_array)
	elif discarded_read:
		read()
	
	return true


func _start_reading(line_array: Array):
	if should_skip:
		line.set_line(line_array)
		force_flush()
	else:
		line.set_and_read_line(line_array, text_speed)


func _parse_line(line_to_parse: String, prev_indent_level: int, current_spotlight: String,
 apply_csv_translation = false):
	var spotlight: Role = Roles.get_role(file.get_spotlight(), false)
	var abr_arrays
	if spotlight == null:
		abr_arrays = [file.get_abr_array(), global_abr_array]
	else:
		abr_arrays = [file.get_abr_array(), spotlight.get_abr_array(), global_abr_array]
	var resul = parser.parse(line_to_parse, abr_arrays, prev_indent_level, 
	current_spotlight, apply_csv_translation)
	return resul


func _append_text(text):
	current_text += text
	new_text_counter += 1
	emit_signal("text_changed", current_text)


func clear_text():
	current_text = ""
	emit_signal("text_changed", current_text)


func set_text(cue: Cue):
	# [test: String]
	current_text = cue.get_at(0, '')


func enable_auto(time_factor = null):
	if time_factor != null:
		auto_time_factor = AUTO_TIME_FACTOR_DEFAULT 
	else:
		auto_time_factor = time_factor
	is_auto_enabled = true
	read()


func disable_auto():
	is_auto_enabled = false
	auto_timer.stop()


func request_auto():
	if is_auto_enabled:
		auto_timer.start(AUTO_TIME_PADDING_DEFAULT + auto_time_factor * new_text_counter)
	
	new_text_counter = 0


func _set_is_reading(value):
	is_reading = value
	if not is_reading:
		should_skip = false
		emit_signal("finished_reading")


func _set_is_waiting(value):
	is_waiting = value
	line.should_wait = is_waiting


func set_spotlight(role: Role):
	file.set_spotlight(str(role))
	emit_signal("spotlight_changed", role)


func _on_Line_read_next_char():
	var text_send = false # Because this function is activated only after the 
	# line timer ends, this bool is to make sure that pn every timer end we have
	# sent at least one character. Otherwise ti will look like the program
	# is throttling
	if is_waiting:
		return
	
	var cue_aux: Cue
	var resul
	var character
	while not text_send and line.array.size() != 0:
		match line.array[0][1]:
			parser.ROLE:
				set_spotlight(line.array[0][0])
				line.array.pop_front()
			parser.TEXT:
				if line.cursor < line.array[0][0].length():
					character = line.array[0][0][line.cursor]
					_append_text(character)
					line.cursor += 1
					text_send = true
				else:
					line.array.pop_front()
					_append_text(' ')
					line.cursor = 0
			parser.CUE:
				#if not backlog.is_backlog_up():
				cue_aux = line.array[0][0]
				cue_aux.requires_rollback = not backlog.is_backlog()
				cue_aux.set_reader(self)
				Director.console.add_entry(str(cue_aux))
				cue_aux.execute_or_store(true)
				#resul = manager.execute_or_store_cue(cue_aux, true, true)
				if resul != null:
					Director.console.append_text(': ' + str(resul))
				# if reader is waiting because of the 'wait cue, that means 
				# that it should not keep reading any characters, thus we set
				# text_send = true to stop the while loop and don't send more chars.
				if is_waiting:
					text_send = true
				line.array.pop_front()


func _on_Line_finished():
	if file.eof_reached():
		_end_reading()
	elif _continue_if_empty() and should_read:
		_read_next()
	else:
		_end_reading()


func _end_reading():
	line.stop()
	_end_backlog_entry()
	self.is_reading = false
	backlog.refresh_is_backlog_var()
	if is_auto_enabled:
		request_auto()


func _continue_if_empty():
	if is_aborted:
		return false
	
	if not allow_empty and current_text.strip_edges().empty():
		return true
	else:
		return false


func _on_Wait_timeout():
	if is_waiting:
		#self.is_waiting = false
		wait_timer.stop()
		resume()


func _start_backlog_entry():
	# Places where this should be:
	# 1. Right in read_next() in reader
	var ref_cue = file.get_reference_cue()
	if backlog.start_backlog_entry(ref_cue):
		current_line_start_reference_cue = ref_cue


func _end_backlog_entry():
	# Places where this should be:
	# 1. Right in end_reading() in reader
	backlog.end_backlog_entry(file.get_spotlight(), current_text)



# ABBREVIATION FUNCTIONS


func add_global_abr(cue: Cue):
	# Creates or replaces a global abbreviation
	# args = [abr, meaning]
	var key = cue.get_at(0)
	var value = cue.get_at(1)
#	# This was for not setting it if it already exists
#	if key in global_abr_array:
#		L.g("Couldn't add global abbreviation: " + str(key))
#	else:
	global_abr_array[key] = value


func remove_global_abr(cue: Cue):
	# Removes a global abbreviation
	# args = [abr]
	var key = cue.get_at(0)
	return global_abr_array.erase(key)


func add_abr(cue: Cue):
	# Creates or replaces a file abbreviation
	# args = [abr, meaning]
	var key = cue.get_at(0)
	var value = cue.get_at(1)
#	# This was for not setting it if it already exists
#	if key in file.file.base.abr_array:
#		L.g("Couldn't add global abbreviation: " + str(key))
#	else:
	file.file.base.abr_array[key] = value


func remove_abr(cue: Cue):
	# Removes a file abbreviation
	# args = [abr]
	var key = cue.get_at(0)
	return file.file.base.abr_array.erase(key)


func replace_abr(abbreviation: String, default: String = ''):
	return global_abr_array.get(abbreviation, default)


func _on_Backlog_backlog_jump_performed() -> void:
	
	read()


func _on_FileManager_spotlight_loaded(spotlight) -> void:
	var role = Role.new(null, spotlight)
	set_spotlight(role)
