extends Node

# entry looks like this { control_node: tween_obj, ... }
var active_tweens: Dictionary = {}
var color_theme_tween: SceneTreeTween
var color_modulate_tween: SceneTreeTween
var theme_by_modulate_groups: Dictionary = {}

#signal theme_changed(style_colors_dict, type_colors_dict)
signal locale_changed(locale)


func set_locale(locale: String):
	TranslationServer.set_locale(locale)
	emit_signal("locale_changed", locale)


func _add_visibility_tween(control_node: Control, time: float, visible: bool, 
tween: SceneTreeTween = null, delay: float = 0, chain: bool = false) -> float:
	# returns how long will the tween take to complete, this is because of stuff 
	# like the replace function i prev_v_tween
	var time_to_complete = 0
	if tween == null: 
		tween = create_tween()
	
	var prev_v_tween: VisibilityTWeen = active_tweens.get(control_node)
	
	# if there's not VisibilityTween or if there's a not valid one
	if prev_v_tween == null or not prev_v_tween.is_valid():
		var v_tween = VisibilityTWeen.new(control_node, time, visible, tween, delay)
		active_tweens[control_node] = v_tween
		v_tween.play()
		time_to_complete = time
	else:
		if chain:
			prev_v_tween.chain(control_node, time, visible, tween)
			time_to_complete = prev_v_tween.get_remaining_time() + time
		else:
			time_to_complete = prev_v_tween.replace(control_node, time, visible, 
					tween, delay, true)
			prev_v_tween.play()
	
	return time_to_complete


func hide_node(control_node: Control, time: float = 0, tween: SceneTreeTween = null):
	_add_visibility_tween(control_node, time, false, tween)


func show_node(control_node: Control, time: float = 0, tween: SceneTreeTween = null):
	_add_visibility_tween(control_node, time, true, tween)


func hide_show_node(hide_node: Control, show_node: Control, hide_time: float = 0, 
show_time: float = 0, hide_tween: SceneTreeTween = null, show_tween: SceneTreeTween = null):
	var delay = _add_visibility_tween(hide_node, hide_time, false, hide_tween)
	_add_visibility_tween(show_node, show_time, true, show_tween, delay, true)


func hide_group(group_name: String, time: float, tween = null):
	if tween == null:
		tween = create_tween()
	
	var tween_copy
	for node in get_tree().get_nodes_in_group(group_name):
		tween_copy = tween.duplicate()
		hide_node(node, time, tween_copy)


func show_group(group_name: String, time: float, tween = null):
	if tween == null:
		tween = create_tween()
	
	var tween_copy
	for node in get_tree().get_nodes_in_group(group_name):
		tween_copy = tween.duplicate()
		show_node(node, time, tween_copy)


func hide_show_group(hide_group: String, show_group: String, hide_time: float, 
show_time: float, hide_tween = null, show_tween = null):
	if hide_tween == null:
		hide_tween = create_tween()
	if show_tween == null:
		show_tween = create_tween()
	
	var tween_copy
	for node in get_tree().get_nodes_in_group(hide_group):
		tween_copy = hide_tween.duplicate()
		_add_visibility_tween(node, hide_time, false, tween_copy)
	for node in get_tree().get_nodes_in_group(show_group):
		tween_copy = show_tween.duplicate()
		_add_visibility_tween(node, show_time, true, tween_copy, hide_time, true)


func show_v_scroll_indicator(v_scrollbar: VScrollBar, top_indicator: Control, 
bottom_indicator: Control, error_margin: int = 0):
	if v_scrollbar.value <= v_scrollbar.min_value + error_margin:
		top_indicator.visible = false
	else:
		top_indicator.visible = true
	if v_scrollbar.value + v_scrollbar.rect_size.y >= v_scrollbar.max_value - error_margin:
		bottom_indicator.visible = false
	else:
		bottom_indicator.visible = true


# THEME MANAGEMENT FUNTIONS


func add_to_theme_by_modulate_group(node: CanvasItem, group: String):
	if not node is CanvasItem:
		l.g("Can't add node '" + node.name + "' to group '" + group + 
		"' since it's not a CanvasItem node")
		return
	
	var color_dict
	if group in theme_by_modulate_groups:
		color_dict = theme_by_modulate_groups[group]
		_set_modulate_color(node, color_dict, 0, null)
	
	node.add_to_group(group)


func change_group_modulate_by_alpha(group: String, colors: Dictionary, 
time: float = 0, tween = null):
#	if color_modulate_tween != null and color_modulate_tween.is_running() and time != 0:
#		color_modulate_tween.kill()
	var play: bool = false
	
	if time != 0:
		if not tween is SceneTreeTween:
			tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_LINEAR)
		
		tween.set_parallel(true).pause()
	
	var aux
	for node in get_tree().get_nodes_in_group(group):
		if node is CanvasItem:
			aux = _set_modulate_color(node, colors, time, tween)
			play = play or aux
	
	theme_by_modulate_groups[group] = colors
	if play: # Roundabout way to check if tween has any tweeners 
		tween.play()
		


func _set_modulate_color(node: CanvasItem, color_dict: Dictionary, time: float, 
tween: SceneTreeTween) -> bool:
	var added_tweener: bool = false
	var target_color = color_dict.get(node.modulate.a8)
	if not target_color is Color:
		return added_tweener
	
	if time == 0 or tween == null:
		node.modulate = target_color
	else:
		tween.tween_property(node, "modulate", target_color, time)
		added_tweener = true
	
	return added_tweener


func change_theme_colors_by_alpha(theme: Theme, style_colors: Dictionary, 
type_colors: Dictionary, time: float = 0, tween = null):
#	if color_theme_tween != null and color_theme_tween.is_running() and time != 0:
#		color_theme_tween.kill()
	
	var play: bool = false
	if time != 0:
		if not tween is SceneTreeTween:
			tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_LINEAR)
		
		tween.set_parallel(true).pause()
	
	var stylebox
	var aux
	var done_styleboxes: Dictionary = {}
	for type_name in theme.get_type_list(""):
		for style_name in theme.get_stylebox_list(type_name):
			stylebox = theme.get_stylebox(style_name, type_name)
			if stylebox in done_styleboxes:
				continue
			aux = change_style_colors_by_alpha(stylebox, style_colors, time, tween)
			done_styleboxes[stylebox] = true
			play = play or aux
		
		for color_name in theme.get_color_list(type_name):
			aux = change_theme_type_color_by_alpha(theme, color_name, type_name, 
					type_colors, time, tween)
			play = play or aux
	
	if play: # Roundabout way to check if tween has any tweeners 
		tween.play()


func change_style_colors_by_alpha(style: StyleBox, style_colors: Dictionary, 
time: float = 0, tween = null) -> bool:
	if time != 0:
		if tween == null: 
			tween = create_tween()
			tween.set_trans(Tween.TRANS_LINEAR)
	
	var added_tweener: bool = false
	var aux
	match style.get_class():
		"StyleBoxFlat":
			aux = _set_color_property(style, "bg_color", style_colors, time, tween)
			added_tweener = added_tweener or aux
			aux = _set_color_property(style, "border_color", style_colors, time, tween)
			added_tweener = added_tweener or aux
	
	return added_tweener


func _set_color_property(object: Object, property: String, color_dict: Dictionary, 
time: float, tween: SceneTreeTween) -> bool:
	var added_tweener: bool = false
	var original_color = object.get(property)
	if not original_color is Color:
		return added_tweener
	
	var target_color = color_dict.get(original_color.a8)
	if not target_color is Color:
		return added_tweener
	
	if time == 0:
		object.set(property, target_color)
	elif original_color != target_color:
		tween.tween_property(object, property, target_color, time)
		added_tweener = true
	
	return added_tweener


func change_theme_type_color_by_alpha(theme: Theme, color_name: String, 
type_name: String, color_dict, time: float, tween: SceneTreeTween) -> bool:
	var added_tweener: bool = false
	var original_color = theme.get_color(color_name, type_name)
	var target_color = color_dict.get(original_color.a8)
	if target_color == null:
		return added_tweener
	
	if time == 0:
		#l.p(color_name + " " + str(original_color.a8) + " " + str(target_color.a8))
		theme.set_color(color_name, type_name, target_color)
	elif original_color != target_color:
#		var callable = Callable(self, "_set_theme_color").bind(theme, color_name, type_name)
#		tween.tween_method(callable, original_color, target_color, time)
		added_tweener = true
		tween.tween_method(self, "_set_theme_color", 
				original_color, target_color, time, 
				[theme, color_name, type_name])
	
	return added_tweener


func _set_theme_color(color: Color, theme: Theme, color_name: String, type_name: String):
	theme.set_color(color_name, type_name, color)


# FOCUS MANAGEMENT FUNCTIONS


func connect_ui_group_focus(group_name: String, x_tolerance = 50, y_tolerance = 25):
	var tree = get_tree()
	if tree == null:
		return
	
	yield(get_tree(), "idle_frame")
	l.start_measure()
	var nodes: Array = get_ui_group_nodes(group_name)
	nodes = format_control_nodes(nodes)
	if nodes.empty():
		return
	
	
	connect_up_down(nodes, y_tolerance)
	connect_left_right(nodes, x_tolerance)
	connect_prev_next(nodes)
	l.write_measure('ui connected')


func disconnect_ui_group_focus(group_name: String, prev: bool = true, next: bool = true,
left: bool = true, right: bool = true, up: bool = true, down: bool = true):
	var nodes: Array = get_ui_group_nodes(group_name)
	nodes = format_control_nodes(nodes)
	if nodes.empty():
		return
	
#	var control_node_data: ControlNodeData
	for control_node_data in nodes:
		if prev:
			control_node_data.erase_prev_focus()
		if next:
			control_node_data.erase_next_focus()
		if left:
			control_node_data.erase_left_focus()
		if right:
			control_node_data.erase_right_focus()
		if up:
			control_node_data.erase_up_focus()
		if down:
			control_node_data.erase_down_focus()


func get_ui_group_nodes(group_name: String):
	var tree = get_tree()
	var group_nodes: Array = []
	if tree.has_group(group_name):
		group_nodes = tree.get_nodes_in_group(group_name)
	else:
		l.g("Group '" + group_name + "' doesn't exist.", l.WARNING)
	
	return group_nodes


func format_control_nodes(nodes: Array) -> Array:
	var resul: Array = []
	for node in nodes:
		if node is Control and node.is_visible_in_tree():
			resul.append(ControlNodeData.new(node))
	
	return resul


func connect_up_down(nodes: Array, tolerance: float):
	nodes.sort_custom(self, "sort_ascending_y")
	var size: int = nodes.size()
	var closest_node = null
	
	# connecting the nodes with their focus down node
	for i in range(size):
		closest_node = get_node_by_distance(nodes, i, tolerance, true, false)
		if closest_node != null:
			nodes[i].set_down_focus(closest_node)
	
	# connecting the nodes with their focus up node
	for i in range(size):
		closest_node = get_node_by_distance(nodes, i, tolerance, true, true)
		if closest_node != null:
			nodes[i].set_up_focus(closest_node)


func connect_left_right(nodes: Array, tolerance: float):
	nodes.sort_custom(self, "sort_ascending_x")
	var size: int = nodes.size()
	var closest_node = null
	
	# connecting the nodes with their focus right node
	for i in range(size):
		closest_node = get_node_by_distance(nodes, i, tolerance, false, false)
		if closest_node != null:
			nodes[i].set_right_focus(closest_node)
	# connecting the nodes with their focus left node
	for i in range(size):
		closest_node = get_node_by_distance(nodes, i, tolerance, false, true)
		if closest_node != null:
			nodes[i].set_left_focus(closest_node)


func connect_prev_next(nodes: Array):
	nodes.sort_custom(self, "sort_path")
	var last_pos:int = nodes.size() - 1
	nodes[0].set_prev_focus(nodes[last_pos])
	nodes[last_pos].set_next_focus(nodes[0])
	for i in range(last_pos):
		nodes[i].set_next_focus(nodes[i + 1])
		nodes[i + 1].set_prev_focus(nodes[i])


func get_node_by_distance(formated_nodes: Array, node_num: int, tolerance: float, vertical: bool, reverse: bool):
	var resul
	var node = formated_nodes[node_num]
	if reverse:
		resul = get_closest_node(formated_nodes, node, 0, node_num, vertical, tolerance)
		if resul == null:
			resul = get_farthest_node(formated_nodes, node, node_num + 1, formated_nodes.size(), vertical)
	else:
		resul = get_closest_node(formated_nodes, node, node_num + 1, formated_nodes.size(), vertical, tolerance)
		if resul == null:
			resul = get_farthest_node(formated_nodes, node, 0, node_num, vertical)
	
	return resul



func get_closest_node(nodes: Array, node: ControlNodeData, from: int, to: int, 
vertical: bool, tolerance: float):
	var aux_node
	var lenght
	var shortest_len
	var closest_node = null
	var gap
	for i in range(from, to):
		aux_node = nodes[i]
		# check tolerance
		if vertical:
			gap = abs(node.y - aux_node.y)
			if gap < tolerance:
				continue
		else:
			gap = abs(node.x - aux_node.x)
			if gap < tolerance:
				continue
		
		if vertical:
			lenght = lenght_ratio_biased_closest(node.y - aux_node.y, node.x - aux_node.x)
		else:
			lenght = lenght_ratio_biased_closest(node.x - aux_node.x, node.y - aux_node.y)
		
			
		
		if closest_node == null:
			shortest_len = lenght
			closest_node = aux_node
		elif lenght < shortest_len:
			shortest_len = lenght
			closest_node = aux_node
	
	return closest_node


func get_farthest_node(nodes: Array, node: ControlNodeData, from: int, to: int, vertical: bool):
	var aux_node
	var lenght
	var longest_len 
	var farthest_node = null
	for i in range(from, to):
		aux_node = nodes[i]
		if vertical:
			lenght = lenght_ratio_biased_farthest(node.y - aux_node.y, node.x - aux_node.x)
		else:
			lenght = lenght_ratio_biased_farthest(node.x - aux_node.x, node.y - aux_node.y)
		if farthest_node == null:
			longest_len = lenght
			farthest_node = aux_node
		elif lenght > longest_len:
			longest_len = lenght
			farthest_node = aux_node
	
	return farthest_node




# because on Y the negative means upper, in the result, upper controls are at the beginning
func sort_ascending_y(a: ControlNodeData, b: ControlNodeData): 
	if a.y < b.y:
		return true
	return false


# because on X the negative means left, in the result, left controls are at the beginning
func sort_ascending_x(a: ControlNodeData, b: ControlNodeData): 
	if a.x < b.x:
		return true
	return false


func sort_path(a: ControlNodeData, b: ControlNodeData): 
	if str(a.path) < str(b.path):
		return true
	return false


func biased_squared_lenght(vector: Vector2, x_bias = 1, y_bias = 1):
	return pow(vector.x * x_bias, 2) + pow(vector.y * y_bias, 2)


func lenght_ratio_biased_closest(main: float, sub: float):
	return abs(main) + abs(sub * 3) 
#	return abs(main * 0.5) + pow(sub, 2) 
#	if main < 1.0:
#		return abs(sub) 
#	else: 
#		return abs(sub / (main * main ))


func lenght_ratio_biased_farthest(main: float, sub: float):
	return abs(main) - abs(sub * 3)
	#return abs(main) - pow(sub, 2)







class ControlNodeData extends Reference:
	var screen_position: Vector2
	var x: float
	var y: float
	var path: NodePath
	var node: Control
	var has_focus_up: bool = false
	var has_focus_down: bool = false
	var has_focus_left: bool = false
	var has_focus_right: bool = false
	var has_focus_next: bool = false
	var has_focus_prev: bool = false
	
	
	func _init(control_node: Control):
		node = control_node
		path = node.get_path()
		screen_position = node.global_position
		x = screen_position.x
		y = screen_position.y
	
	func set_up_focus(control_node_data: ControlNodeData):
		node.focus_neighbor_top = control_node_data.path
		has_focus_up = true
		#L.p(node.name + " -> added foucs up")
	
	func set_down_focus(control_node_data: ControlNodeData):
		node.focus_neighbor_bottom = control_node_data.path
		has_focus_down = true
		#L.p(node.name + " -> added foucs down")
	
	func set_right_focus(control_node_data: ControlNodeData):
		node.focus_neighbor_right = control_node_data.path
		has_focus_right = true
		#L.p(node.name + " -> added foucs right")
	
	func set_left_focus(control_node_data: ControlNodeData):
		node.focus_neighbor_left = control_node_data.path
		has_focus_left = true
		#L.p(node.name + " -> added foucs left")
	
	func set_next_focus(control_node_data: ControlNodeData):
		node.focus_next = control_node_data.path
		has_focus_next = true
		#L.p(node.name + " -> added foucs next")
	
	func set_prev_focus(control_node_data: ControlNodeData):
		node.focus_previous = control_node_data.path
		has_focus_prev = true
		#L.p(node.name + " -> added foucs prev")
	
	func erase_up_focus():
		node.focus_neighbor_top = path
		has_focus_up = false
		#L.p(node.name + " -> added foucs up")
	
	func erase_down_focus():
		node.focus_neighbor_bottom = path
		has_focus_down = false
		#L.p(node.name + " -> added foucs down")
	
	func erase_right_focus():
		node.focus_neighbor_right = path
		has_focus_right = false
		#L.p(node.name + " -> added foucs right")
	
	func erase_left_focus():
		node.focus_neighbor_left = path
		has_focus_left = false
		#L.p(node.name + " -> added foucs left")
	
	func erase_next_focus():
		node.focus_next = path
		has_focus_next = false
		#L.p(node.name + " -> added foucs next")
	
	func erase_prev_focus():
		node.focus_previous = path
		has_focus_prev = false
		#L.p(node.name + " -> added foucs prev")






class VisibilityTWeen extends Reference:
	enum types{
		HIDE,
		SHOW,
	}
	var tween: SceneTreeTween = null
	var original_time: float
	var original_visibility: bool
	var initial_delay: float
	var type: int = -1
	var node: Control
	var next_ui_tween: VisibilityTWeen = null
	var is_finished: bool = false
	
	signal control_tween_finished(control_node)
	
	func _init(control_node: Control, time: float, visible: bool, tween_: SceneTreeTween, 
	delay: float = 0):
		tween = tween_
		initial_delay = delay
		tween.connect("finished", self, "_tween_is_finished")
		original_time = time
		original_visibility = visible
		node = control_node
		next_ui_tween = null
		is_finished = false
		if visible:
			type = types.SHOW
#			if time != 0:
			tween.tween_property(node, "modulate:a", 1, time).set_delay(delay)
			tween.pause()
		else:
			type = types.HIDE
#			if time != 0:
			tween.tween_property(node, "modulate:a", 0, time).set_delay(delay)
			tween.pause()
	
	
	func _tween_is_finished():
		is_finished = true
		set_node_visibility()
		if next_ui_tween == null:
			emit_signal("control_tween_finished", node)
		else:
			next_ui_tween.play()
		
		tween.kill()
		tween = null
	
	
	func set_node_visibility():
		match type:
			types.SHOW:
				if is_finished:
					node.modulate.a = 1
			types.HIDE:
				if is_finished:
					node.visible = false
					node.modulate.a = 0
	
	
	func play():
		if type == types.SHOW:
			if not node.visible:
				node.modulate.a = 0
			node.visible = true
		
#		if original_time != 0:
		tween.play()
	
	
	func chain(control_node: Control, time: float, visible: bool, tween_: SceneTreeTween):
		next_ui_tween = VisibilityTWeen.new(control_node, time, visible, tween_)
	
	
	func replace(control_node: Control, time: float, visible: bool, 
	tween_: SceneTreeTween, delay: float = 0, proportional_time: bool = true) -> float:
		# Returns how long it will take to finish the newly replaced tween
		tween.pause()
		if proportional_time:
			time = get_proportinal_remaining_time(time, visible != original_visibility)
		
		if tween.is_connected("finished", self, "_tween_is_finished"):
			tween.disconnect("finished", self, "_tween_is_finished")
		
		tween.kill()
		_init(control_node, time, visible, tween_)
		return time
	
	
	func get_remaining_time():
		return original_time + initial_delay - tween.get_total_elapsed_time()
		
	
	func get_proportinal_remaining_time(time: float, is_inverse_transition: bool):
		if original_time == 0:
			return 0
		
		var remaing_time_proportion = get_remaining_time() / original_time
		if is_inverse_transition:
			return time * (1 - remaing_time_proportion)
		else:
			return time * remaing_time_proportion
	
	
	func is_valid():
		if tween == null:
			return false
		else:
			return tween.is_valid()

