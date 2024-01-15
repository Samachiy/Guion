extends Node

onready var camera = $Stage/Camera3D
onready var popups = $Stage/PopUps
onready var reader = $Stage/Reader
onready var line = $Stage/Reader/Line
onready var stage = $Stage
onready var backlog = $Stage/Reader/Backlog
onready var file = $Stage/Reader/FileManager
#onready var skipper = $Stage/Reader/FileManager/Skipper
#onready var file = $Stage/Reader/FileManager/NormalFile
#onready var temp_file = $Stage/Reader/FileManager/TempFile
#onready var flags = $Stage/Reader/Jumper/Flags
onready var auto_save_timer = $AutoSaveTimer

export(bool) var unstable_load: bool = true
export(bool) var clear_roles_on_load: bool = false
export(bool) var swap_viewport_on_current_scene: bool = false

const SAVE_DIR = "user://saves/"
const MAIL_CUE_LABEL = 'cues mailbox'
const FILE_SAVE_LABEL = 'file save'
const SCENE_SAVE_LABEL = 'scene save'
const AUTO_SAVE_SLOT = '_autosave'

var skipped_lines: Dictionary = {}

var default_label: String = SCENE_SAVE_LABEL
var save_name: String = "save"
var global_save_name: String = "global_save"
var file_extension: String = ".dat"
var save_cues_method: String = "_save_cues"
# each key of 'lockers' is the name of the locker
# each value of 'lockers' is a dictionary that contains labels as keys and a cue array as values
var lockers: Dictionary = {} 
# to fill this, objects have to connect to 'global_save_cues_requested' signal
var global_save_cues: Array = [] 
var is_loading_from_file: bool = false
var game_viewport_resource = null
var game_viewport = null setget , get_game_viewport
var auto_save_ready: bool = false
var subscribed_lockers_on_load_ready: Array = []
var is_global_file_loaded: bool = false

signal load_ready(is_loading_from_file)
signal game_viewport_changed(viewport)
signal file_save_requested(slot)
signal file_saved(slot)
signal file_load_requested(slot)
signal file_loaded(slot)
signal save_cues_requested(is_game_save)
signal global_save_cues_requested
signal auto_saved_file_found(slot)
signal global_file_loaded
signal game_closing

func _ready():
	camera.save_dir = SAVE_DIR
	camera.save_name = save_name
	camera.is_current_scene_a_viewport = swap_viewport_on_current_scene
	Roles.saveload_system = self
	game_viewport_resource = preload("res://addons/guion/director/StageViewport.tscn")
	set_up_locker('')
	if save_file_exists(AUTO_SAVE_SLOT):
		emit_signal("auto_saved_file_found", AUTO_SAVE_SLOT)
	
	yield(get_tree().current_scene, "ready")
	load_global_file()


# MISC FUNCTIONS

func start_auto_save(time: int = 300):
	auto_save_timer.wait_time = time
	auto_save_timer.start(time)


func add_save_cue(locker_name: String, role_string: String, method: String, args: Array = [], 
options: Dictionary = {}):
	var cue: Cue = Cue.new(role_string, method).args(args).opts(options)
	store_cue(locker_name, cue)


func add_global_save_cue(role_string: String, method: String, args: Array = [], 
options: Dictionary = {}):
	var cue: Cue = Cue.new(role_string, method).args(args).opts(options)
	global_save_cues.append(cue)


func scene_load_ready(wrap_with_viewport: bool):
	if wrap_with_viewport:
		add_game_viewport()
	
	if is_loading_from_file:
		_load_cues()
	
	reader.should_read = true
	reader._append_text("")
	emit_signal("load_ready", is_loading_from_file)
	is_loading_from_file = false
	if auto_save_ready:
		request_auto_save()


func _get_save_path(slot_num = '_q'):
	return (SAVE_DIR + save_name + str(slot_num) + file_extension)


func _get_global_save_path():
	return (SAVE_DIR + global_save_name + file_extension)


func create_file(file_path: String, globalize_path: bool = true):
	if globalize_path:
		file_path = ProjectSettings.globalize_path(file_path)
	
	var file_dir = file_path.get_base_dir()
#	if !DirAccess.dir_exists_absolute(file_dir):
#		DirAccess.make_dir_recursive_absolute(file_dir)
	
	var dir = Directory.new()
	if !dir.dir_exists(file_dir):
		dir.make_dir_recursive(file_dir)
	
	
	var save_file = File.new()
	var error = save_file.open(file_path, File.WRITE)
	#var error = save_file.open_encrypted_with_pass(save_path, File.WRITE, password)
	if error == OK:
		return save_file
	else:
		l.g("Couldn't open/create file '" + file_path + "'. Error: " + str(error))
		return null


func open_file(file_path: String, globalize_path: bool = true):
	if globalize_path:
		file_path = ProjectSettings.globalize_path(file_path)
	
	
	var load_file = File.new()
	if load_file.file_exists(file_path):
		var error = load_file.open(file_path, File.READ)
		#var error = load_file.open_encrypted_with_pass(save_path, File.READ, password)
		if error != OK:
			l.g("Couldn't open file '" + file_path + "'. Error: " + str(error))
			load_file = null
	else:
		l.g("Couldn't open file '" + file_path + "'. File not found")
		load_file = null
	
	return load_file



# LOAD AND SAVE FUNCTIONS

# SAVE FUNCTIONS


func request_auto_save(_cue: Cue = null):
	auto_save_ready = false
	save_file_at_slot(AUTO_SAVE_SLOT)
	auto_save_timer.stop()
	auto_save_timer.start()


func restore_auto_save(_cue: Cue = null):
	load_file_at_slot(AUTO_SAVE_SLOT)
	delete_save_file(AUTO_SAVE_SLOT, true)


func auto_save_exists():
	return save_file_exists(AUTO_SAVE_SLOT)


func save_file_exists(slot_num):
	var save_file = File.new()
	return save_file.file_exists(_get_save_path(slot_num))


func delete_save_file(slot_num, move_to_trash = false):
	var file_to_remove = _get_save_path(slot_num)
	var success = false
	if move_to_trash:
		var dir = Directory.new()
		if dir.remove(file_to_remove) == OK:
			l.g("Successfully removed the save file at slot: " + str(slot_num), l.INFO)
			success = true
		else:
			l.g("Couldn't remove the save file at slot: " + str(slot_num))
	elif OS.move_to_trash(ProjectSettings.globalize_path(file_to_remove)) == OK:
		l.g("Successfully moved to trash the save file at slot: " + str(slot_num), l.INFO)
		success = true
	else:
		l.g("Couldn't move to trash the save file at slot: " + str(slot_num))
	
	return success


func save_file_at_slot(slot_num = '_q'):
	_save_cues()
	default_label = FILE_SAVE_LABEL # this means to lockers labels
	fill_lockers(true)
	default_label = SCENE_SAVE_LABEL
	_save_data(slot_num)
	wipe_label(FILE_SAVE_LABEL)


func _save_data(slot_num = '_q'):
	emit_signal("file_save_requested", slot_num)
	save_global_file()
	var save_path = _get_save_path(slot_num)
	var data
	
	data = {
		"lockers" : lockers,
		"flags": Flags.flag_catalog,
		"global_abr_array": reader.global_abr_array,
		"backlog": backlog.get_trimmed_active_backlog(),
		"scene": stage.current_scene,
		"text": line.text
	}
	
	#var error = save_file.open_encrypted_with_pass(save_path, File.WRITE, password)
	var save_file = create_file(save_path)
	if save_file != null:
		save_file.store_var(data)
		save_file.close()
		emit_signal("file_saved", slot_num)


func _save_cues():
	var ref_cue = file.get_reference_cue()
	if ref_cue != null:
		store_cue('', ref_cue) # add_save_cue but without the wrapper
	
	if stage.is_stage_showing:
		add_save_cue('', '', 'show_stage')
	else:
		add_save_cue('', '', 'hide_stage')
	
	add_save_cue('', '', 'set_stage_layout', [stage.actors_number, stage.actors_padding_h])
	
	pass


func fill_lockers(is_game_save: bool):
	for role in Roles.roles.values():
		if is_instance_valid(role.node) and role.node.has_method(save_cues_method):
			role.node.call(save_cues_method, is_game_save)
	
	emit_signal("save_cues_requested", is_game_save)


func save_global_file():
	var save_path = _get_global_save_path()
	var disassembled_cues = []
	emit_signal("global_save_cues_requested")
	for cue in global_save_cues:
		disassembled_cues.append(cue.disassemble())
	var data = {
		"flags": Flags.global_flags,
		"skip_registry": skipped_lines,
		"global_cues": disassembled_cues
	}
	
	var save_file = create_file(save_path)
	if save_file != null:
		save_file.store_var(data)
		save_file.close()
	
	global_save_cues.clear()


# LOAD FUNCTIONS


func load_file_at_slot(slot_num = '_q'):
	if not save_file_exists(slot_num):
		return
	# To finish load, every root of the scenes should use scene_reload_ready()
	emit_signal("file_load_requested", slot_num)
	reader.abort()
	is_loading_from_file = true
	_load_data(slot_num)


func _load_data(slot_num = '_q'):
	var save_path = _get_save_path(slot_num)
	var load_file = open_file(save_path)
	#var error = load_file.open_encrypted_with_pass(save_path, File.READ, password)
	if load_file != null:
		var data = load_file.get_var()
		var text
		load_file.close()
		
		lockers = data['lockers']
		Flags.flag_catalog = data['flags']
		reader.global_abr_array = data['global_abr_array']
		backlog.array = data['backlog']
		text = data['text']
		Roles.clear_roles()
		reader.current_text = text
		line.text = text
		backlog.reset_backlog_cursor()
		backlog.refresh_is_backlog_var()
		stage.change_scene_to_file(Cue.new('', '').args([data['scene'], true]))
		emit_signal("file_loaded", slot_num)


func _load_cues():
	#for locker_name in lockers.keys():
	#	use_up_locker(locker_name)
	
	#backlog.wipe_backlogs()
	use_up_locker('')


func load_global_file():
	var save_path = _get_global_save_path()
	var load_file = open_file(save_path)
	#var error = load_file.open_encrypted_with_pass(save_path, File.READ, password)
	var cues = []
	if load_file != null:
		var data = load_file.get_var()
		load_file.close()
		
		# Report of ths status and warnings
		l.g("Global file loaded. ", l.INFO)
		if not Flags.flag_catalog.empty():
			l.g(str(Flags.flag_catalog.size()) + " flags overwriten when loading global file.", 
					l.WARNING)
		if not skipped_lines.empty():
			l.g(str(skipped_lines.size()) + " skip entries overwriten when loading global file.", 
					l.WARNING)
		
		# Info extraction
		Flags.global_flags = data.get('flags', {})
		skipped_lines = data.get('skip_registry', {})
		cues = data.get('global_cues', [])
	
	var aux_cue
	for disassembled_cue in cues: 
			aux_cue = Cue.new('', '').assemble(disassembled_cue)
			aux_cue.execute()
	
	emit_signal("global_file_loaded")
	is_global_file_loaded = true




# LOCKER MANAGEMENT


func use_up_locker_on_load_ready(role_name: String):
	# <PENDING REMOVE this function corresponds to a feature that once was though as
	# needed but after finding a better work around, haven't been used since
	# < means delayed until this is it's own repo
	subscribed_lockers_on_load_ready.append(role_name)


func use_up_subscribed_lockers():
	# <PENDING REMOVE this function corresponds to a feature that once was though as
	# needed but after finding a better work around, haven't been used since.
	# This function isn't even used anywhere
	# < means delayed until this is it's own repo
	for role_name in subscribed_lockers_on_load_ready:
		use_up_locker(role_name)


func set_up_locker(locker_name: String):
	if not locker_name in lockers:
		lockers[locker_name]  = {}


func use_up_locker(locker_name: String):
	# will execute all the cues as well as empty it once it's done
	var locker = lockers.get(locker_name)
	var aux_cue: Cue
	if locker == null:
		l.g("Can't use up locker. Locker '" + locker_name + "' doesn't exist.")
		return
	
	for cues in locker.values(): # this cycle through the arrays of all labels
		for disassembled_cue in cues: # this cycle through the cues in the array
			aux_cue = Cue.new('', '').assemble(disassembled_cue)
			aux_cue.execute()
	
	wipe_locker(locker)


func push_mail_cue(cue: Cue) -> bool:
	var success: bool = store_cue(cue.role, cue, MAIL_CUE_LABEL)
	if success:
		backlog.add_rollback_cue('', '_pop_mail_cue', [cue.role])
	
	return success


func pop_mail_cue(cue: Cue):
	var locker = lockers.get(cue.get_at(0))
	var cues: Array
	if locker != null:
		cues = locker.get(MAIL_CUE_LABEL, [])
		cues.pop_back()
	else:
		l.g("Can't pop mail cue. Locker '" + cue.get_at(0) + "' doesn't exist for cue: " + str(cue))


func store_cue(locker_name: String, cue: Cue, label: String = default_label, 
replace: bool = false):
	var locker = lockers.get(locker_name)
	var success: bool = false
	if locker != null:
		var label_cues_ref = _request_label(locker, label)
		if replace:
			label_cues_ref.clear()

		label_cues_ref.append(cue.disassemble())
		success = true
	else:
		l.g("Can't store cue. Locker '" + locker_name + "' doesn't exist for cue: " + str(cue))
	
	return success


func store_cues(locker_name: String, cues: Array, label: String = default_label, 
replace: bool = false):
	var locker = lockers.get(locker_name)
	var success: bool = false
	if locker != null:
		var label_cues = _request_label(locker, label)
		if replace:
			label_cues.clear()
		
		for i in range(cues.size()):
			label_cues.append(cues[i].disassemble())
		success = true
	else:
		l.g("Can't store cues. Locker '" + locker_name + "' doesn't exist for cues: " + str(cues))
	
	return success


func _request_locker(locker_name: String) -> Dictionary:
	# returns the reference of the locker by name, if the locker doesn't exist, it will create it.
	var locker_ref = lockers.get(locker_name)
	if locker_ref == null:
		locker_ref = {}
		lockers[locker_name] = locker_ref

	return locker_ref


func _request_label(locker: Dictionary, label: String) -> Array:
	# returns the reference of the array of cues belonging to an specific
	# label, if the label doesn't exist, it will create it.
	var label_cues_ref = locker.get(label)
	if label_cues_ref == null:
		label_cues_ref = Array()
		locker[label] = label_cues_ref

	return label_cues_ref


func wipe_label(label: String):
	for locker in lockers.values():
		locker.erase(label)


func remove_locker(locker_name: String):
	return lockers.erase(locker_name)


func wipe_lockers():
	lockers.clear()


func wipe_locker(locker):
	if locker != null:
		locker.clear()


func add_game_viewport():
	if not swap_viewport_on_current_scene:
		return
	
	if game_viewport_resource != null:
		var game_viewport_canvas = game_viewport_resource.instance()
		game_viewport_canvas.node_with_signal = self
		game_viewport_canvas.viewport_changed_emit_signal_method = "emit_game_viewport_changed"
		game_viewport = game_viewport_canvas.replace_scene(get_tree())
		yield(get_tree(), "idle_frame")


func get_game_viewport():
	if game_viewport != null:
		return game_viewport
	else:
		return get_viewport()


func emit_game_viewport_changed():
	emit_signal("game_viewport_changed", get_game_viewport())


func _on_Stage_scene_change_started() -> void:
	if not is_loading_from_file:
		fill_lockers(false)


func _on_AutoSaveTimer_timeout():
	auto_save_timer.stop()
	auto_save_ready = true


func _on_SaveLoad_tree_exiting():
	save_global_file()
	emit_signal("game_closing")
	l.g('Graceful game close achieved', l.INFO)
	if save_file_exists(AUTO_SAVE_SLOT):
		delete_save_file(AUTO_SAVE_SLOT)


