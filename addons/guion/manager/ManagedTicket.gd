tool
extends Node

enum holders{
	OWNER,
	PARENT,
}

export(NodePath) var save_cues_node_path: NodePath
export(NodePath) var act_node_path: NodePath
export(NodePath) var other_methods_node_path: NodePath # this is the same as '' so == '' will return true
export(holders) var ticket_holder = holders.PARENT
export(holders) var ticket_holder_manager = holders.PARENT

var save_cues_node = null
var act_node = null
var other_methods_node = null
var ticket_holder_node
var manager
var spawn_name: String = ''
var registered: bool = false

func _on_ManagedTicket_tree_entered():
	if Engine.is_editor_hint() or registered:
		return
	
	# we first check if all exports are empty or not so we can use the defaul node or custom nodes
	if not save_cues_node_path.is_empty():
		act_node = get_node_or_null(save_cues_node_path)
	if not act_node_path.is_empty():
		act_node = get_node_or_null(act_node_path)
	if not other_methods_node_path.is_empty():
		other_methods_node = get_node_or_null(other_methods_node_path)
	
	# We now get the default holder node
	match ticket_holder:
		holders.OWNER:
			ticket_holder_node = owner
			if ticket_holder_node == null:
				l.g("Failed to set up manager ticket due to lack of owner in node at: " 
				+ str(get_path()))
				return
		holders.PARENT:
			ticket_holder_node = get_parent()
			if ticket_holder_node == null:
				l.g("Failed to set up manager ticket due to lack of parent in node at: " 
				+ str(get_path()))
				return
	
	# We set nodes that are null with the default holder node and check if we are gonna use a  
	# custom arrangement
	if save_cues_node == null:
		save_cues_node = ticket_holder_node
	if act_node == null:
		act_node = ticket_holder_node
	if other_methods_node == null:
		other_methods_node = ticket_holder_node
	
	# We attempt to get the manager
	if ticket_holder == null:
		l.g("Failed to set up manager ticket due to null ticket holder in node at: " + str(get_path()))
		return
	else:
		set_manager(ticket_holder_node)
		if manager == null:
			l.g("Failed to set up manager ticket due to lack of ticket_holder's manager at: " + 
			str(get_path()))
			return
		elif not manager.has_method("_register_management_ticket"):
			l.g("Failed to set up manager ticket, retrieved node is not a management node, " + 
			"in node at: " + str(get_path()))
			return

	manager._register_management_ticket(self, ticket_holder_node)
	registered = true


func set_manager(ticket_holder_node: Node):
	match ticket_holder_manager:
		holders.OWNER:
			manager = ticket_holder_node.owner
			if manager == null:
				l.g("Failed to set up manager due to lack of owner in node at: " 
				+ str(ticket_holder_node.get_path()))
				return
		holders.PARENT:
			manager = ticket_holder_node.get_parent()
			if manager == null:
				l.g("Failed to set up manager due to lack of parent in node at: " 
				+ str(ticket_holder_node.get_path()))
				return



func _get_disassembled_cues(is_game_save):
	var cues: Array = []
	var disassembled_cues: Array = []
	if save_cues_node.has_method("_get_managed_save_cues"):
		cues = save_cues_node._get_managed_save_cues(is_game_save)
	else:
		l.g("Node with manager ticket does not have the function '_get_managed_save_cues', this node's " + 
			"data won't be saved. Node at: " + str(get_path()), l.WARNING)
	
	for cue in cues:
		disassembled_cues.append(cue.disassemble())
	
	return disassembled_cues


func send_cue(cue: Cue, method):
	if other_methods_node.has_method(method):
		other_methods_node.call(method, cue)
	elif act_node.has_method('act'):
		act_node.call('act', cue)
