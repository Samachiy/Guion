extends Node

class_name FlagModule

const FLAG_TEMPLATE: Array = [0.0] 
const NOT_SIGN = '~'

var flag_catalog: Dictionary = {} setget set_all_flags, get_all_flags
var global_flags: Dictionary = {} setget set_global_flags, get_global_flags
var wrappers: Dictionary = {}

func get_flag_array(flag_name: String):
	return flag_catalog.get(flag_name)


func get_flag_wrapper(flag_name: String) -> Flag:
	var wrapper = wrappers.get(flag_name)
	if wrapper == null:
		wrapper = Flag.new(flag_name, self)
		wrappers[flag_name] = wrapper
	
	return wrapper


func ref(flag_name: String) -> Flag:
	# This is simply an alias to get a reference to the flag wrapper
	return get_flag_wrapper(flag_name)


func add(cue: Cue):
	# [flag1, flag2, ... flagn]
	# value: int = 0
	# global: bool = false
	# Will add the flags to the dictionary, and if value != 0, will add
	# that to flag counter. Default value is 0.
	
	var value = cue.get_float_option('value', 0)
	var global = cue.get_bool_option('global', false)
	var flag_wrapper: Flag
	for flag_name in cue._arguments:
		flag_name = flag_name.strip_edges()
		flag_wrapper = get_flag_wrapper(flag_name)
		add_rollback_if_needed(flag_wrapper, cue)
		if flag_wrapper.exists():
			flag_wrapper.value += value
			flag_wrapper.is_global = global
		else:
			flag_wrapper.create()
			flag_wrapper.is_global = global


func remove(cue: Cue):
	# [flag1, flag2, ... flagn]
	
	var flag_wrapper: Flag
	for flag_name in cue._arguments:
		flag_name = flag_name.strip_edges()
		flag_wrapper = get_flag_wrapper(flag_name)
		if flag_wrapper.exists():
			add_rollback_if_needed(flag_wrapper, cue)
			flag_wrapper.remove()
		else:
			l.g("Couldn't remove flag '" + flag_name + "'. It doesn't exist.")


func add_rollback_if_needed(wrapper_before_change: Flag, cue: Cue):
	if cue.requires_rollback:
		if wrapper_before_change.exists():
			Director.add_rollback_cue('', "set_flag", 
			[wrapper_before_change.name, 
			wrapper_before_change.value, 
			wrapper_before_change.is_global])
		else:
			Director.add_rollback_cue('', "remove_flag", [wrapper_before_change.name])


func set_flag(cue: Cue):
	# [name: String, value: float, is_global: bool]
	
	# Sets a flag to the specific value, used mainly for rollbacks
	var flag_wrapper = get_flag_wrapper(cue.get_at(0, ''))
	flag_wrapper.value = cue.get_float(1, 0.0)
	flag_wrapper.is_global = cue.get_bool(2, false)


func has(args) -> bool:
	# [flag1, flag2, ... flagn]
	
	var success: bool = true
	for flag in args:
		if not has_single_flag(flag):
			success = false
			break

	return success


func has_single_flag(flag: String) -> bool:
	if flag[0] == NOT_SIGN:
		return not flag_catalog.has(flag.substr(1))
	else:
		return flag_catalog.has(flag)


func count_up_flag(cue: Cue):
	# [flag1, flag2, ... flagn]
	# value: int = 1
	
	# The difference with 'add' is that here the default value is 1 instead of 0
	cue.add_option('value', cue.get_float_option('value', 1))
	add(cue)


func add_to_flag(cue: Cue):
	# [flag1, flag2, ... flagn, value = 0]
	
	# The difference with 'add' is that here the value is specified
	# as the last argument rather than an individual option.
	var value = float(cue._arguments.pop_back())
	cue.add_option('value', value)
	add(cue)


func set_global_flags(value: Dictionary):
	global_flags = value
	refresh_local_flags_value_with_global()


func set_all_flags(value: Dictionary):
	flag_catalog = value
	refresh_local_flags_value_with_global()


func get_global_flags():
	return global_flags


func get_all_flags():
	refresh_local_flags_value_with_global()
	return flag_catalog


func refresh_local_flags_value_with_global():
	for flag_name in global_flags.keys():
		flag_catalog[flag_name] = global_flags[flag_name]



# TESTING

#func _ready():
#	var time_before
#	var total_time 
#	var parse_one_resul
#	time_before = OS.get_ticks_usec()
#	has(['a'])
#	add(Cue.new('', '', ['a', 'b', 'b', 'b', 'a']))
#	remove(Cue.new('', '', ['b']))
#	remove(Cue.new('', '', ['a']))
#	add(Cue.new('', '', ['e1', 'e2', 'e3', 'e4', 'e5']))
#	add(Cue.new('', '', ['d1', 'd2', 'd3', 'd4', 'd5']))
#	add(Cue.new('', '', ['c1', 'c2', 'c3', 'c4', 'c5']))
#	total_time = OS.get_ticks_usec() - time_before
#	L.p(total_time)
#	L.p(flag_catalog)
##	get_flags_from_to('c', 'd')
##	get_flags_from_to('c1', 'e1')
##	get_flags_from_to('e1', 'e5')
##	get_flags_from_to('a', 'z')
#	pass
