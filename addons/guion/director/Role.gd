extends Reference
class_name Role

const context_separator: String = '@'

var role: String
var context: String
var node: Node = null
var group_name: String = ''
var is_group: bool
var _context_sign: String


func _init(node_ref, role_name: String, 
role_context: String = '', context_sign: String = context_separator) -> void:
	role = role_name.strip_edges()
	context = role_context.strip_edges()
	_context_sign = context_sign
	if node_ref is Node or node_ref == null:
		node = node_ref
		is_group = false
	elif node_ref is String:
		group_name = node_ref
		is_group = true
	else:
		group_name = str(node_ref)
		is_group = true
		l.g("Role reference is not a Node nor a group name, forcing convertion to string." + 
		" Role reference: " + group_name)


func _to_string() -> String:
	var resul = role
	if context != '':
		role += context_separator + context
		
	return resul


func get_abr_array() -> Array:
	if node != null and "abr_array" in node:
		return node.abr_array
	else:
		return []


func clone():
	var role_clone = get_script().new(node, role, context)
	return role_clone
