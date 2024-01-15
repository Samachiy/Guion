extends Node

#var registry: Dictionary
var start_line_num: int = -1
var start_name_id: String = ''
var is_recording_entry: bool = false

var compare_function = "_compare"

enum{
	START,
	END
}

func should_skip(entry_name, line_num) -> bool:
	var resul = false
	var registry = Director.saveload.skipped_lines
	var skiper_entry = registry.get(entry_name)
	if skiper_entry != null:
		resul = _is_in_range(skiper_entry, line_num)
	return resul


func start_skip_entry(name_id, line_num):
	start_line_num = line_num
	start_name_id = name_id
	is_recording_entry = true


func end_skip_entry(name_id, line_num):
	if not is_recording_entry:
		return
	
	if name_id == start_name_id:
		if name_id != '':
			_add_skip_entry(name_id, start_line_num, line_num)
	else:
		l.g("Can't add skip entry, the name/id doesn'tmatch: '" + \
		start_name_id + "' and '" + name_id + "'.")
	
	is_recording_entry = false
	start_line_num = -1
	start_name_id = ''


func _add_skip_entry(entry_name, start_number, end_number):
	if start_number > end_number:
		l.g("Cannot add skip entry of id '" + entry_name + "'. End line (" + 
		start_number + ") is less than start line (" + end_number + ")")
		return
	
	var registry = Director.saveload.skipped_lines
	var skiper_entry = registry.get(entry_name)
	if skiper_entry == null:
		skiper_entry = []
		registry[entry_name] = skiper_entry
	
	registry[entry_name] = _add_range_in_entry(skiper_entry, start_number, end_number)


func _is_in_range(entry: Array, number: int) -> bool:
	var pos = entry.bsearch_custom([number, ], self, compare_function)
	# pos corresponds to the array position which number is more than or equal
	# to the number passed as parameter, if there's no such number, pos will
	# be a index outside the array.
	# if array[pos] correspond to an END type, that means that the number is
	# inside the range. The equal is there because if the number falls right
	# in the beggining of the range, the type will START, even though is in 
	# the range.
	if pos >= entry.size():
		return false
	elif entry[pos][1] == 1 or number == entry[pos][0]:
		return true
	else:
		return false


func _add_range_in_entry(entry: Array, start_line_number: int, end_line_number: int):
	if entry.empty():
		entry.append([start_line_number, START])
		entry.append([end_line_number, END])
		return entry
	
	var resul_entry_ini: Array 
	var resul_entry_end: Array 
	var start_item = [start_line_number, START]
	var end_item = [end_line_number, END]
	var pos_ini = entry.bsearch_custom(start_item, self, compare_function)
	var pos_end = entry.bsearch_custom(end_item, self, compare_function)
	
	if pos_ini > 0:
		resul_entry_ini = entry.slice(0, pos_ini - 1)
		_append_solving_continuity(resul_entry_ini, start_item)
	else:
		resul_entry_ini = [start_item]
	
	_append_solving_continuity(resul_entry_ini, end_item)
	if pos_end < entry.size():
		resul_entry_end = entry.slice(pos_end, entry.size() - 1)
		for item in resul_entry_end:
			_append_solving_continuity(resul_entry_ini, item)
	
	return resul_entry_ini



func _append_solving_continuity(entry: Array, item: Array):
	var prev_item = entry.back()
	# since the entry is never going to be empty before adding a new item
	# due to the guard clauses oon 'add', it's safe to check the last 
	# element with .back()
	if item[1] == START:
		if prev_item[1] == START:
			pass
		elif _are_continous(prev_item[0], item[0]):
			entry.pop_back()
		else:
			entry.append(item)
	else:
		if prev_item[1] == END:
			entry.pop_back()
			entry.append(item)
		else:
			entry.append(item)


func _are_continous(first_num: int, second_num: int) -> bool:
	# array = [line_number, type]
	var resul = false
	if first_num == second_num or first_num + 1 == second_num:
		resul = true
	
	return resul


static func _compare(a, b):
	return a[0] < b[0]


func _print_status():
	var registry = Director.saveload.skipped_lines
	for i in range(registry.size()):
		l.p(registry[i])


# TESTING
#func _ready():
#	L.new_measure()
#	_add_skip_entry('a', 4, 8)
#	_add_skip_entry('a', 24, 28)
#	_add_skip_entry('a', 34, 38)
#	_add_skip_entry('a', 44, 48)
#	L.p('-----')
#
#	_add_skip_entry('a', 49, 52)
#	_add_skip_entry('a', 1, 3)
#	_add_skip_entry('a', 29, 33)
#	_add_skip_entry('a', 39, 40)
#	_add_skip_entry('a', 42, 43)
#	L.p('-----------')
#	_add_skip_entry('a', 40, 41)
#	_add_skip_entry('a', 52, 53)
#	_add_skip_entry('a', 58, 59)
#	_add_skip_entry('a', 24, 28)
#	_add_skip_entry('a', 8, 24)
#	_add_skip_entry('a', 0, 55)
#	L.p(should_skip('a', 59))
#	L.p(should_skip('a', 53))
#	L.p(should_skip('a', 58))
#	L.p(should_skip('a', 54))
#	L.p(should_skip('a', 57))
#	L.p(should_skip('a', -21))
#	L.p(should_skip('a', 0))
#	L.p(should_skip('a', 1))
#	L.p(should_skip('a', 52))
#	L.write_measure('entries tested')
