extends Node


var file: Node
var backlog: Node
var marker_sign: String

var jump_in_stack: Array = Array()

signal jumper_ready(jumper)

func _ready() -> void:
	emit_signal("jumper_ready", self)


#[- jump to: file#marker] 
# Jump to specified file/marker
#
#[- jump in: file#marker] 
# Queues a "jump back" point at the current position and jumps to specified file/marker
#
#[- jump back] 
# Jumps to the most recent "jump back" point and remove it from queue, if there's any
#
#[- if: flag-1, ~flag-2, ...] 
# Keeps reading if it complies with all the flags specified in the other arguments. If a flag has the '~' symbol, it will be interpreted as 'has-not' flag rather than 'has'. Otherwise, it will jump to the nearest #end-if marker with the same level of indentation in tabs (\t) as the indentation level that the cue was sent.
#
#	/Options
#		end = #marker: If set, the if cue will try to jump to the marker rather than a matching indentation line when trying to reach the end of the if function. If it is set to an empty marker ('#') end will be '#end-if'.
#
#[- skip if: flag-1, ~flag-2, ...]
# Jumps to #end-skip marker if it complies with all the flags specified in the other arguments. If a flag has the '~' symbol, it will be interpreted as 'has-not' flag rather than 'has'.
#
#[- jump to if: flag-1, ~flag-2, ..., file#marker]
# Jumps to the file/marker specified in the last argument if it complies with all the flags specified in the other arguments. If a flag has the '~' symbol, it will be interpreted as 'has-not' flag rather than 'has'. 
#
#[- jump in if: flag-1, ~flag-2, ..., file#marker]
# Queues a "jump back" point at the current position and jumps to the file/marker specified in the last argument if it complies with all the flags specified in the other arguments. If a flag has the '~' symbol, it will be interpreted as 'has-not' flag rather than 'has'. 
#
#[- match: #marker]
# 	end = #end_if
# Jumps to the specified marker, and if it encounters any marker with the same indentation -1 after that, will skip until a line with the original indentation is found or to the end marker if specified.
#


func jump_to(cue: Cue) -> bool:
	# args = [file#marker: String]
	var success: bool = _jump(cue, 0, true)
	return success


func jump_in(cue: Cue) -> bool:
	# args = [file#marker: String]
	var return_point: Cue = file.get_reference_cue()
	var successful_jump = _jump(cue, 0, true)
	if successful_jump:
		jump_in_stack.push_back(return_point)
		if cue.requires_rollback:
			Director.add_rollback_cue('', 'pop_jump_in')
	
	return successful_jump


func pop_jump_in(_cue: Cue = null):
	jump_in_stack.pop_back()


func jump_back(_cue: Cue):
	var load_cue = jump_in_stack.pop_back()
	var successful_jump
	if load_cue != null and load_cue is Cue:
		successful_jump = load_cue.execute()
	else:
		successful_jump = false
		l.g("Couldn't perform jump_back, reference cue was null.")
	
	return successful_jump


func read_if(cue: Cue):
	# args = [flag-1, ~flag-2, ..., flag-n]
	# Options:
	#	end = #marker: If set, the if cue will try to jump to the marker rather 
	#	than a matching indentation line when trying to reach the end of the 
	#	function. If it is set to an empty marker ('#') end will be '#end-if'.

	var is_true = Flags.has(cue.args)
	var indent = cue.get_indent()
	var end_if = cue.get_option("end", '')
	var skip_else = "~#else"
	if end_if == '#':
		end_if = '#end-if'
		skip_else = end_if
	elif end_if != '':
		skip_else = end_if
	
	if is_true:
		file.create_parser_event(str(cue) + ". Indentation: " + str(indent))
		file.add_event_task(indent, '#else', [
			Cue.new('', 'abort'), 
			Cue.new('', '_go_to').args([[skip_else], indent, false, true])
		])
		file.add_event_task(indent, '', [])
		file.push_parser_event(cue.requires_rollback)
	else:
		file.go_to(['#else', end_if], indent, false, true)


func skip_if(cue: Cue):
	# args = [flag-1, ~flag-2, ..., flag-n]
	# Options:
	#	end = #marker: If set, the if cue will try to jump to the marker rather 
	#	than a matching indentation line when trying to reach the end of the 
	#	function. If it is set to an empty marker ('#') end will be '#end-if'.

	var is_true = Flags.has(cue.args)
	var end_skip = cue.get_option("end", '')
	if end_skip == '#':
		end_skip = '#end-skip'
	
	if not is_true:
		file.go_to([end_skip], cue.get_indent() + 1, false, true, true)


func jump_to_if(cue: Cue) -> bool:
	# args = [flag-1, ~flag-2, ..., flag-n, file#marker: String]
	var is_true = Flags.has(cue.slice(0, -2))
	var successful_jump: bool = false
	if is_true:
		successful_jump = _jump(cue, -1, true)
	
	return successful_jump


func jump_in_if(cue: Cue) -> bool:
	# args = [flag-1, ~flag-2, ..., flag-n, file#marker: String]
	var is_true = Flags.has(cue.slice(0, -2))
	var successful_jump: bool = false
	if is_true:
		successful_jump = jump_in(cue)
	
	return successful_jump


func _jump(cue: Cue, jump_str_pos: int, remove_parser_events_if_same_file_jump: bool = false):
	# args = [file#marker: String]
	var jump_str = cue.get_at(jump_str_pos, '')
	if jump_str == '':
		return false
	
	var go_back_cue: Cue = file.get_reference_cue(true)
	var args = jump_str.split(marker_sign)
	var file_name: String = args[0].strip_edges()
	var marker = ''
	if args.size() > 1:
		marker = args[1].strip_edges()
	# file and marker jump success is set to true by default, that way if there was 
	# either no file or marker jump attempeted, it won't affect the overall success of the jump
	var file_jump_success: bool = true 
	var marker_jump_success: bool = true
	var overall_success: bool = false
	
	if file_name != '':
		file_jump_success = file.open_normal_file(file_name)

	if marker != '':
		marker = marker_sign + marker
		marker_jump_success = file.go_to([marker])
	
	if file_jump_success and marker_jump_success: 
		overall_success = true
		if file_name == '' and marker != '' and remove_parser_events_if_same_file_jump:
			file.remove_parser_events()
	else:
		overall_success = false
		if not marker_jump_success:
			l.g("Can't jump_to  to marker: '" + marker + "'. Cue: " + str(cue))
		
		if not file_jump_success:
			l.g("Can't jump_to  to file '" + file_name + "'. Couldn't open. Cue: " + str(cue))
		
		if go_back_cue == null:
			l.g("RefCounted cue is null when trying to restore state before jump attempt with cue:" + 
			str(cue), l.WARNING)
		else:
			go_back_cue.execute()
	return overall_success


func select_subcategory(cue: Cue):
	# args = [#marker: String]
	# Options:
	#	end = #marker: If set, the if cue will try to jump to the marker rather 
	#	than a matching indentation line when trying to reach the end of the 
	#	function. If it is set to an empty marker ('#') end will be '#end'.
	var target = cue.get_at(0, "")
	var indent = cue.get_indent()
	var end_category: String = cue.get_option("end", '#')
	if end_category == '#':
		end_category = '#end'
	
	var success: bool = file.go_to([target], indent + 1, false, true, true)
	if success:
		file.create_parser_event(str(cue) + ". Indentation: " + str(indent))
		file.add_event_task(indent + 1, end_category, [])
		file.add_event_task(indent + 1, end_category.to_upper(), [])
		file.add_event_task(indent + 1, '~' + target, [
			Cue.new('', 'discard'), 
			Cue.new('', '_go_to').args([[end_category], indent + 1, false, true, true]),
		])
		file.add_event_task(indent, '', [])
		file.push_parser_event(cue.requires_rollback)
	else:
		file.go_to([end_category], indent, false, true, true)


func attempt_jump_back() -> bool:
	var success = false
	if not jump_in_stack.empty():
		success = jump_back(null)
	
	return success


func match_flag(cue: Cue):
#	[match flag:
#	flag_mid = #mid,
#	flag_start = #start,
#	flag_end = #end,
#	...]
#	If no match occurs, it will jump to #default
#	WARNING: Since this use sub_category, at the end, it will try to jump to an #end marker
	var flags_with_markers = cue._options
	var marker: String = ''
	var default_marker = '#default'
	for flag in flags_with_markers.keys():
		marker = flags_with_markers[flag].strip_edges()
		if marker.substr(0, 1) == "#" and Director.has_flag(flag):
			break
		
		marker = '' # we reset the marker to '', it will only have value if the break happens
	
	if marker == '':
		marker = default_marker
	
	cue.opts({})
	cue.args([marker])
	select_subcategory(cue)


func match_abr(cue: Cue):
#	[match abr: /abr,
#	Lynn = #lynn,
#	Fran = #fran,
#	Chloe = #chloe,
#	...]
#	If no match occurs, it will jump to #default
#	WARNING: Since this use sub_category, at the end, it will try to jump to an #end marker
	var meanings = cue.options
	var marker: String = ''
	var default_marker = '#default'
	var abr = cue.get_at(0, '')
	var abr_meaning =  Director.replace_abr(abr, '')
	if abr_meaning == '':
		return
	
	for meaning in meanings.keys():
		meaning = meanings[meaning].strip_edges()
		if marker.substr(0, 1) == "#" and abr_meaning == meaning:
			break
		
		marker = '' # we reset the marker to '', it will only have value if the break happens
	
	if marker == '':
		marker = default_marker
	
	cue.opts({})
	cue.args([marker])
	select_subcategory(cue)


func match_value(cue: Cue):
#	[match value: flag-1,
#	0 = #zero,
#	1-4 = #low,
#	5-7 = #med,
#	8-n = #high]
#	n means 
#		- any number lower than if placed left
#		- any number higher than if placed right
#	If no match occurs, it will jump to #default
#	WARNING: Since this use sub_category, at the end, it will try to jump to an #end marker
	var value_ranges = cue.options
	var marker: String = ''
	var default_marker = '#default'
	var flag_name = cue.get_at(0, '')
	var flag_ref = Flags.ref(flag_name)
	var flag_value
	if flag_name == '':
		l.g("Failed to match flag value, no flag especified or empty flag.")
		return
	
	if not flag_ref.exists():
		l.g("Failed to match flag value, flag '" + flag_name + "' doesn't exists.")
		return
	
	flag_value = flag_ref.value
	for val_range in value_ranges.keys():
		marker = value_ranges[val_range].strip_edges()
		if marker.substr(0, 1) == "#" and _is_value_range_match(val_range, flag_value, cue):
			break
		
		marker = '' # we reset the marker to '', it will only have value if the break happens
	
	if marker == '':
		marker = default_marker
	
	cue.opts({})
	cue.args([marker])
	select_subcategory(cue)


func _is_value_range_match(value_range: String, value_to_match: float, cue: Cue):
	var limits: Array = value_range.split('-', false, 1)
	var lim1: float
	var lim2: float
	var is_match: bool = false
	var infinite: String = 'n'
	if limits.size() == 1:
		lim1 = float(limits[0])
		is_match = value_to_match == lim1
	elif limits.size() == 2:
		lim1 = float(limits[0])
		lim2 = float(limits[1])
		if limits[0].strip_edges() == infinite:
			is_match = value_to_match <= lim2
		elif limits[1].strip_edges() == infinite:
			is_match = value_to_match >= lim1
		else:
			is_match = value_to_match >= lim1 and value_to_match <= lim2
	else:
		l.g("Failed to match value, invalid range '" + value_range + "' at cue: " + str(cue))
	
	return is_match
