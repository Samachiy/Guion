extends Reference
class_name Parser

export var dialog_separator: String = "\n\n"
export var cue_start: String = "["
export var cue_end: String = "]"
export var str_sub_cue_start: String = "("
export var str_sub_cue_end: String = ")"
export var string_start_1: String = '"""'
export var string_end_1: String = '"""'
export var string_start_2: String = "'''"
export var string_end_2: String = "'''"
export var cue_arg_string_start_1: String = '"'
export var cue_arg_string_end_1: String = '"'
export var cue_arg_string_start_2: String = "'"
export var cue_arg_string_end_2: String = "'"
export var variable_sign: String = "/"
export var marker_sign: String = "#"
export var actor_sign: String = ":"
export var cue_actor_sign: String = "- "
export var cue_method_sign: String = ":"
export var cue_argument_sign: String = ","
export var translation_sign: String = "%"
export var line_break_allowed: bool = false
export var method_to_lowercase: bool = true
export var sign_end_regex: String = "[0-9a-zA-z_-]"
export var indent_sign: String = "\t"
export var comment_sign: String = "##"
export var context_sign: String = '@'
export var argument_option_sign: String = '='
export var annotation_sign: String = '<'
const line_break: String = "\n"
const empty_space: String = "[\t\n ]"
const abr_array_spotlight_pos: int = 1

enum {
	ROLE,
	TEXT,
	CUE
}

var regex_token: RegEx
var regex_indent: RegEx
var regex_line_break: RegEx
var regex_empty_space: RegEx
var default_spotlight: String

signal parser_ready(parser)
signal marker_found(marker, indent_level)
signal indentation_change(old_indent, new_indent)


func _init():
	regex_token = RegEx.new()
# warning-ignore:return_value_discarded
	regex_token.compile(sign_end_regex)
	regex_indent = RegEx.new()
# warning-ignore:return_value_discarded
	regex_indent.compile(indent_sign)
	regex_line_break = RegEx.new()
# warning-ignore:return_value_discarded
	regex_line_break.compile(line_break)
	regex_empty_space = RegEx.new()
# warning-ignore:return_value_discarded
	regex_empty_space.compile(empty_space)
	emit_signal("parser_ready", self)
	#test_parser()


func extract_cues(text, abr_arrays: Array):
	var parsed_text = parse(text, abr_arrays, 0, '', false)
	parsed_text.pop_back()
	var resul: Array = []
	for fragment in parsed_text:
		if fragment[1] == CUE:
			resul.append(fragment[0])
	return resul


func parse(line: String, abr_arrays: Array, prev_indent_level: int, spotlight_str: String, 
apply_csv_translation = false) -> Array:
	if apply_csv_translation:
		line = _parse_phase_zero(line)
	var parse_one_resul = _parse_phase_one(line, abr_arrays, prev_indent_level, spotlight_str)
	return parse_one_resul


func check_marker_and_indent(line: String, markers: Array, indentation_level: int) -> Array:
	# By adding ~ before the # to a marker, it will find a matching indent line
	# that doesn't have the marker
	# Sending an empty marker (only the '#') will match any found marker
	# Sending an empty string (only '') will only match indentation level
	var matcher: Matcher = Matcher.new(line)
	matcher.line = line
	var i: int = 0
	var is_line_start = true 
	var indent_level = 0 	# changed from -1 to 0 because when the indentation was 0, 
							# it was being interpreted as outside indentation
	var is_line_indent = true
	var success = false
	var indent_level_match: bool = true
	var matched_marks = Array()
	var outside_indentation: bool = false
	while i < line.length() and is_line_start:
		match line[i]:
			'\t':
				# POINT 1: Sets indentation level and removes indentation
				if is_line_indent:
					indent_level = _parse_indentation(matcher, i, line, indent_level, is_line_start)
					matcher.remove_match()
					i = matcher.match_end
					line = matcher.line
					is_line_indent = false
					i -= 1 # offset the i += 1 at 'while' end
					if indent_level != indentation_level and indentation_level != -1:
						indent_level_match = false
						success = false
						break
			'#':
				# POINT 2: Remove comments
				matcher.match_at_before(i, line, comment_sign, '\n')
				if matcher.is_match:
					matcher.remove_match()
					i = matcher.match_end
					line = matcher.line
					is_line_indent = true
					# Since comments can only end at a line break, we set is_line_indent
					# to true
					i -= 1 # offset the i += 1 at 'while' end
				else:
				# POINT 3: Removes markers and compares them
					is_line_start = _parse_marker(matcher, i, line, indent_level, 
					is_line_start, false)
					if matcher.is_match:
						var matched_mark = matcher.get_match()
						matched_marks.append(matched_mark)
						for j in range(markers.size()):
							if matched_mark == markers[j] and indent_level_match:
								success = true
								break
							
						matcher.remove_match()
						i = matcher.match_end
						line = matcher.line
						i -= 1 # offset the i += 1 at 'while' end
			' ':
				pass
			'\n':
				# POINT 5: Parse multiline (Line breaks)
				matcher.match_chars(i, line, line_break)
				if matcher.is_match:
					if not line_break_allowed:
						matcher.replace_match(' ')
						i = matcher.match_end
						line = matcher.line
					else:
						i += 1
					
					is_line_indent = true
					i -= 1 # offset the i += 1 at 'while' end
			_:
				is_line_start = false
		i += 1
	# if there was no match in checking if it have a marker from the list, we 
	# will see if we can get a match by the line:
	#	a. NOT having a marker with the ~ at the  beggining 
	#	b. having an entry as '' (no marker)
	#	c. having any marker if an entry as '#' (empty marker) and has markers
	if indent_level_match and not success:
		for j in range(markers.size()):
			if markers[j].length() >= 1 and markers[j][0] == '~':
				success = not matched_marks.has(markers[j].substr(1))
				break
			
			if markers[j] == '':
				success = true
				break
			
			if markers[j] == '#' and not matched_marks.is_empty():
				success = true
				break
	
	if indent_level < indentation_level and indentation_level != -1:
		outside_indentation = true
	#matcher.free()
	return [success, outside_indentation]


func _parse_phase_zero(line: String) -> String:
	# Replaces translations
	var matcher: Matcher = Matcher.new(line)
	var i: int = 0
	while i < line.length():
		matcher.match_at(i, line, translation_sign, regex_token)
		if matcher.is_match:
			matcher.replace_match(tr(matcher.get_content()))
			line = matcher.line
			i = matcher.match_end
		else:
			i += 1
	
	return line


func _parse_phase_one(line: String, abr_arrays: Array, prev_indent_level: int, spotlight_str: String):
	# This function does the following things sin the following order:
	# 1. Sets indentation level and removes indentation, sends a warning if 
	# indentation is inconsistent - Done
	# 2. Remove comments
	# 3. Parse away multiline (if 'multiple_lines' is false), and set the 
	# beginning of new line (so as to remove indent)
	# 4. Removes markers and send marker_found signal if valid marker, also, 
	# send error if the mark is not at the beginning of a line but keep parsing
	# 5. Skip (don't touch) anything between an string delimitator, and
	# remove said delimitator
	# 6. Replace any abbreviations, and read from the beginning of the
	# replacement so as to also read the segment that replaced the abbreviation
	# 7. Separate and parse roles; separating normal text as consequence
	# 8. Separate and parse cues; separating normal text as consequence
	var matcher: Matcher = Matcher.new(line)
	matcher.line = line
	default_spotlight = spotlight_str
	var i: int = 0
	var is_line_start = true 
	var indent_level = 0
	var is_line_indent = true
	var parsed_line: Array = Array()
	var no_actor_in_line_yet = true
	var str_start_signs = [string_start_1, string_start_2]
	var str_end_signs = [string_end_1, string_end_2]
	while i < line.length():
		match line[i]:
			'\t':
				# POINT 1: Sets indentation level and removes indentation
				if is_line_indent:
					indent_level = _parse_indentation(matcher, i, line, indent_level, is_line_start)
					if indent_level != prev_indent_level and prev_indent_level != -1:
						emit_signal("indentation_change", prev_indent_level, indent_level)
					matcher.remove_match()
					i = matcher.match_end
					line = matcher.line
					is_line_indent = false
					i -= 1 # offset the i += 1 at 'while' end
			'#':
				# POINT 2: Remove comments
				matcher.match_at_before(i, line, comment_sign, '\n')
				if matcher.is_match:
					#matcher.replace_match('\n')
					matcher.remove_match()
					i = matcher.match_end
					line = matcher.line
					# Since comments can only end at a line break, we set is_line_indent
					# to true
					is_line_indent = true
					i -= 1 # offset the i += 1 at 'while' end
				else:
				# POINT 4: Removes markers and send marker_found signal if valid marker
					is_line_start = _parse_marker(matcher, i, line, indent_level, is_line_start)
					if matcher.is_match:
						matcher.remove_match()
						i = matcher.match_end
						line = matcher.line
						i -= 1 # offset the i += 1 at 'while' end
			'\n':
				# POINT 3: Parse multiline (Line breaks)
				matcher.match_chars(i, line, line_break)
				if not line_break_allowed:
					matcher.replace_match(' ')
					i = matcher.match_end
					line = matcher.line
				else:
					i += 1
				
				is_line_indent = true
				i -= 1 # offset the i += 1 at 'while' end
			'"', "'":
				# POINT 5: Skip anything between an string delimitator and crop signs
				matcher.match_many_at_until(i, line, str_start_signs, str_end_signs)
				if matcher.is_match:
					matcher.remove_signs()
					i = matcher.match_end
					line = matcher.line
					is_line_start = false
					i -= 1 # offset the i += 1 at 'while' end
			'/':
				# POINT 6: Replace any abbreviations
				i = _parse_abbreviation(matcher, i, line, abr_arrays)
				line = matcher.line
				is_line_start = false
				i -= 1 # offset the i += 1 at 'while' end
			':':
				# POINT 7: Separate and parse roles
				if no_actor_in_line_yet:
					matcher.set_match_at_pos(i, line, 1)
					no_actor_in_line_yet = false
					var role_str: String = matcher.get_line_before_match()
					var role_class: Role = _retrieve_and_parse_role(role_str)
					default_spotlight = str(role_class)
					abr_arrays[abr_array_spotlight_pos] = role_class.get_abr_array()
					parsed_line = _add_element_to_array(role_class, parsed_line, ROLE)
					matcher.remove_match()
					line = matcher.get_line_after_match()
					is_line_start = false
					i = 0
					i -= 1 # offset the i += 1 at 'while' end
			'[':
				# POINT 8: Separate and parse cues
				matcher.set_match_at_pos(i, line, 1)
				parsed_line = _add_element_to_array(matcher.get_line_before_match(), parsed_line, TEXT)
				var cue = parse_cue(matcher.get_line_after_match(), 0, indent_level, matcher)
				cue.source_line = matcher.original_line
#				var cue = _parse_cue(matcher, 0, matcher.get_line_after_match(), indent_level)
#				line = matcher.line
#				i = matcher.match_end
#				var args = _parse_arguments(matcher, i, line, true)
#				cue.set_arguments(args[0])
#				cue.set_options(args[1])
				
				parsed_line = _add_element_to_array(cue, parsed_line, CUE)
				line = matcher.get_line_after_match()
				is_line_start = false
				i = 0
				i -= 1 # offset the i += 1 at 'while' end
			'<':
				# POINT 9: Take out annotations and print warning
				matcher.match_at_before(i, line, annotation_sign, '\n')
				if matcher.is_match:
					l.p("Lingering annotation '" + matcher.get_match() + "' at line: " +
					matcher.original_line)
					matcher.remove_match()
					i = matcher.match_end
					line = matcher.line
					# Since annotations can only end at a line break, we set is_line_indent
					# to true
					is_line_indent = true
					i -= 1 # offset the i += 1 at 'while' end
			' ':
				pass
			_:
				is_line_start = false
		i += 1
	
	parsed_line = _add_element_to_array(line, parsed_line, TEXT)
	parsed_line.push_back(indent_level)
	return parsed_line


func _parse_indentation(matcher: Matcher, i: int, line: String, indent_level: int = -1, 
is_line_start: bool = true):
	# If the indent level is -1, that means that there is no indent set yet, so
	# we are going to set it, otherwise, we are going to check the the current
	# indentation level matches the set indent level.
	# If there's no match, that means that the indent level is 0, because of this
	# behaviour, this function should only be called at the very beginning of the line
	matcher.match_chars(i, line, indent_sign)
	#matcher.match_at(i, line, indent_sign, regex_indent)
	if not matcher.is_match:
		return indent_level
	
	if indent_level == -1 or is_line_start:
		indent_level = matcher.get_match().length()
	elif indent_level != matcher.get_match().length():
		l.g("Mismatched indentation levels in line: \n" + line + "\n\n", l.WARNING)
	
	return indent_level


func _parse_marker(matcher: Matcher, i: int, line: String, indent_level: int, 
is_line_start = true, send_signal_if_match = true):
	# The first while loop will remove any blank-space until reaching the next 
	# character, when it does, it will check to see if it is marker.
	# If it is a correct match, it will check whether or not the marker is at 
	# line_start, if it is, it will send a signal of marker found if specified to do so;
	# if it is not line start will print error. 
	# Since multiple markers can be placed next to each other, the is_line_start will only
	# be set to false if whatever is found is not a marker.
		
	matcher.match_at(i, line, marker_sign, regex_token)
	if matcher.is_match:
		if is_line_start:
			if send_signal_if_match: # and false
				emit_signal("marker_found", matcher.get_match(), indent_level)
		else:
			l.g("Marker '" + matcher.get_match() + "' is not at the start of line in line: \n" 
			+ line + "\n\n")
	else:
		is_line_start = false
	
	return is_line_start


func _parse_abbreviation(matcher: Matcher, pos: int, line: String, abr_arrays: Array) -> int:
	# If an abbreviation is found, it will proceed to iterate to al the
	# abbreviations available in abr_array, and it something match, it will 
	# replace the abbreviation and return the beginning of the match to read 
	# from there. This will ensure that whatever replaced the abr is also read.
	# if it goes all the way to the end without replacing, it will notify 
	# that the abbreviation doesn't exist and return the end of the match to 
	# keep reading from there.
	matcher.match_at(pos, line, variable_sign, regex_token)
#	if not matcher.is_match:
#		return pos
	
	var abr = matcher.get_match()
	for i in range(0, abr_arrays.size()):
		if abr in abr_arrays[i]:
			matcher.replace_match(abr_arrays[i][abr])
			return matcher.match_start
#		pos = abr_arrays[i].find([abr])
#		if pos != -1:
#			matcher.replace_match(abr_arrays[i].binary_array[pos][1])
#			return matcher.match_start
	l.g("Abbreviation for '" + abr + "' doesn't exist")
	return matcher.match_end


func _parse_role(role_string: String):
	# If retrieve_role == true, will return a Role var, otherwise will return an
	# array where [role_name, role_context] with edges already striped
	# Will separate role_name and context from the role_string. If there's no 
	# context sign, it will be considered that everything is the role_name
	var matcher: Matcher = Matcher.new(role_string)
	matcher.line = role_string
	var i: int = 0
	var role_context: String = ''
	var role_name: String = ''
	var role
	var str_start_signs = [string_start_1, string_start_2]
	var str_end_signs = [string_end_1, string_end_2]
	while i < role_string.length():
		# Skip anything between an string delimitator and crop signs
		matcher.match_many_at_until(i, role_string, str_start_signs, str_end_signs)
		if matcher.is_match:
			matcher.remove_signs()
			i = matcher.match_end
			role_string = matcher.line
			continue
		
		# Divide between role and context if context sign found
		matcher.match_at_for(i, role_string, context_sign, -1)
		if matcher.is_match:
			role_context = matcher.get_content()
			matcher.remove_match()
			break
		else:
			i += 1
	
	role_name = matcher.line.strip_edges()
	role_context = role_context.strip_edges()
	
	if role_context == '':
		role = role_name
	else:
		role = role_name + context_sign + role_context
	
	#matcher.free()
	return role


func _retrieve_and_parse_role(role_string: String):
	var role_resul = _parse_role(role_string)
	var role: Role = Roles.get_role(role_resul)
	if role == null:
		l.g("Role: '" + role_resul + "' wasn't found.")
		role = Role.new(null, role_string)
	
	return role


func parse_cue(line: String, i: int = 0, indentation_level: int = -1, matcher: Matcher = null):
	if matcher == null:
		matcher = Matcher.new(line)
		matcher.line = line
	var cue = _parse_cue(matcher, 0, matcher.get_line_after_match(), indentation_level)
	line = matcher.line
	i = matcher.match_end
	var args = _parse_arguments(matcher, i, line, true)
	cue.set_arguments(args[0])
	cue.set_options(args[1])
	
	return cue



func _parse_cue(matcher: Matcher, i: int, line: String, indentation_level: int) -> Cue:
	# return [cue: Cue, line_without_cue: String]
	# This function must recibe the cue string with or without it's enclosure
	# The role and method while be parser in the first while loop, if there still
	# some  left to parse or if the role and method are already identified, we
	# will move to parse the arguments
	matcher.is_match = false
	var role: String
	var role_string: String = ''
	var role_found: bool = false
	var method: String = ''
	var method_found: bool = false
	var cue: Cue
	var str_start_signs = [string_start_1, string_start_2]
	var str_end_signs = [string_end_1, string_end_2]
	# Parsing role and method
	while i < line.length():
		if role_found and method_found:
			break
		match line[i]:
			'-': # Parsing the role separator
				if not role_found:
					matcher.match_at_for(i, line, cue_actor_sign, 0)
					if matcher.is_match:
						role_found = true
						role_string = matcher.get_line_before_match()
						role = _parse_role(role_string)
						line = matcher.get_line_after_match()
						i = 0
						i -= 1 # offset the i += 1 at 'while' end
			':': # Parsing the method separator
				if not method_found:
#					matcher.match_at_for(i, line, cue_method_sign, 0)
#					if matcher.is_match:
					matcher.set_match_at_pos(i, line, 1)
					method_found = true
					method = matcher.get_line_before_match()
					line = matcher.get_line_after_match()
					i = 0
					break
					i -= 1 # offset the i += 1 at 'while' end
			']': # Parsing cue end
				break
			'"', "'":
				# Skip anything between an string delimitator and crop signs
				matcher.match_many_at_until(i, line, str_start_signs, str_end_signs)
				if matcher.is_match:
					matcher.remove_signs()
					i = matcher.match_end
					line = matcher.line
					i -= 1 # offset the i += 1 at 'while' end
		i += 1
	
	if not role_found:
		role = default_spotlight
	
	if not method_found:
		method = line.substr(0, i)
		line = line.substr(i)
		i = 0
	
	matcher.set_match_at_pos(i, line, 0)
	cue = Cue.new(role, _format_cue_method(method)).args([]).indent(indentation_level)
	return cue


func _parse_cue_as_text(matcher: Matcher, i: int, line: String):
	var str_start_signs = [string_start_1, string_start_2, 
	cue_arg_string_start_1, cue_arg_string_start_2]
	var str_end_signs = [string_end_1, string_end_2, 
	cue_arg_string_end_1, cue_arg_string_end_2]
	var sign_stack = 0
	var cue_start_pos = i
	while i < line.length():
		match line[i]:
			']':
				sign_stack -= 1
				if sign_stack == 0:
					i += 1
					break
			'[':
				sign_stack += 1
			'"', "'":
				# Skip anything between an string delimitator and crop signs
				matcher.match_many_at_until(i, line, str_start_signs, str_end_signs)
				if matcher.is_match:
					matcher.remove_signs()
					i = matcher.match_end
					line = matcher.line
					i -= 1 # offset the i += 1 at 'while' end
		i += 1
	
	matcher.set_match_at_pos(cue_start_pos, line, i - cue_start_pos)


func parse_arguments(line: String) -> Array:
	var matcher: Matcher = Matcher.new(line)
	return _parse_arguments(matcher, 0, line)


func _parse_arguments(matcher: Matcher, i: int, line: String, is_cue_arg: bool = false) -> Array:
	# because of some shenanigans due to using key.empty() as an indicator for options
	# parsing arguments is resilent to trying to do something like 'key ===== value' or
	# '= value' or '======value'. This is just in theory tho.
	var is_comma_separated: bool = false
	var args: Array = Array()
	var options: Dictionary = {}
	#var option_indicator = null # any int works really, what really matters is the type
	var key = ''
	var aux
	var str_start_signs = [string_start_1, string_start_2, 
	cue_arg_string_start_1, cue_arg_string_start_2]
	var str_end_signs = [string_end_1, string_end_2, 
	cue_arg_string_end_1, cue_arg_string_end_2]
	var _sub_cue: Cue 
	var sub_cue_resul: String = ''
	# Parsing the arguments
	while i < line.length():
		match line[i]:
			',':
				# Parse comma, if is_comma_separated == false, set it to true and unite
				# the previous arguments into one. 
				# If there's a key that's not empty, that means we are parsing an option,
				# and thus the option value will be the found argument
				matcher.set_match_at_pos(i, line, 1)
				if key.is_empty():
					args.append(matcher.get_line_before_match().strip_edges())
				else:
					options[key] = matcher.get_line_before_match().strip_edges()
					key = ''
				
				if not is_comma_separated:
					# Since array and dictionary are references, we don't need to return their final values
					_join_arguments(args, options)
					is_comma_separated = true
				
				line = matcher.get_line_after_match()
				i = 0
				i -= 1 # offset the i += 1 at 'while' end
			'=':
				# We parse the options. If we are NOT in comma separated mode, we just add
				# and indicator to the array that later will signal us that the positions
				# before and after the indicator, ara an option.
				# If it IS comma separated, we are just going to set the key as what was before the sign.
				matcher.set_match_at_pos(i, line, 1)
				if not is_comma_separated:
					aux = matcher.get_line_before_match()
					if aux.strip_edges() != '':
						args.append(aux)
					args.append(null) # null is the indicator that there was a '='
				elif key.is_empty():
					key = matcher.get_line_before_match().strip_edges()
				
				i = 0
				line = matcher.get_line_after_match()
				i -= 1 # offset the i += 1 at 'while' end
			']':
				if is_cue_arg:
					break
			'[':
				# Parse cues, but not into an actual cue, it keeps it just as an string
				_parse_cue_as_text(matcher, i, line)
				i = matcher.match_end
				line = matcher.line
				i -= 1 # offset the i += 1 at 'while' end
			'"', "'":
				# Skip anything between an string delimitator and crop signs
				matcher.match_many_at_until(i, line, str_start_signs, str_end_signs)
				if matcher.is_match:
					args.append(matcher.get_content())
					matcher.remove_match()
					i = matcher.match_end
					line = matcher.line
					i -= 1 # offset the i += 1 at 'while' end
			' ', '\t', '\n':
				# Parse white space, tabs or line breaks as argument separator if 
				# is_comma_separated == false. Keep the separators beacuse we will have
				# to join them back if we found a comma
				if not is_comma_separated:
					matcher.match_at_regex(i, line, regex_empty_space, regex_empty_space)
					aux = matcher.line.substr(0, matcher.match_end) # grab line before and match
					if aux.strip_edges() != '':
						args.append(aux)
				
					i = 0
					line = matcher.get_line_after_match()
					i -= 1 # offset the i += 1 at 'while' end
			'(':
				matcher.match_at_until_pair_signs(i, line, str_sub_cue_start, str_sub_cue_end)
				if matcher.is_match:
					_sub_cue = parse_cue(matcher.get_content())
					sub_cue_resul = str(Director.execute_cue(_sub_cue))
					matcher.replace_match(sub_cue_resul)
					line = sub_cue_resul + matcher.get_line_after_match()
					i = matcher.match_start
					i -= 1 # offset the i += 1 at 'while' end
		i += 1
	
	matcher.set_match_at_pos(i, line, 1)
	aux = matcher.get_line_before_match().strip_edges()
	if aux != '':
		if key != '':
			options[key] = aux
		else:
			args.append(aux)
	var resul
	if not is_comma_separated:
		resul = _format_arguments(args, options)
	else:
		resul = [args, options]
	
	return resul


func _join_arguments(array: Array, dictionary: Dictionary):
	# Since array and dictionary are references, we don't need to return their final values
	# converts the arguments array from space separated to comma separated. 
	# Example: ['zoom', null, '1.2', '1', '2'] into ['1 2'] {'zoom': '1.2'}
	var aux: String = ''
	var aux_key: String = ''
	for arg in array:
		if arg == null:
			if aux_key == '':
				aux_key = aux.strip_edges()
				aux = ''
			else:
				aux += '= '
				l.g("Ambiguos argument separation for the following args: " + str(array)
				+ ". ('Null' represents '=')")
		else:
			aux += arg
	
	array.resize(0)
	# if the argument_option_sign is found the aux_key will not be empty , that means 
	# that the arguments are an option and thus we add them to the dictionary, otherwise
	# it is all a single argument and we add it to the array
	if not aux_key.strip_edges().empty():
		dictionary[aux_key] = aux
	else:
		array.append(aux)


func _format_arguments(array: Array, dictionary: Dictionary):
	# converts the arguments array. Example: ['zoom', null, '1.2', '1', '2'] into
	# ['1', '2'] {'zoom': '1.2'}
	# used only on not comma separated arguments
	var new_arr: Array = []
	var key: String = ''
	var aux: String
	for i in range(array.size()):
		if array[i] == null:
			if key.empty():
				key = new_arr.pop_back()
		else:
			aux = array[i].strip_edges()
			if not key.empty():
				dictionary[key] = aux
				key = ''
			else: 
				new_arr.append(aux)
	
	return [new_arr, dictionary]


func _add_element_to_array(element, arr: Array, type: int) -> Array:
	if element == null:
		return arr
	
	if type == TEXT:
		element = element.strip_edges()
		# if the element is an empty text, there's no need to add it, 
		# so we end the function here
		if element.is_empty():
			return arr

	arr.append([element, type])
	return arr


func _format_cue_method(method: String) -> String:
	method = method.strip_edges()
	method = method.replace(' ', '_')
	method = method.replace('-', '_')
	
	if method_to_lowercase:
		method = method.to_lower()
	
	return method


