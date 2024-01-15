tool
extends Node

class_name Manager

const SPAWNED_NODE_SYMBOL = '#'
const UNIQUE_ENTRY_SYMBOL = '*'
const KEY_PATH_DIVIDE_SYMBOL = '='
const ACT_METHOD = 'act'
export var manager_name: String = ''
var add_hashtag_to_name: bool = false
var registered_nodes: String = '' setget _refresh_available_node_types
var spawn_node: bool = false setget _spawn_node
var selected_node: String = ''
var catalog: Dictionary # the key corresponds to the type, the value is [resource_path, unique_bool]
var nodes_tickets: Dictionary = {} # {node_reference: ticket_node}
var spawned_nodes_types: Dictionary = {} # {node_reference: type}
var locker_name = ''
var nodes_holder_path: NodePath = ''
var nodes_holder = self

func _ready() -> void:
	var aux_node
	if not nodes_holder_path.is_empty():
		aux_node = get_node_or_null(nodes_holder_path)
		if is_instance_valid(aux_node):
			nodes_holder = aux_node
	
	_parse_entries()
	if not Engine.is_editor_hint():
		if manager_name != '':
			Director.request_role(self, manager_name)


func act(cue: Cue):
	var path_method: Array = cue.method.rsplit('/', false, 1)
	var target
	var path = path_method[0].strip_edges()
	var method
	# if the method does have two arguments and the requested node is not ''.
	# there's no need to check if the requested node is empty since the method
	# already comes with striped edges and the split does not allow empty
	if path_method.size() == 2 and path != '':
		target = _get_target(path, cue)
		if target == null:
			return
	else:
		l.g("No target node specified for manager's act function in cue: " + str(cue))
		return
	
	method = path_method[1].strip_edges()
	_send_cue_to_target(target, cue, method)


func _get_target(target_path: String, cue: Cue):
	var target = get_node_or_null(target_path)
	if target == null:
		l.g("Target node specified in manager's act function in cue: " + str(cue) + 
		" does not exists")
	
	return target


func _send_cue_to_target(target: Node, cue: Cue, method: String):
	var ticket = nodes_tickets.get(target)
	if ticket == null:
		if target.has_method(method):
			target.call(method, cue)
		elif target.has_method(ACT_METHOD):
			target.call(ACT_METHOD, cue)
	else:
		ticket.send_cue(cue, method)


func _batch_send_disassembled_cues_to_target(target: Node, disassembled_cues: Array):
	var ticket = nodes_tickets.get(target)
	var cue
	for disassembled_cue in disassembled_cues:
		cue = Director.assemble_cue(disassembled_cue)
		if ticket == null:
			if target.has_method(cue.method):
				target.call(cue.method, cue)
			elif target.has_method(ACT_METHOD):
				target.call(ACT_METHOD, cue)
		else:
			ticket.send_cue(cue, cue.method)


func _parse_entries():
	# Example:
	# *Foo = res://Test/Foo.gd  		-> unique
	# * Foo2 = res://Test/Foo2.gd 	-> unique
	#  *  Foo3 = res://Test/Foo3.gd 	-> unique
	# Bar = res://Test/Bar.gd  		-> not unique

	var raw_entries: Array = registered_nodes.split('\n', false)
	var split_entry: Array
	var is_unique: bool = false
	var key: String
	var path: String
	for raw_entry in raw_entries:
		raw_entry = raw_entry.strip_edges()
		if raw_entry[0] == UNIQUE_ENTRY_SYMBOL:
			is_unique = true
			raw_entry = raw_entry.substr(1)
		else:
			is_unique = false
		
		split_entry = raw_entry.split(KEY_PATH_DIVIDE_SYMBOL, false, 1)
		if split_entry.size() == 2:
			key = split_entry[0].strip_edges()
			path = split_entry[1].strip_edges()
			catalog[key] = [path, is_unique]
		else:
			l.g("Discarded entry name of info'" + raw_entry  + "' at '" + name + "': "+ get_path())


func add(cue: Cue):
	# [name_id: String, spawned_node_name]
	# {cues: disassembled_cues_array}
	l.start_measure()
	var type_id: String = cue.get_at(0, '').strip_edges()
	var spawned_node_name: String = cue.get_at(1, '', false).strip_edges()
	var disassembled_cues: Array = cue.get_array_option('cues', [])
	if type_id == '':
		return
	
	var new_node = _create_instance(type_id)
	l.write_measure("initializing actor '" +  type_id + "' at '" + name + "'.")
	
	if new_node == null:
		return 
	
	if spawned_node_name != '':
		# check that the suggested name of the spawned node has '#' as the first character
		if add_hashtag_to_name and spawned_node_name[0] != SPAWNED_NODE_SYMBOL:
			l.g("The suggested name of spawned node type '" + type_id  + "' at '" + name + "' "
			+ "does not contains '#' as first character, this could lead to conflict with " +
			"non-spawned nodes", l.WARNING)
			
		new_node.name = spawned_node_name
		# check that the node was added with the respective spawned_node_name
		if new_node.name != spawned_node_name:
			l.g("The suggested name of spawned node type '" + type_id  + "' at '" + name + "' is "
			+ "in conflict with another node of the same name, renaming it to: " + new_node.name)
	
	#managed_nodes[new_node.name] = [new_node, type_id]
	spawned_nodes_types[new_node] = type_id
	_batch_send_disassembled_cues_to_target(new_node, disassembled_cues)


func set_cues(cue: Cue):
	# [node_name: String
	# {cues: disassembled_cues_array}
	var target = _get_target(cue.get_at(0, ''), cue)
	var disassembled_cues = cue.get_array_option('cues', [])
	if target != null:
		_batch_send_disassembled_cues_to_target(target, disassembled_cues)
		


func _register_management_ticket(ticket: Node, ticket_owner: Node):
	nodes_tickets[ticket_owner] = ticket


func _spawn_node(value):
	if value:
		_create_instance(selected_node)


func _refresh_available_node_types(_value):
	registered_nodes = _value
	_parse_entries()


func _create_instance(key: String):
	var entry = catalog.get(key)
	if entry == null:
		l.g("Entry '" + key + "' does not exists in manager '" + manager_name + "'.")
		return null
	
	# here we check if the node is unique and if we already have one
	if entry[1] and _node_exists(entry[0]):
		return null
	
	var res_path: String = entry[0]
	var node_name: String = res_path.substr(res_path.rfind('/') + 1)
	node_name = node_name.substr(0, node_name.rfind('.'))
	if not Engine.is_editor_hint() and add_hashtag_to_name:
		node_name = '#' + node_name
	var new_node = load(res_path).instance()
	nodes_holder.add_child(new_node)
	new_node.set_owner(self)
	new_node.name = node_name
	return new_node


func _node_exists(target_filename: String) -> bool:
	var exist: bool = false
	var f
	for child in nodes_holder.get_children():
		f = child.filename
		if f == target_filename:
			exist = true
			break
	
	return exist


func _save_cues(is_game_save):
	# add_save_cue(locker_name: String, role_string: String, method: String, args: Array = [])
	if manager_name == '':
		return
	
	var locker
	var options
	var type
	var ticket
	var finished_nodes: Dictionary = {}
	if locker_name == '':
		locker = owner.name
	else:
		locker = locker_name
	# not all spawned nodes may have a ticket, and not all nodes with ticket may be spawned
	# so we need to check in those to groups
	for node in spawned_nodes_types.keys():
		type = spawned_nodes_types.get(node)
		ticket = nodes_tickets.get(node)
		options = _get_disassembled_cues(ticket, is_game_save)
		Director.add_save_cue(locker, manager_name, 'add', [type, node.name], options)
		finished_nodes[node] = true
		
	for node in nodes_tickets.keys():
		if node in finished_nodes:
			continue
		ticket = nodes_tickets.get(node)
		options = _get_disassembled_cues(ticket, is_game_save)
		Director.add_save_cue(locker, manager_name, 'set_cues', [node.name], options)


func _get_disassembled_cues(ticket, is_game_save):
	# if ticket == null or no _get_save_cues_method, return {}
	if ticket == null:
		return {}
	else:
		return {'cues': ticket._get_disassembled_cues(is_game_save)}


func _get_property_list():
	var properties = []
	var available_exp: String = ''
	_parse_entries()
	for key in catalog.keys():
		available_exp += key + ',' 
	
	if available_exp.length() > 0:
		available_exp = available_exp.substr(0, available_exp.length() - 1)
	
	properties.append({
		name = "selected_node",
		"hint": PROPERTY_HINT_ENUM, 
		"hint_string": available_exp,
		type = TYPE_STRING
	})
	properties.append({
		name = "spawn_node",
		type = TYPE_BOOL
	})
	properties.append({
		name = "registered_nodes",
		"hint": PROPERTY_HINT_MULTILINE_TEXT,
		type = TYPE_STRING
	})
	properties.append({
		name = "add_hashtag_to_name",
		type = TYPE_BOOL
	})
	
	return properties

