extends Node

const ACT_METHOD: String = "act"

var roles: Dictionary
var saveload_system
var subscribed_nodes_on_roles_cleared: Dictionary = {}

signal roles_cleared
signal manager_ready(manager)

func _ready() -> void:
	roles = {}
	emit_signal("manager_ready", self)


func request_role(node, role_str: String, refresh_role: bool = false):
	_add_role(node, role_str, refresh_role)


func connect_role(role_name: String, signal_name: String, object: Object, method: String):
	var emitter_obj = get_node_by_role(role_name)
	if emitter_obj is Object:
		if emitter_obj.has_signal(signal_name):
			var error = emitter_obj.connect(signal_name, object, method)
			l.error(error, l.CONNECTION_FAILED + 
					". Role: " + role_name + 
					". Signal: " + signal_name + 
					". Method: " + method)


func _add_role(node, role_name, allow_replace = false):
	var new_role = Role.new(node, role_name)
	if node == null:
		l.g("Null can't be asigned the role '" + str(new_role) + "'.")
	
	if role_name in roles and not allow_replace:
		if node is String:
			l.g("The group '" + node + "' can't be asigned the role '" + str(new_role) 
			+ "'. The role is already taken and replacements are not allowed.")
		else:
			l.g("'" + str(node.name) + "' can't be asigned the role '" + str(new_role) 
			+ "'. The role is already taken and replacements are not allowed.")
	else:
		roles[role_name] = new_role


func clear_roles():
	roles.clear()
	add_subscribed_nodes()
	emit_signal("roles_cleared")


func request_role_on_roles_cleared(node, role_name: String):
	subscribed_nodes_on_roles_cleared[role_name] = node


func add_subscribed_nodes():
	var node
	for role_name in subscribed_nodes_on_roles_cleared.keys():
		node = subscribed_nodes_on_roles_cleared[role_name]
		if is_instance_valid(node):
			request_role(node, role_name)


func send_cue(role_string: String, method: String, args: Array = [], 
options: Dictionary = {}):
	var cue: Cue = Cue.new(role_string, method).args(args)
	cue._options = options
	return execute_cue(cue)


func execute_cue(cue: Cue):
	if cue == null:
		return null

	return cue.execute()


func send_or_store_cue(role_string: String, method: String, args: Array = [], 
add_rollback_if_stored: bool = false):
	var cue: Cue = Cue.new(role_string, method).args(args)
	return execute_or_store_cue(cue, add_rollback_if_stored)


func execute_or_store_cue(cue: Cue, register_stored_on_console: bool = false):
	if cue == null:
		return null

	return cue.execute_or_store(register_stored_on_console)


func get_node_by_role(role: String, is_necessary: bool = true):
	if role == '':
		return Director
	
	var matched_role: Role = get_role(role, is_necessary)
	if matched_role == null:
		return null
	
	if matched_role.is_group:
		return matched_role.group_name
	else:
		return matched_role.node


func get_role(role: String, is_necessary: bool = true) -> Role:
	if role == '':
		return Role.new(Director, '')
	
		
	var matched_role: Role
	if role in roles:
		matched_role = roles[role]
	else:
		if is_necessary:
			l.g("The role '" + role + "' doesn't exist or no longer exist.")
		
		matched_role = null
		if get_tree().has_group(role):
			l.g("There's a group called '" + role + 
			"' but the role wasn't requested by the group. If the intention was to " + 
			"call said group, please make it request the role first.", l.WARNING)
	
	return matched_role


func has_role(role: String):
	return role in roles


func delete_role(role: String):
	return roles.erase(role)


func ref():
	pass # <PENDING to make with roles something similar to flagWrappers


func _on_cue_request(cue: Cue):
	#Converto to generic array, not any of the weird array types
	execute_cue(cue)


func compare_roles(a, b):
	return str(a) < str(b)


func is_equal_roles(a, b):
	return str(a) == str(b)


func _on_Jumper_jumper_ready(jumper_node) -> void:
	jumper_node.manager = self


func clone_roles():
	var cloned_roles = Dictionary()
	for role_name in roles.keys():
		cloned_roles[role_name] = roles[role_name].clone()
	
	return cloned_roles


