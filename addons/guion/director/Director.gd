extends Node

onready var saveload = $SaveLoad
onready var stage = $SaveLoad/Stage
onready var reader = $SaveLoad/Stage/Reader
onready var backlog = $SaveLoad/Stage/Reader/Backlog
onready var normal_file = $SaveLoad/Stage/Reader/FileManager/NormalFile
onready var temp_file = $SaveLoad/Stage/Reader/FileManager/TempFile
onready var file = $SaveLoad/Stage/Reader/FileManager
onready var camera = $SaveLoad/Stage/Camera3D
onready var blackout = $SaveLoad/Stage/PopUps/Blackout
onready var parser = $SaveLoad/Stage/Reader/Parser
onready var file_manager = $SaveLoad/Stage/Reader/FileManager
onready var jumper = $SaveLoad/Stage/Reader/Jumper
onready var console = $ConsoleServer
onready var processor = $SaveLoad/Stage/Processor
onready var logic = $Logic

export var default_locale: String = 'en_US'
export var major_version: int = 0
export var minor_version: int = 0
export var patch_version: int = 0
export var release_candidate: int = 0 # 0 means it is not release candidate


func get_current_version_array() -> Array:
	return [major_version, minor_version, patch_version]


func get_current_version_string() -> String:
	return str(major_version) + "." + str(minor_version) + "." + str(patch_version)


func _ready():
	parser = parser.parser
	processor.reader = reader


# SIGNALS RELAY (necessary to adapt this to godot 4, willbe done on demand)

func connect_spotlight(node, method_name: String):
	reader.connect("spotlight_changed", node, method_name)

func connect_text(node, method_name: String):
	reader.connect("text_changed", node, method_name)

func connect_blackout_start(node, method_name: String):
	blackout.connect("blackout_started", node, method_name)

func connect_blackout_end(node, method_name: String):
	blackout.connect("blackout_ended", node, method_name)

func connect_ui_registry_cleared(node, method_name: String):
	camera.connect("ui_registry_cleared", node, method_name)

func connect_load_ready(node, method_name: String):
	return saveload.connect("load_ready", node, method_name)

func connect_file_save_requested(node, method_name: String):
	saveload.connect("file_save_requested", node, method_name)

func connect_file_saved(node, method_name: String):
	saveload.connect("file_saved", node, method_name)

func connect_file_load_requested(node, method_name: String):
	saveload.connect("file_load_requested", node, method_name)

func connect_file_loaded(node, method_name: String):
	saveload.connect("file_loaded", node, method_name)

func connect_global_file_loaded(node, method_name: String):
	saveload.connect("global_file_loaded", node, method_name)

func connect_save_cues_requested(node, method_name: String):
	saveload.connect("save_cues_requested", node, method_name)

func connect_global_save_cues_requested(node, method_name: String):
	saveload.connect("global_save_cues_requested", node, method_name)

func connect_game_closing(node, method_name: String):
	saveload.connect("game_closing", node, method_name)

func connect_game_viewport_changed(node, method_name: String):
	saveload.connect("game_viewport_changed", node, method_name)

func connect_scene_change_started(node, method_name: String):
	stage.connect("scene_change_started", node, method_name)

func connect_scene_change_succeded(node, method_name: String):
	stage.connect("scene_change_succeded", node, method_name)

func connect_stage_hidden(node, method_name: String):
	stage.connect("stage_hidden", node, method_name)

func connect_stage_shown(node, method_name: String):
	stage.connect("stage_shown", node, method_name)

# Re-add this signals on demand

#func connect_flags_changed(node, method_name: String):
#	flags.connect("flags_changed", Callable(node, method_name))
#
#func connect_flag_added(node, method_name: String):
#	flags.connect("flag_added", Callable(node, method_name))
#
#func connect_flag_removed(node, method_name: String):
#	flags.connect("flag_removed", Callable(node, method_name))
#
#func connect_flag_value_changed(node, method_name: String):
#	flags.connect("flag_value_changed", Callable(node, method_name))


# VARIABLES FUNCTIONS


func is_loading():
	return saveload.is_loading
func is_stage_showing():
	return stage.is_stage_showing
func is_ui_hidden():
	return camera.is_ui_hidden
func is_reading():
	return reader.is_reading
func is_waiting():
	return reader.is_waiting
func is_backlog():
	return backlog.is_backlog()
func is_backlog_up():
	return backlog.is_backlog_up()
func is_open():
	return file.is_open()


func get_screen_v():
	return stage.screen_v
func get_screen_h():
	return stage.screen_h
func get_stage_padding_h():
	return stage.stage_padding_h
func get_positions_number():
	return stage.positions_number
func get_stage_positions():
	return stage.positions
func get_game_viewport():
	return saveload.get_game_viewport()
func get_should_read():
	return reader.should_read
func set_should_read(value: bool):
	reader.should_read = value



# FUNCTIONS


func add_save_cue(locker_name: String, role_string: String, method: String, args: Array = [], 
options: Dictionary = {}):
	saveload.add_save_cue(locker_name, role_string, method, args, options)
func add_global_save_cue(role_string: String, method: String, args: Array = [], 
options: Dictionary = {}):
	saveload.add_global_save_cue(role_string, method, args, options)
func scene_load_ready(wrap_with_viewport: bool):
	saveload.scene_load_ready(wrap_with_viewport)
func save_file_at_slot(slot_num = '_q'):
	saveload.save_file_at_slot(slot_num)
func load_file_at_slot(slot_num = '_q'):
	saveload.load_file_at_slot(slot_num)
func save_file_at_path(path):
	saveload.save_file_at_path(path)
func load_file_at_path(path):
	saveload.load_file_at_path(path)
func _pop_mail_cue(cue: Cue):
	saveload.pop_mail_cue(cue)
func _push_mail_cue(cue: Cue):
	saveload.push_mail_cue(cue)
func set_up_locker(locker_name: String):
	saveload.set_up_locker(locker_name)
func use_up_locker(locker_name: String):
	saveload.use_up_locker(locker_name)
func use_up_locker_on_load_ready(role_name):
	saveload.use_up_locker_on_load_ready(role_name)
func store_cue(locker_name: String, cue: Cue, label: String = '', replace: bool = false):
	return saveload.store_cue(locker_name, cue, label, replace)
func store_cues(locker_name: String, cues: Array, label: String = '', replace: bool = false):
	return saveload.store_cues(locker_name, cues, label, replace)
func remove_locker(locker_name: String):
	saveload.remove_locker(locker_name)
func wipe_lockers():
	saveload.wipe_lockers()
func get_save_file_extension():
	return saveload.file_extension
func get_save_directory():
	return saveload.SAVE_DIR
func save_file_exists(slot_num):
	return saveload.save_file_exists(slot_num)
func request_auto_save(_cue: Cue = null):
	return saveload.request_auto_save(_cue)
func restore_auto_save(_cue: Cue = null):
	return saveload.restore_auto_save(_cue)
func auto_save_exists():
	return saveload.auto_save_exists()
func reload_current_scene(reload_global_file: bool):
	return saveload.reload_current_scene(reload_global_file)


func hide_stage(cue: Cue):
	stage.hide_stage(cue)
func show_stage(cue: Cue):
	stage.show_stage(cue)
func set_stage_layout(cue: Cue):
	stage.set_stage_layout(cue)
func change_scene_to_file(cue: Cue):
	stage.change_scene_to_file(cue)
func load_scene(scene_path: String):
	stage.change_scene_to_file(Cue.new('', '').args([scene_path]))
func cue_on_scene_change_finished(cue: Cue):
	stage.cue_on_scene_change_finished(cue)
func start_dialog(cue: Cue):
	stage.start_dialog(cue)
func end_dialog(cue: Cue):
	stage.end_dialog(cue)
func clear_dialog(cue: Cue):
	stage.clear_dialog(cue)
func kill_dialog(cue: Cue):
	stage.kill_dialog(cue)


func read_file(text_file):
	reader.read_file(text_file)
func read(_cue: Cue = null):
	if _cue != null:
		_cue.get_reader().read()
	else:
		reader.read()
func resume():
	reader.resume()
func read_this(text, caller = null, skip_id = ''):
	reader.read_this(text, caller, skip_id)
func wait(_cue: Cue = null):#, force: bool = false):
	if _cue != null:
		_cue.get_reader().wait(_cue)#, force)
	else:
		reader.wait(_cue)
func force_flush():
	reader.force_flush()
func add_global_abr(cue: Cue):
	reader.add_global_abr(cue)
func remove_global_abr(cue: Cue):
	reader.remove_global_abr(cue)
func add_abr(cue: Cue):
	cue.get_reader().add_abr(cue)
func remove_abr(cue: Cue):
	cue.get_reader().remove_abr(cue)
func replace_abr(abbreviation: String, default: String = ''):
	return reader.replace_abr(abbreviation, default)
func set_text_speed(value: float):
	reader.text_speed = value
func get_text_speed():
	return reader.text_speed
func set_can_skip_unread_text(value: bool):
	reader.can_skip_unread_text = value
func get_can_skip_unread_text():
	return reader.can_skip_unread_text
func abort(_cue: Cue = null):
	if _cue != null:
		return _cue.get_reader().abort(_cue)
	else:
		return reader.abort(_cue)
func discard(_cue: Cue = null):
	return reader.discard(_cue)
#func _start_skip_entry(_args):
#	reader.start_skip_entry()


func process_this(text, caller = null, skip_id = ''):
	processor.process_this(text, caller, skip_id)


func _go_to(cue: Cue):
	cue.get_reader().file.go_to(cue.get_array(0, []), cue.get_int(1, -1, false), cue.get_bool(2, true, false),
	cue.get_bool(3, false, false), cue.get_bool(4, false, false))
func load_file(cue: Cue):
	file.load_file(cue)
func get_reference_cue() -> Cue:
	return file.get_reference_cue()
func get_soft_reference_cue() -> Cue:
	return file.get_soft_reference_cue()
func pop_parser_event(_cue: Cue = null):
	file.pop_parser_event(_cue)


func request_role(node, role_name: String, refresh_role: bool = false):
	Roles.request_role(node, role_name, refresh_role)
func request_role_on_roles_cleared(node, role_name: String):
	Roles.request_role_on_roles_cleared(node, role_name)
func send_cue(role_string: String, method: String, args: Array = [], options: Dictionary = {}):
	return Roles.send_cue(role_string, method, args, options)
func execute_cue(cue: Cue):
	return Roles.execute_cue(cue)
func send_or_store_cue(role_string: String, method: String, args: Array = []):
	return Roles.send_or_store_cue(role_string, method, args)
func execute_or_store_cue(cue: Cue):
	return Roles.execute_or_store_cue(cue)
func get_node_by_role(role: String, is_necessary: bool = true):
	return Roles.get_node_by_role(role, is_necessary)
func get_role(role: String):
	return Roles.get_role(role)


func backlog_up():
	backlog.backlog_up()
func backlog_down():
	backlog.backlog_down()
func trim_backlog_at(pos = null):
	backlog.trim_at(pos)
func trim_backlog(_cue = null):
	backlog.trim()
func clear(_cue: Cue = null):
	backlog.clear()
func add_rollback_cue(role_string: String, method: String, args: Array = [],
options: Dictionary = {}, half_rollback: bool = false):
	backlog.add_rollback_cue(role_string, method, args, options, half_rollback)
func add_restore_state_cue(role_string: String, method: String, args: Array = [], 
options: Dictionary = {}):
	backlog.add_rollback_cue(role_string, method, args, options)
func add_break_state_cue(role_string: String, method: String, args: Array = [], 
options: Dictionary = {}):
	backlog.add_rollback_cue(role_string, method, args, options)


func take_screenshot(img_width, img_height, slot_num):
	camera.take_screenshot(img_width, img_height, slot_num)
func hide_ui(_cue: Cue = null):
	camera.hide_ui()
func show_ui(_cue: Cue = null):
	camera.show_ui()
func register_ui(node, ui_name):
	camera.register_ui(node, ui_name)
func get_img_save_path(slot_num = '_q'):
	return camera.get_img_save_path(slot_num)


func start_blackout():
	blackout.start_blackout()
func end_blackout():
	blackout.end_blackout()


func add_flag(cue: Cue):
	Flags.add(cue)
func remove_flag(cue: Cue):
	Flags.remove(cue)
func count_up_flag(cue: Cue):
	Flags.count_up_flag(cue)
func add_to_flag(cue: Cue):
	Flags.add_to_flag(cue)
func set_flag(cue: Cue):
	Flags.set_flag(cue)
func has_flags(args: Array):
	return Flags.has(args)
func has_flag(flag: String):
	return Flags.has_single_flag(flag)
func get_flag_wrapper(flag_name: String):
	return Flags.get_flag_wrapper(flag_name)
func get_flag_array(flag_name: String):
	return Flags.get_flag_array(flag_name)


#func cue_this(text):
#	parser.cue_this(text)
func parse(text: String, abr_arrays: Array = []) -> Array:
	abr_arrays.append(reader.global_abr_array)
	var resul: Array = parser.parse(text, abr_arrays, 0, '', false)
	resul.pop_back()
	return resul
func parse_arguments(line: String) -> Array:
	return parser.parse_arguments(line)
func extract_cues(line: String, abr_arrays: Array = []) -> Array:
	abr_arrays.append(reader.global_abr_array)
	return parser.extract_cues(line, abr_arrays)



func jump_to(cue: Cue) -> bool:
	# args = [file#marker: String]
	return cue.get_reader().jumper.jump_to(cue)
func jump_in(cue: Cue) -> bool:
	# args = [file#marker: String]
	return cue.get_reader().jumper.jump_in(cue)
func jump_back(_cue: Cue):
	if _cue != null:
		_cue.get_reader().jumper.jump_back(_cue)
	else:
		jumper.jump_back(_cue)
func read_if(cue: Cue):
	# args = [flag-1, ~flag-2, ..., flag-n]
	cue.get_reader().jumper.read_if(cue)
func skip_if(cue: Cue):
	# args = [flag-1, ~flag-2, ..., flag-n]
	# Options:
	#	end = #marker:
	cue.get_reader().jumper.skip_if(cue)
func jump_to_if(cue: Cue) -> bool:
	# args = [flag-1, ~flag-2, ..., flag-n, file#marker: String]
	return cue.get_reader().jumper.jump_to_if(cue)
func jump_in_if(cue: Cue) -> bool:
	# args = [flag-1, ~flag-2, ..., flag-n, file#marker: String]
	return cue.get_reader().jumper.jump_in_if(cue)
func select_subcategory(cue: Cue):
	# args = [#marker: String]
	# Options:
	#	end = #marker: If set, the if cue will try to jump to the marker rather 
	#	than a matching indentation line when trying to reach the end of the 
	#	function. If it is set to an empty marker ('#') end will be '#end'.
	return cue.get_reader().jumper.select_subcategory(cue)
func match_flag(cue: Cue):
	#[match flag:
	#	flag_mid = #mid,
	#	flag_start = #start,
	#	flag_end = #end]
	return cue.get_reader().jumper.match_flag(cue)
func match_abr(cue: Cue):
	#[match abr: /abr,
	#	Lynn = #lynn,
	#	Fran = #fran,
	#	Chloe = #chloe]
	return cue.get_reader().jumper.match_abr(cue)
func match_value(cue: Cue):
	#[match value: flag-1,
	#	0 = #zero,
	#	1-4 = #low,
	#	5-7 = #med,
	#	8-n = #high]
	#n means 
	#	- any number lower than if placed left
	#	- any number higher than if placed right
	return cue.get_reader().jumper.match_value(cue)
func pop_jump_in(_cue: Cue = null):
	if _cue != null:
		_cue.get_reader().jumper.pop_jump_in(_cue)
	else:
		jumper.pop_jump_in(_cue)


func solve(cue: Cue):
	return logic.solve(cue)


# MISC FUNCTIONS


func pt(cue: Cue):
	print(cue.get_at(0, ''))

func set_text_scripts_locale(locale: String):
	var text_dir = normal_file.text_directory + locale + "/"
	var dir = Directory.new()
	if not dir.dir_exists(text_dir):
		text_dir = normal_file.text_directory + default_locale + "/"
	normal_file.text_folder = text_dir
