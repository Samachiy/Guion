extends Node

# Backlog entries are not deleted, but rather are disabled
# When disabled, they will just keep the spotlight and text
const SPOTLIGHT =  "spotlight"
const TEXT =  "text"
const ROLLBACK_CUES =  "rollback_cues"
const RESTORE_CUES =  "restore_cues"
const BREAK_CUES =  "break_cues"
const FILE_LOAD_CUE =  "file_load_cue"
const CAN_ROLLBACK =  "can_rollback"
const CONTEXT_SIGN =  "context_sign"

const BACKLOG_ENTRY: Dictionary = {
	SPOTLIGHT: '',
	TEXT: '',
	ROLLBACK_CUES: [],
	RESTORE_CUES: [],
	BREAK_CUES: [],
	FILE_LOAD_CUE: [],
	CAN_ROLLBACK: true,
}

var array: Array = Array()
var cursor: int = -1
var disabled_cursor: int = -1
var _is_backlog: bool = false setget set_is_backlog
var _is_backlog_up: bool = false
var is_recording_backlog: bool = false
var new_backlog_entry: Dictionary
var consume_next_read_cue: bool = false

signal entered_backlog
signal exited_backlog
signal backlog_ready(backlog)
signal backlog_jump_performed

func _ready() -> void:
	emit_signal("backlog_ready", self)


func start_backlog_entry(file_load_cue: Cue) -> bool:
	var success = false
	if _is_backlog_up:
		return success
	
	if not _is_backlog and not is_recording_backlog:
		new_backlog_entry = BACKLOG_ENTRY.duplicate(true)
		new_backlog_entry[FILE_LOAD_CUE] = file_load_cue.disassemble()
		success = true
	
	is_recording_backlog = true
	return success


func end_backlog_entry(spotlight: String, text: String):
	if not is_recording_backlog or text.strip_edges() == '':
		return
	
	is_recording_backlog = false
	if not _is_backlog:
		new_backlog_entry[SPOTLIGHT] = spotlight
		new_backlog_entry[TEXT] = text
		_fix_new_backlog_entry_if_disabled()
		array.append(new_backlog_entry)
		cursor += 1
		#L.p('Backlog cursor: ' + str(cursor))


func _fix_new_backlog_entry_if_disabled():
	if new_backlog_entry[CAN_ROLLBACK] == false:
		if array[array.size() - 1][CAN_ROLLBACK] == false:
			disabled_cursor += 1
		else:
			l.g("Trying to add a disabled backlog entry on top of non-disabled backlog" + 
			"registries, proceding to enable new entry again. New backlog entry: " 
			+ str(new_backlog_entry))
			new_backlog_entry[CAN_ROLLBACK] = true


func discard_backlog_entry():
	if not is_recording_backlog:
		return
	
	is_recording_backlog = false
	if not _is_backlog and not array.empty():
		new_backlog_entry = array[array.size() - 1]


func trim_at(backlog_array: Array, pos = null):
	#trims all the backlog entries positions ahead of the backlog cursor position
#	print_status("TRIMMING")
	if pos == null:
		pos = cursor
	
	if pos > disabled_cursor + 1:
		backlog_array.resize(pos + 1)
		self._is_backlog = false
		_is_backlog_up = false
	else:
		l.g("Failed to trim. Tried to trim disabled backlog entries. Trim postion: " 
		+ str(pos) + ", disabled backlog cursor: " + str(disabled_cursor) + ".")


func trim():
	trim_at(array, cursor)


func get_trimmed_active_backlog():
	return get_active_backlog(cursor)


func disable_backlog():
	# will disable the backlog entries from the current backlog disabled_cursor
	# up to the current backlog cursor
	while disabled_cursor < cursor:
		array[disabled_cursor][CAN_ROLLBACK] = false
		disabled_cursor += 1


func disable_new_backlog_entry():
	new_backlog_entry[CAN_ROLLBACK] = false


func get_active_backlog(end = null) -> Array:
	var active_backlog: Array
	if end == null:
		end = array.size() - 1
	if not array.empty():
		active_backlog = array.slice(disabled_cursor + 1, end, 1, true)
	else:
		active_backlog = []
	
	return active_backlog


func set_is_backlog(value):
	var prev_value = _is_backlog
	_is_backlog = value
	if prev_value != value:
		if _is_backlog == true:
			emit_signal("entered_backlog")
			if is_recording_backlog:
				l.g("Entered into backlog without finishing current backlog entry: "
				+ str(new_backlog_entry[FILE_LOAD_CUE]))
		else:
			emit_signal("exited_backlog")


func backlog_up():
	if cursor > disabled_cursor + 1:
		_is_backlog_up = true
		self._is_backlog = true
		_execute_cues(array[cursor][ROLLBACK_CUES])
		#wipe_current_backlog_entry_cues()
		cursor -= 1
		_execute_cues(array[cursor][RESTORE_CUES])
		load_current_backlog_entry()


func backlog_down():
	if cursor < array.size() - 1:
		_is_backlog_up = false
		self._is_backlog = true
		_execute_cues(array[cursor][BREAK_CUES])
		cursor += 1
		load_current_backlog_entry()
	else:
		_is_backlog_up = false
		self._is_backlog = false


func reset_backlog_cursor():
	cursor = array.size() - 1


func refresh_is_backlog_var():
	# This is intending to be used on reader.end_reading()
	# check if after reading the last text, it is indeed the last backlog entry
	# and thus sets the vars accordingly
	if cursor == array.size() - 1: # aka last backlog entry
		self._is_backlog = false
	else:
		self._is_backlog = true
	

func load_current_backlog_entry():
	var cue = Cue.new('', '').assemble(array[cursor][FILE_LOAD_CUE].duplicate(true))
	cue.execute()
	emit_signal("backlog_jump_performed")
	


func wipe_current_backlog_entry_cues():
	wipe_backlog_entry_cues(array[cursor])


func get_last_file_load_cue():
	if is_recording_backlog and new_backlog_entry[CAN_ROLLBACK]:
		return Cue.new('', '').assemble(new_backlog_entry[FILE_LOAD_CUE].duplicate(true))
	else:
		return null


func _execute_cues(cues_array: Array):
	var aux_cue: Cue
	for i in range(cues_array.size()):
		aux_cue = Cue.new('', '').assemble(cues_array[i].duplicate(true))
		aux_cue.execute()


func clear():
	var i = disabled_cursor + 1
	while i <= cursor:
		disable_backlog_entry(array[i])
	
	disabled_cursor = i
	self._is_backlog = false
	_is_backlog_up = false


func add_rollback_cue(role_string: String, method: String, args: Array = [], 
options: Dictionary = {}, half_rollback: bool = false):
	var cue: Cue = Cue.new(role_string, method).args(args)
	cue.options = options
	var dis_cue
	if is_recording_backlog and not _is_backlog:
#		if _is_backlog:
#			array[cursor][ROLLBACK_CUES].append(cue.disassemble())
#		else:
		dis_cue = cue.disassemble()
		new_backlog_entry[ROLLBACK_CUES].append(dis_cue)
		if not half_rollback:
			new_backlog_entry[RESTORE_CUES].append(dis_cue)


func add_restore_state_cue(role_string: String, method: String, args: Array = [], 
options: Dictionary = {}):
	var cue: Cue = Cue.new(role_string, method).args(args)
	cue.options = options
	if is_recording_backlog:
#		if _is_backlog:
#			array[cursor][RESTORE_CUES].append(cue.disassemble())
#		else:
		if not _is_backlog:
			new_backlog_entry[RESTORE_CUES].append(cue.disassemble())


func add_break_state_cue(role_string: String, method: String, args: Array = [], 
options: Dictionary = {}):
	var cue: Cue = Cue.new(role_string, method).args(args)
	cue.options = options
	if is_recording_backlog:
#		if _is_backlog:
#			array[cursor][BREAK_CUES].append(cue.disassemble())
#		else:
		if not _is_backlog:
			new_backlog_entry[BREAK_CUES].append(cue.disassemble())


func _on_exited_backlog():
	emit_signal("exited_backlog")


func _on_entered_backlog():
	emit_signal("entered_backlog")


func is_backlog():
	return _is_backlog


func is_backlog_up():
	return _is_backlog_up


func disable_backlog_entry(entry: Dictionary) -> void:
	entry[CAN_ROLLBACK] = false
	entry[FILE_LOAD_CUE].resize(0)
	wipe_backlog_entry_cues(entry)


func wipe_backlog_entry_cues(entry: Dictionary) -> void:
	entry[ROLLBACK_CUES].resize(0)
	entry[RESTORE_CUES].resize(0)
	entry[BREAK_CUES].resize(0)


func print_status(text):
	l.p(text)
	l.p('Backlog size: ' + str(array.size()))
	l.p('Backlog cursor: ' + str(cursor))
	for i in range(array.size()):
			l.p(str(i) + ': ' + str(array[i]) + '. RB cues: ' + str(array[i][ROLLBACK_CUES]))


func _on_Jumper_jumper_ready(jumper_node) -> void:
	jumper_node.backlog = self



