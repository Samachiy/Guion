extends Reference
class_name BaseFile

var is_open: bool = false
#	A bool indicateing whether or not there's a file open to read from
var abr_array: Dictionary
#	An array that contains the abbreviations to be used by the file
var current_indent_level: int = -1
#	An int that contains the current indentation level of the file 
var current_spotlight: String = ''
#	A string that contains the current name of role in the spotlight
var skip_id: String = ''
#	A string that contains an id in order to identify said file for the purpose
#	of storing already read text info. If said string is empty, it will be 
#	considered that said info is not relevant to be saved for that specific file
var events: Array = Array() # Contains arrays called event, each event contains arrays called entry
# the structure of said entry is [indent, marker, cues]
var new_event = null #: Array = [] # replace to null and remove typing when done

func _init() -> void:
	abr_array = {}


func set_close():
	if is_open:
		abr_array = {}
	is_open = false
	skip_id = ''


func set_open(_skip_id: String):
	if not is_open:
		abr_array = {}
	is_open = true
	skip_id = _skip_id


func create_parser_event(_metadata: String):
	new_event = []


func add_event_task(indent: int, marker: String, cues: Array):
	var disassembled_cues: Array = []
	for cue in cues:
		disassembled_cues.append(cue.disassemble())
	
	if new_event != null:
		new_event.append([indent, marker, disassembled_cues])
	else:
		l.g("Couldn't add task '" + str(indent) + ', ' + marker + str(cues) + 
		"' to event, event is null")


func push_parser_event() -> bool:
	if new_event != null:
		events.append(new_event)
		new_event = []
		return true
	else:
		l.g("Couldn't submit event, event is null")
		return false


func pop_parser_event():
	events.pop_back()


func pop_matching_event_cues(indent: int, marker: String) -> Array:
	var matching_event: Array = []
	for i in range(events.size()):
		matching_event = _attempt_event_match(events[i], marker, indent)
		if not matching_event.empty():
			events.resize(i)
			break
	
	if matching_event == []:
		return []
	else:
		return matching_event[2] # cues of the entry


func remove_all_parser_events():
	events.resize(0)


func _attempt_event_match(event: Array, marker: String, indent: int) -> Array:
	var matched_entry = []
	for entry in event:
		if _is_entry_match(entry, marker, indent):
			matched_entry = entry
			break
	
	return matched_entry


func _is_entry_match(entry: Array, marker: String, indent_level: int):
	# entry = [indent, marker, cues]
	
	# If marker (the one in the array entry[1]) is '#', that means any marker will do, so
	# long as the received marker (this func argument) is not empty, since if it is
	# empty that will mean that the event we are trying to match is
	# an indentation_change and not a marker_found signal from the parser
	var not_marker
	if entry[1] == '#' and marker != '':
		return entry[0] == indent_level
	elif indent_level == entry[0]:
		# we check if they are the same
		if marker == entry[1]: 
			return true
		# we check if the marker is different ('~' means 'not' here)
		elif entry[1].substr(0, 1) == '~' and marker != '': 
			not_marker = entry[1].substr(1)
			return not_marker != marker # if the marker is not the same as the not_marker
	elif entry[1] == '' and indent_level <= entry[0]:
		return true
	else:
		return false


func disassemble() -> Array: # disassemble the base file
	var resul: Array = []
	# new variables go at the beginning
	resul.push_back(is_open)
	resul.push_back(abr_array.duplicate(true))
	resul.push_back(current_indent_level)
	resul.push_back(current_spotlight)
	resul.push_back(skip_id)
	resul.push_back(events.duplicate(true))
	if new_event == null:
		resul.push_back(null)
	else:
		resul.push_back(new_event.duplicate(true))
	return resul


func assemble(disassembled_base_file: Array): # assemble the base file
	new_event = disassembled_base_file.pop_back()
	events = disassembled_base_file.pop_back()
	skip_id = disassembled_base_file.pop_back()
	current_spotlight = disassembled_base_file.pop_back()
	current_indent_level = disassembled_base_file.pop_back()
	abr_array = disassembled_base_file.pop_back()
	is_open = disassembled_base_file.pop_back()
	# new variables go at the end
	pass


func merge_assemble(disassembled_base_file: Array):
	new_event = disassembled_base_file.pop_back()
	events = disassembled_base_file.pop_back()
	skip_id = disassembled_base_file.pop_back()
	current_spotlight = disassembled_base_file.pop_back()
	current_indent_level = disassembled_base_file.pop_back()
	disassembled_base_file.pop_back() # Disabled abr_array
	is_open = disassembled_base_file.pop_back()
	# This function is a copy of assemble but with deactivated values
	# in the things that the new file should not overwrite.
	# Place a comment indication what was disabled.
	pass


