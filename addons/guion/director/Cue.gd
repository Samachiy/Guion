extends Reference
class_name Cue

const context_sign: String = '@'
const ACT_METHOD: String = "act"
const TRUE = true
const FALSE = false

var role: String
var method: String
var _arguments: Array = []
var _options: Dictionary = {}
var indentation: int = -1
#var size: int setget , args_size
var requires_rollback = false
var source_line : String = ''
var metadata: String = ''
var reader = null
var director = Director
var roles = Roles

var version: Array = [-1, -1, -1] # major, mino, patch respectivelly -1 means current ver

func _init(role_name: String, method_name: String) -> void:
	role = role_name
	method = method_name
	version = director.get_current_version_array()


func opts(options_dict: Dictionary) -> Cue:
	_options = options_dict
	return self


func args(arguments_array: Array) -> Cue:
	_arguments = arguments_array
	return self


func get_args():
	return _arguments


func get_opts():
	return _options


func indent(indentation_level) -> Cue:
	indentation = indentation_level
	return self


func get_indent():
	return indentation


func get_option(key: String, null_value):
	if _options.has(key):
		return _options[key]
	else:
		return null_value

func int_option(key: String, null_value):
	return int(get_option(key, null_value))

func str_option(key: String, null_value):
	return str(get_option(key, null_value))

func bool_option(key: String, null_value):
	var resul = get_option(key, null_value)
	match resul:
		TRUE:
			resul = true
		FALSE:
			resul = false
		null_value:
			pass
		_:
			l.g("Cue: " + _to_string() + " has an undefined bool option at key: " + key,
			l.WARNING)
			resul = bool(resul)
	return resul

func float_option(key: String, null_value):
	return float(get_option(key, null_value))

func vec2_option(key1: String, key2: String, null_value1, null_value2):
	return Vector2(get_option(key1, null_value1), get_option(key2, null_value2))

func array_option(key: String, null_value) -> Array:
	var resul = get_option(key, null_value)
	if resul is Array:
		return resul
	else:
		return [resul]


func object_option(key: String, null_value = null) -> Object:
	var resul = get_option(key, null_value)
	if resul is Object:
		return resul
	else:
		return null_value


func get_at(index: int, null_value = null, necessary: bool = true):
	# will Get the value at index in a safe way, printing errors if marked as a
	# necessary get and returning the specified null value if the index doesn't 
	# exist
	var resul
	var abs_index: int
	if index < 0:
		abs_index = _arguments.size() + index
	else:
		abs_index = index
	
	if abs_index >= 0 and abs_index < _arguments.size():
		resul = _arguments[abs_index]
	else:
		resul = null_value
		if necessary:
			var error = "Index '" + str(index) + "' doesn't exist in cue, "
			error += "argument array of size " + str(_arguments.size()) + " in cue: "
			error += _to_string()
			l.g(error)
	
	return resul


func int_at(index: int, null_value = -1, necessary = true) -> int:
	return int(get_at(index, null_value, necessary))

func float_at(index: int, null_value = -1.0, necessary = true) -> float:
	return float(get_at(index, null_value, necessary))

func bool_at(index: int, null_value = false, necessary = true) -> bool:
	var resul = get_at(index, null_value, necessary)
	if resul is bool:
		return resul
	match resul:
		TRUE:
			resul = true
		FALSE:
			resul = false
		null_value:
			pass
		_:
			l.g("Cue: " + _to_string() + " has an undefined bool value of '" + str(resul) + 
			"' at index: " + str(index),
			l.WARNING)
			resul = bool(resul)
	return resul

func array_at(index: int, null_value = [], necessary = true) -> Array:
	var resul = get_at(index, null_value, necessary)
	if resul is Array:
		return resul
	else:
		return [resul]

func str_at(index: int, null_value = '', necessary = true) -> String:
	return str(get_at(index, null_value, necessary))


func object_at(index: int, null_value = null, necessary = true) -> Object:
	var resul = get_at(index, null_value, necessary)
	if resul is Object:
		return resul
	else:
		return null_value


func args_slice(begin: int, end_included: int):
	return _arguments.slice(begin, end_included)


func size() -> int:
	return _arguments.size()


func add_arg(argument):
	_arguments.append(argument)
	return self


func add_opt(key: String, value):
	_options[key] = value
	return self


func _to_string() -> String:
	var info: String = ""
	var has_method_separator = false
	info += "[" + str(role) + " - " + method
	for i in range(_arguments.size()):
		has_method_separator = true
		if i == 0:
			info += ': '
		else:
			info += ', '
		
		info += str(_arguments[i])
	
	var keys = _options.keys()
	for i in range(keys.size()):
		if i == 0 and not has_method_separator:
			info += ': '
		else:
			info += ', '
		
		info += str(keys[i]) + ' = ' + str(_options[keys[i]])
	
	info += "]"
	return info


func get_info() -> String:
	var info: String = ""
	info += "\nRole: " + str(role) + "\nMethod: " + method + ":\n"
	for i in range(_arguments.size()):
		info += "\t" + str(i) + ": " + str(_arguments[i]) + "\n"
	return info


func clone() -> Cue:
	var cue_clone = get_script().new(role, method)
	#cue_clone.role = role
	#cue_clone.method = method
	cue_clone._arguments = _arguments.duplicate(true)
	cue_clone.indentation = indentation
	cue_clone._options = _options.duplicate(true)
	cue_clone.requires_rollback = requires_rollback
	return cue_clone


func disassemble() -> Array:
	var resul: Array = []
	resul.push_back(version)
	resul.push_back(requires_rollback)
	resul.push_back(_options)
	resul.push_back(indentation)
	resul.push_back(_arguments)
	resul.push_back(method)
	resul.push_back(role)
	return resul


func assemble(disassembled_cue: Array) -> Cue:
	if disassembled_cue.empty():
		l.g("disassembled cue is emtpy at:" + str(get_stack()))
	var cue = get_script().new(
		disassembled_cue.pop_back(), # role
		disassembled_cue.pop_back()) # method
	
	cue.args(disassembled_cue.pop_back()) # args
	cue.indent(disassembled_cue.pop_back()) # indentation_level
	cue.opts(disassembled_cue.pop_back()) # options
	cue.requires_rollback = disassembled_cue.pop_back() # requires_rollback
	cue.version = disassembled_cue.pop_back()
	return cue


static func check_if_disassembled_cue(disassembled_cue: Array) -> bool:
	if disassembled_cue != null and disassembled_cue.size() == 7:
		return true
	else:
		return false


func set_reader(reader_: Node):
	reader = reader_
	return self


func get_reader():
	if reader == null:
		return director.reader
	else:
		return reader


# Parsing functions: This are a direct copy of those in parser


func format_method(raw_method: String):
	raw_method = raw_method.strip_edges()
	raw_method = raw_method.replace(' ', '_')
	raw_method = raw_method.replace('-', '_')
	raw_method = raw_method.to_lower()
	return raw_method


func format_role(role_string: String):
	# If retrieve_role == true, will return a Role var, otherwise will return an
	# array where [role_name, role_context] with edges already striped
	# Will separate role_name and context from the role_string. If there's no 
	# context sign, it will be considered that everything is the role_name
	
	var string_start_1: String = '"""'
	var string_end_1: String = '"""'
	var string_start_2: String = "'''"
	var string_end_2: String = "'''"
	var matcher: Matcher = Matcher.new(role_string)
	matcher.line = role_string
	var i: int = 0
	var role_context: String = ''
	var role_name: String = ''
	var role_resul
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
		role_resul = role_name
	else:
		role_resul = role_name + context_sign + role_context
		
	return role_resul


# FUNCTIONS TO EXECUTE THE CUE


func execute(log_missing_role: bool = true):
	var node
	var resul
	node = roles.get_node_by_role(role, log_missing_role)
	if node == null:
		if log_missing_role:
			l.g("The role for cue '" + str(self) + "' doesn't exist.")
		resul = null
	elif node is Node:
		resul = execute_in_node(node)
	elif director.get_tree().has_group(node):
		resul = execute_in_group(node)
	
	return resul


func execute_or_store(register_stored_on_console: bool = false):
	var node
	var stored = false
	var resul
	node = director.get_node_by_role(role, false)
	if node == null:
		if requires_rollback:
			stored = director._push_mail_cue(self)
		else:
			stored = director.store_cue(role, self, director.saveload.MAIL_CUE_LABEL)
		
		if stored and register_stored_on_console:
			director.console.append_text(": " + "stored cue")
		
		if not stored:
			l.g("Neither the role or locker for cue '" + str(self) + "' exist.")
		
		resul = null
	elif node is Node:
		resul = execute_in_node(node)
	elif director.get_tree().has_group(node):
		resul = execute_in_group(node)
	
	return resul


func execute_in_node(node: Node):
	var resul = null
	if method == '':
		if node.has_method(ACT_METHOD):
			resul = node.call(ACT_METHOD, self)
		else:
			l.g("Couldn't execute methodless cue '" + str(self) + 
			"'. No act method in node: " + str(node.get_path()))
	elif node.has_method(method):
		resul = node.call(method, self)
	elif node.has_method(ACT_METHOD):
		resul = node.call(ACT_METHOD, self)
	else:
		l.g("Couldn't execute cue '" + str(self) + 
		"'. Non-existent method in node: " + str(node.get_path()) + ". Metadata: " + metadata)
	
	return resul


func execute_in_group(group: String):
	var tree = director.get_tree()
	var results: Dictionary = {}
	var clone_cue: Cue
	for node in tree.get_nodes_in_group(group):
		clone_cue = clone()
		results[node.get_path()] = clone_cue.execute_in_node(node)
	
	return results



func evaluate(act_method_is_valid: bool = false):
	var node
	var is_valid = false
	node = roles.get_node_by_role(role)
	if node != null:
		if node is Node:
			is_valid = evaluate_in_node(node)
#	elif director.get_tree().has_group(node):
#		resul = execute_in_group(node)
	
	return is_valid


func evaluate_in_node(node: Node, act_method_is_valid: bool = false):
	var is_valid = false
	if method == '':
		if act_method_is_valid and node.has_method(ACT_METHOD):
			is_valid = true
	elif node.has_method(method):
		is_valid = true
	elif act_method_is_valid and node.has_method(ACT_METHOD):
		is_valid = true
	
	return is_valid

# VERSION MANAGEMENT FUNCTIONS


#func fill_version(major_ver: int, minor_ver: int, patch_ver: int):
#	# this functions will onl be used if the version is empty (aka equal to -1)
#	if _major_version == -1:
#		_major_version == major_ver
#	if _minor_version == -1:
#		_minor_version == minor_ver
#	if _patch_version == -1:
#		_patch_version == patch_ver


func is_version_array(version: Array) -> bool:
	if _compare_version_to_array(version) == 0:
		return true
	else:
		return false


func is_version_higher_than_array(version: Array) -> bool:
	if _compare_version_to_array(version) == 1:
		return true
	else:
		return false


func is_version_lower_than_array(version: Array) -> bool:
	if _compare_version_to_array(version) == -1:
		return true
	else:
		return false


func is_version(major_ver: int, minor_ver: int, patch_ver: int) -> bool:
	if _compare_version_to(major_ver, minor_ver, patch_ver) == 0:
		return true
	else:
		return false


func is_version_higher_than(major_ver: int, minor_ver: int, patch_ver: int) -> bool:
	if _compare_version_to(major_ver, minor_ver, patch_ver) == 1:
		return true
	else:
		return false


func is_version_lower_than(major_ver: int, minor_ver: int, patch_ver: int) -> bool:
	if _compare_version_to(major_ver, minor_ver, patch_ver) == -1:
		return true
	else:
		return false


func _format_version_array(version: Array, defaul_num: int = 0) -> Array:
	var ver_array = version.duplicate()
	var formated_ver_array: Array = []
	
	# major num
	var num = ver_array.pop_front()
	if num is int:
		formated_ver_array.append(num)
	else:
		formated_ver_array.append(defaul_num)
		
	# minor num
	num = ver_array.pop_front()
	if num is int:
		formated_ver_array.append(num)
	else:
		formated_ver_array.append(defaul_num)
		
	# patch num
	num = ver_array.pop_front()
	if num is int:
		formated_ver_array.append(num)
	else:
		formated_ver_array.append(defaul_num)
	
	return formated_ver_array


func _compare_version_to_array(version: Array):
	var ver_array = version.duplicate()
	var formated_ver_array: Array = _format_version_array(version)
	return _compare_version_to(
			formated_ver_array[0], 
			formated_ver_array[1], 
			formated_ver_array[2])


func _compare_version_to(major_ver: int, minor_ver: int, patch_ver: int) -> int:
	var resul # -1 cue ver is less than, 0 cue ver is the same, 1 cue ver is higher than
	var cue_major_ver = get_major_version()
	var cue_minor_ver = get_minor_version()
	var cue_patch_ver = get_patch_version()
	resul = cue_major_ver - major_ver
	if resul == 0:
		resul = cue_minor_ver - minor_ver
		if resul == 0:
			resul = cue_patch_ver - patch_ver
	
	if resul < 0:
		return -1
	elif resul == 0:
		return 0
	else:
		return 1


func get_version_array() ->Array:
	return [get_major_version(), get_minor_version(), get_patch_version()]


func get_major_version() -> int:
	var major_version = version[0]
	if major_version == -1:
		return director.major_version
	else:
		return major_version

func get_minor_version() -> int:
	var minor_version = version[1]
	if minor_version == -1:
		return director.minor_version
	else:
		return minor_version

func get_patch_version() -> int:
	var patch_version = version[2]
	if patch_version == -1:
		return director.patch_version
	else:
		return patch_version

