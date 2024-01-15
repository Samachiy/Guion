extends Reference

class_name Flag

# The flag wrapper exists pretty much in order to manage the signals
# Since every process to modify a flag goes through the same one wrapper, 
# signals can be used. For this to work there has to be only one FlagWrapper
# per flag

enum {
	VALUE,
}

signal flag_created()
signal flag_destroyed()
signal flag_value_changed(old_value, new_value)
signal flag_is_global_changed(old_is_global, new_is_global)

var value: float setget set_value, get_value
var is_global: bool setget set_is_global, get_is_global
var name: String
var manager setget , get_manager

func _init(name_: String, manager_ = null):
	name = name_
	manager = manager_


func get_manager():
	# This function also has the role of a guard clause, since it will prevent misbehaviour
	# by checking if managaer is null at the start of a function
	if manager == null:
		manager = Flags
	
	return manager


func set_value(value_: float):
	var flag = get_manager().flag_catalog.get(name)
	var old_value: float
	if flag == null:
		flag = create()
	
	old_value = flag[VALUE]
	flag[VALUE] = value_
	
	flag = get_manager().global_flags.get(name)
	if flag != null:
		#old_value_global = flag[VALUE]
		flag[VALUE] = value_
	
	if old_value != value_:
		emit_signal("flag_value_changed", old_value, value_)


func get_value():
	var flag = get_manager().global_flags.get(name)
	if flag == null:
		flag = manager.flag_catalog.get(name)
		if flag == null:
			return 0.0
		else:
			return flag[VALUE]
	else:
		return flag[VALUE]


func set_is_global(value_: bool):
	var flag = get_manager().flag_catalog.get(name)
	if flag == null:
		flag = create()
	
	#if the current 'is_global' status equals the new, there's no need to do anything else.
	if get_is_global() == value_:
		return 
	
	if value_:
		manager.global_flags[name] = flag
		emit_signal("flag_is_global_changed", false, true)
	else:
		manager.global_flags.erase(name)
		emit_signal("flag_is_global_changed", true, false)
	

func get_is_global():
	var flag = get_manager().global_flags.get(name)
	if flag == null:
		return false
	else:
		return true


func exists():
	var flag = get_manager().flag_catalog.get(name)
	if flag == null:
		return false
	else:
		return true


func create():
	var flag = get_manager().flag_catalog.get(name)
	if flag == null:
		flag = manager.FLAG_TEMPLATE.duplicate()
		manager.flag_catalog[name] = flag
		emit_signal("flag_created")
		#manager.emit_signal("flag_added", name)
	
	return flag


func get_flag_array(create_if_null: bool) -> Array:
	if create_if_null:
		return create()
	else:
		return get_manager().flag_catalog.get(name)


func remove():
	var success = get_manager().flag_catalog.erase(name)
	if success:
		manager.global_flags.erase(name)
		emit_signal("flag_destroyed")
		manager.emit_signal("flag_removed", name)
	
	return success


func set_up(is_global_ = null, value_ = null, is_global_if_new = null, value_if_new = null):
	if not exists():
		create()
		if value_if_new != null:
			set_value(float(value_if_new))
		if is_global_if_new != null:
			set_is_global(is_global_if_new)
			
	
	if value_ != null:
		set_value(float(value_))
	
	if is_global_ != null and is_global_ is bool:
		set_is_global(is_global_)
	
	return self


