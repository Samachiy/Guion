extends Node

export var text_directory: String = "res://Text/"
export var text_extension: String = ".vns"

var text_folder: String
var file_name: String
var dialog_separator: String
var file_path: String
var text_file: File = File.new()
var line_num: int = 0
var cursor: int = 0
var next_line_buffer: String = ''
var base: BaseFile = BaseFile.new()


func seek(line_number: int, file_cursor: int = -1):
	if file_cursor == -1:
		text_file.seek(0)
		line_num = line_number
		for _i in range(line_number):
# warning-ignore:return_value_discarded
			text_file.get_line()
	else:
		cursor = file_cursor
		line_num = line_number
		text_file.seek(file_cursor)


func get_next_raw_line():
	var text = text_file.get_line()
	line_num += 1
	cursor = text_file.get_position()
	return text


func get_next_dialog_line() -> String:
	var current_line: String = ""
	var line_to_append: String
	current_line += next_line_buffer
	next_line_buffer = ""
	while current_line.strip_edges() == "" or not dialog_separator in current_line:
		if eof_reached():
			#emit_signal("eof_reached")
			break
		
		# this block is to prevent tabs or spaces to be considered as not empty lines
		line_to_append = get_next_raw_line() + "\n"
		if line_to_append.strip_edges() == '':
			line_to_append = "\n"
		
		current_line += line_to_append
	
	var pos_ini = current_line.find(dialog_separator)
	if pos_ini != -1:
		var pos_end = pos_ini + dialog_separator.length()
		next_line_buffer = current_line.substr(pos_end)
		current_line = current_line.substr(0, pos_ini)
			
	return current_line


func get_reference_array() -> Array:
	return [file_path, line_num]


func get_current_line_reference_array() -> Array:
	return [file_path, max(line_num - 1, 0)]


func load_file(args: Array):
	# [file_path: String, line_number: int, cursor: int]
	return open(args[0], args[1])


func open(file: String, line_number: int = -1, file_cursor: int = -1) -> bool:
	var file_info = _extract_file_name_from_path(file)
	var success: bool = false
	var skip_creating_new_base: bool  = false
	if base.is_open and file_path == file_info[1]: # if trying to open an already open file
		if line_number == -1 and file_cursor == -1:  
			# If no jump was attempted, will simplyreturn success = true, so no need to do anything
			return true
		elif OS.is_debug_build():
			# if debug built and jump was attempted, will reload the file again to take advantage 
			# of live editing features
			skip_creating_new_base = true
		else:
			# If jump was attempted, will perform the jump and return success = true
			seek(line_number) 
			return true
	
	_close()
	__save_sublime_text()
	file_name = file_info[0]
	file_path = file_info[1]
	
	var err = text_file.open(file_path, File.READ)
	if err != OK:
		text_file.close()
		l.g("Could not open file: '" + file + "', path '" + file_path) # + "'. Error code " + str(err))
		file_name = ''
		file_path = ''
		success = false
	else:
		if not skip_creating_new_base:
			base = BaseFile.new()
		base.set_open(file_name)
		seek(line_number, file_cursor)
		success = true
	
	return success


func __save_sublime_text():
	if OS.is_debug_build():
# warning-ignore:return_value_discarded
		OS.execute('/usr/bin/subl', ["-b", "--command", "save_all_existing_files"])



func _extract_file_name_from_path(path: String) -> Array: 
	# Returns [file_name, file_path]
	# If the path correspond to the general directory of texts specified in 
	# text_dir, it will return the name without the extension and directory
	# otherwise, it will return the full path without changes as name and
	# will add the missing text_dir and extension and return as path.
	# This is done this way since the file_name works as an id to locate the 
	# right file when skipping, allowing the text_dir and/or the file itself
	# to be moved without damaging the skip registry
	
	# Taking out the general directory
	var pos = path.find(text_folder)
	var resul_name: String
	var resul_path: String
	if pos == -1: # if no general directory in path
		resul_path = text_folder + path
		resul_name = path
	else:
		resul_path = path
		resul_name = path.substr(pos + text_folder.length())
		pos = resul_name.find('/')
		resul_name = resul_name.substr(pos + 1)
	
	# Taking out the extension
	var ext_pos = resul_name.find(text_extension)
	if ext_pos == -1: # if no extension in path
		resul_path += text_extension
	else:
		resul_name = resul_name.substr(0, ext_pos)

	return [resul_name, resul_path]


func _close():
	if base.is_open:
		base.set_close()
		text_file.close()


func eof_reached():
	if base.is_open:
		return text_file.eof_reached()
	else:
		return true









