extends Reference

class_name Matcher

var signs_start: int
var content_start: int
var content_end: int
var signs_end: int
var line: String
var is_match: bool

var match_start: int
var match_end: int

var original_line

func _init(original_line_):
	original_line = original_line_

func set_info(line_p: String, signs_start_p: int, content_start_p: int,
content_end_p: int, signs_end_p: int, is_match_p: bool) -> void:
	signs_start = signs_start_p
	content_start = content_start_p
	content_end = content_end_p
	signs_end = signs_end_p
	line = line_p
	is_match = is_match_p
	
	match_start = signs_start_p
	match_end = signs_end_p


func get_content() -> String:
	return line.substr(content_start, content_end - content_start)

func get_match() -> String:
	return line.substr(signs_start, signs_end - signs_start)

func get_line() -> String:
	return line

func get_start_sign() -> String:
	return line.substr(signs_start, content_start - signs_start)

func get_end_sign() -> String:
	return line.substr(content_end, signs_end - content_end)

func get_line_before_match() -> String:
	return line.substr(0, signs_start)

func get_line_after_match() -> String:
	return line.substr(signs_end)

func get_line_before_content() -> String:
	return line.substr(0, content_start)

func get_line_after_content() -> String:
	return line.substr(content_end)


func remove_content():
	var new_line = get_line_before_content() + get_line_after_content()
	var new_signs_end = content_start + (signs_end - content_end)
	set_info(new_line, signs_start, content_start, content_start,
	new_signs_end, is_match)


func remove_match():
	var new_line = get_line_before_match() + get_line_after_match()
	set_info(new_line, signs_start, signs_start, signs_start, signs_start, 
	is_match)


func remove_signs():
	var cont = get_content()
	var new_end = cont.length() + signs_start
	var new_line = get_line_before_match() + cont + get_line_after_match()
	set_info(new_line, signs_start, signs_start, new_end, new_end, is_match)


func remove_line_before_match():
	var new_line = get_match() + get_line_after_match()
	set_info(new_line, 0, content_start - signs_start, content_end - signs_start, 
	signs_end - signs_start, is_match)
	


func replace_content(replace: String):
	var new_content_end = content_start + replace.length()
	var new_sign_end = new_content_end + (signs_end -  content_end)
	var new_line = get_line_before_content() + replace 
	new_line += get_line_after_content()
	set_info(new_line, signs_start, content_start, new_content_end,
	new_sign_end, is_match)


func replace_match(replace: String):
	var new_end = signs_start + replace.length()
	var new_line = get_line_before_match() + replace
	new_line += get_line_after_match()
	
	set_info(new_line, signs_start, signs_start, new_end, new_end, 
	is_match)


func set_match_at_pos(pos: int, text: String, match_len: int):
	var end: int = pos + match_len
	var text_end: int = text.length()
	if end <= text_end:
		set_info(text, pos, pos, end, end, true)
	else:
		set_info(text, pos, pos, text_end, text_end, true)


func match_chars(pos: int, text: String, char_sign: String):
	if pos >= text.length() or not text[pos] == char_sign:
		set_info(text, pos, pos, pos, pos, false)
		return 
	
	var i = pos
	
	i += 1
	while i < text.length():
		if text[i] == char_sign:
			i += 1
		else:
			break
	
	set_info(text, pos, pos, i, i, true)


func match_at_regex(pos: int, text: String, start_def: RegEx, char_def: RegEx, 
include_regex: bool = true):
	if pos >= text.length() or not _is_char_regex_match(pos, text, start_def):
		set_info(text, pos, pos, pos, pos, false)
		return 
	
	var i
	var is_regex_match: bool
	i = pos + 1
	while i < text.length():
		is_regex_match = _is_char_regex_match(i, text, char_def)
		if include_regex and not is_regex_match:
			break
		elif not include_regex and is_regex_match:
			break
		
		i += 1
	
	set_info(text, pos, pos + 1, i, i, true)


func match_at(pos: int, text: String, start_sign: String, char_def: RegEx, 
include_regex: bool = true):
	if not _is_str_match(pos, text, start_sign): # pos >= text.length() or 
		set_info(text, pos, pos, pos, pos, false)
		return 
	
	var i = pos
	var is_regex_match: bool
	i += start_sign.length()
	while i < text.length():
		is_regex_match = _is_char_regex_match(i, text, char_def)
		if include_regex and not is_regex_match:
			break
		elif not include_regex and is_regex_match:
			break
		
		i += 1
	
	set_info(text, pos, pos + start_sign.length(), i, i, true)


func match_at_before(pos: int, text: String, start_sign: String, end_sign_no_included: String):
	if not _is_str_match(pos, text, start_sign): # pos >= text.length() or 
		set_info(text, pos, pos, pos, pos, false)
		return 
	
	var i 
	var start = pos + start_sign.length()
	i = text.find(end_sign_no_included, start)
	if i == -1:
		i = text.length()
	
	set_info(text, pos, pos + start_sign.length(), i, i, true)


func match_at_until(pos: int, text: String, start_sign: String, 
end_sign: String):
	if not _is_str_match(pos, text, start_sign): # pos >= text.length() or 
		set_info(text, pos, pos, pos, pos, false)
		return 
	
	var i 
	var start = pos + start_sign.length()
	var missing_end_sign = true
	i = text.find(end_sign, start)
	if i == -1:
		i = text.length()
	else:
		missing_end_sign = false
		
	if missing_end_sign:
		l.g("Missing '" + end_sign + "' in '" + text + "' line.")
		set_info(text, pos, start, i, i, true)
	else:
		set_info(text, pos, start, i, i + end_sign.length(), true)


func match_at_until_pair_signs(pos: int, text: String, start_sign: String, 
end_sign: String):
	if not _is_str_match(pos, text, start_sign): # pos >= text.length() or 
		set_info(text, pos, pos, pos, pos, false)
		return 
	
	var start = pos + start_sign.length()
	var i = start
	var missing_end_sign = true
	var line_length = text.length()
	var sign_pile = 1
	
	while i < line_length: 
		if _is_str_match(i, text, start_sign):
			sign_pile += 1
			i += start_sign.length()
			continue

		if _is_str_match(i, text, end_sign):
			sign_pile -= 1
			if sign_pile == 0:
				missing_end_sign = false
				break
			else:
				i += end_sign.length()
			continue
		
		i += 1
	
	if i == -1:
		i = text.length()
	else:
		missing_end_sign = false
		
	if missing_end_sign:
		l.g("Missing '" + end_sign + "' in '" + text + "' line.")
		set_info(text, pos, start, i, i, true)
	else:
		set_info(text, pos, start, i, i + end_sign.length(), true)


func match_many_at_until(pos: int, text: String, start_signs: Array, 
end_signs: Array):
	var limit = start_signs.size()
	if limit != end_signs.size():
		l.g("Mismatched number of end and start signs at 'match_many_at_until' in Matcher.")
		if end_signs.size() < limit:
			limit = end_signs.size()
	
	is_match = false
	for i in range(limit):
		match_at_until(pos, text, start_signs[i], end_signs[i])
		if is_match:
			break


func match_at_for(pos: int, text: String, start_sign: String, for_num: int):
	# If for_num is -1, it will match until the end of the string
	if not _is_str_match(pos, text, start_sign): # pos >= text.length() or 
		set_info(text, pos, pos, pos, pos, false)
		return 
	
	var start = pos + start_sign.length()
	var end 
	if for_num == 0:
		end = start
	elif for_num <= -1:
		end = text.length() 
	else:
		end = start + for_num
		if end >= text.length():
			end = text.length() - 1
			l.g("In parser, 'match_at_for' function, the requested for_num" +
			"exceeds text character count", l.WARNING)
	
	set_info(text, pos, start, end, end, true)


func _is_char_regex_match(pos: int, text: String, regex: RegEx):
	return regex.search(text[pos]) != null


func _is_str_match(pos: int, text: String, match_str: String):
	return match_str == text.substr(pos, match_str.length())
# the above function is more consistent on failed matches, if the strin is too long,
# it can be as much as 50% faster, in any other case it's just 10% slower
#		var _is_match = false
#		var resul_pos: int = text.find(match_str, pos)
#		_is_match = resul_pos == pos
#
#		return _is_match

