extends Node

var dialog_separator: String
var text_array: Array
var line_num: int = 0
var base: BaseFile = BaseFile.new()


func seek(line_number: int):
	line_num = line_number


func get_next_raw_line() -> String:
	var line = text_array[line_num][0]
	line_num += 1
	return line


func get_next_dialog_line() -> String:
	var line = ''
	var aux_num = text_array[line_num][1]
	while !eof_reached() and aux_num == text_array[line_num][1]:
		line += get_next_raw_line() + "\n"
	
	return line


func get_reference_array() -> Array:
	return [text_array, line_num]


func get_current_line_reference_array() -> Array:
	return [text_array, max(line_num - 1, 0)]


func load_file(args: Array):
	# [text_array: Array, line_number: int]
	text_array = args[0]
	line_num = args[1]
	return true


func open(text_to_read: String, id: String = '', line_number: int = 0) -> bool:
	if text_to_read.strip_edges() == "":
		return false
	
	base =  BaseFile.new()
	base.set_open(id)
	line_num = line_number
	text_array = _process_text_to_array(text_to_read)
	#print_text()
	return true


func _process_text_to_array(text_to_process):
	var temp_array
	var resul_array = Array()
	var dialog_line_counter = 0
	var new_line: bool = false
	temp_array = text_to_process.split('\n') 
	
	for i in range(temp_array.size()):
		var aux = temp_array[i].strip_edges()
		
		if aux == '' and not new_line:
			# if the line is empty, then that means the next line that DO have text,
			# will be considered a new line
			new_line = true
		elif new_line:
			# if we are in new line, a the current line does have text, we move the counter
			dialog_line_counter += 1
			new_line = false
		
		resul_array.append([temp_array[i], dialog_line_counter])
	
	return resul_array


func _old_process_text_to_array(text_to_process):
	var temp_array
	var resul_array = Array()
	temp_array = text_to_process.split(dialog_separator) # dialog
	# Since we need to iterate each line separated by an \n, and the dialog_separator
	# can be something else, we are going to create an array with the line separated
	# by an \n and next to it, the line number according to the dialog_separator.
	for i in range(temp_array.size()):
		var aux = temp_array[i].split('\n')
		for j in range(aux.size()):
			resul_array.append([aux[j], i])
	
	return resul_array


func eof_reached():
	if line_num >= text_array.size():
		return true
	else:
		return false


func get_raw_text() -> String:
	var raw_text: String = ''
	for i in range(0, text_array.size()):
		raw_text += str(text_array[i]) + "\n"
	
	return raw_text


func print_text():
	for i in range(0, text_array.size()):
		l.p(str(i) + ": " + str(text_array[i]))
