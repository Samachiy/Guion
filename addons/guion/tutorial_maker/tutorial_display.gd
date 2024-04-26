extends Control

class_name TutorialDisplay

const DEFAULT_ROLE = 'Tutorial'

export(String) var role_name = DEFAULT_ROLE
export(String, FILE, "*.tscn") var dialog_box
export(String) var dbox_set_text_function = "set_text"
export(String) var dbox_prev_signal = "prev_pressed"
export(String) var dbox_next_signal = "next_pressed"
export(String) var dbox_skip_signal = "skip_pressed"
export(Color) var frame_color = Color.darkred
export(int) var frame_width = 4
export(String, FILE, "*.tscn") var touch_indicator


var dialog_box_packed_scene: PackedScene
var touch_indicator_packed_scene: PackedScene
var biggest_fitting_area: Rect2
var biggest_area: Rect2
var current_dialog: Control
var frames: Array = [] # [[ReferenceRect, ControlNode], ...]

func _ready():
	connect("resized", self, "_on_resized")
	Roles.request_role(self, role_name)
	dialog_box_packed_scene = load(dialog_box)
	touch_indicator_packed_scene = load(touch_indicator)
	#display_box("test", false, false)


func is_running(_cue: Cue = null):
	return visible


func clear(_cue: Cue = null):
	for child in get_children():
		child.queue_free()
	
	frames.resize(0)


func connect_box(box: Object, receiver_object: Object):
	box.connect(dbox_prev_signal, receiver_object, "_on_prev_pressed")
	box.connect(dbox_next_signal, receiver_object, "_on_next_pressed")
	box.connect(dbox_skip_signal, receiver_object, "_on_skip_pressed")


func _on_resized():
	yield(get_tree(), "idle_frame")
	update_frames()
	update_display_box_rect()


func display_box(text: String, has_prev: bool, has_next: bool, 
allow_skip: bool = true):
	if is_instance_valid(current_dialog):
		current_dialog.queue_free()
	
	var dialog_box_node: Control = dialog_box_packed_scene.instance()
	dialog_box_node.visible = false
	add_child(dialog_box_node)
	move_child(dialog_box_node, 0)
	dialog_box_node.call(dbox_set_text_function, tr(text), has_prev, has_next, allow_skip)
	current_dialog = dialog_box_node
	update_display_box_rect()
	return dialog_box_node


func add_frame(control_node: Control) -> ReferenceRect:
	if control_node == null:
		return null
	
	var rect = control_node.get_global_rect()
	var ref_rect = ReferenceRect.new()
	ref_rect.connect("mouse_entered", self, "_on_disable_mouse_stop")
	ref_rect.connect("mouse_exited", self, "_on_enable_mouse_stop")
	add_child(ref_rect)
	ref_rect.editor_only = false
	ref_rect.border_width = frame_width
	ref_rect.border_color = frame_color
	ref_rect.rect_global_position = rect.position
	ref_rect.rect_size = rect.size
	frames.append([ref_rect, control_node])
	return ref_rect


func update_frames():
	var ref_rect
	var control
	# frame_data = [ReferenceRect, ControlNode]
	for frame_data in frames:
		ref_rect = frame_data[0]
		control = frame_data[1]
		if ref_rect is ReferenceRect and control is Control:
			ref_rect.rect_global_position = control.rect_global_position
			ref_rect.rect_size = control.rect_size


func add_indicator(control_node: Control) -> Control:
	if control_node == null:
		return null
	
	var touch_indicator_node: Control = touch_indicator_packed_scene.instance()
	add_child(touch_indicator_node)
	return touch_indicator_node


func update_display_box_rect():
	# Calculate biggest available area, taking into account margins and existing color frames
	# 	- iterate over the frames
	# 	- each frame creates 4 candidate areas
	# 		- right
	# 		- bottom
	# 		- left
	#		- top
	#	- We check the frames that intersect with the original frame
	#	- if it intersects, substract the area in a way the reduces the area the least
	#		while keeping the central point of the adjoining side of the original frame
	#	- This is done because the resulting area will always adjoin the side of at least
	#		one frame 
	# Click actions will be counted as a frame
	# In drag actions we will just drag over the tutorial box, but the source and target will 
	# count as frames
	if not is_instance_valid(current_dialog):
		return
	
	var child_nodes = []
	for child in get_children():
		if child is ReferenceRect and child.visible:
			child_nodes.append(child)
	
	var rect: Rect2
	var aux_rect: Rect2
	var has_frames: bool = false
	for i in range(child_nodes.size()):
		has_frames = true
		aux_rect = get_biggest_area_with(child_nodes[i], child_nodes)
		if aux_rect.get_area() > rect.get_area():
			rect = aux_rect
	
	if not has_frames:
		rect = get_rect()
	
	yield(get_tree(), "idle_frame")
	if not is_instance_valid(current_dialog):
		return
	
	var margin_offset = (rect.size - current_dialog.rect_size ) / 2
	current_dialog.rect_position = rect.position + margin_offset
	yield(get_tree(), "idle_frame")
	if not is_instance_valid(current_dialog):
		return
	
	current_dialog.visible = true


func get_biggest_area_with(node: Control, nodes: Array):
	var top_left = node.rect_position
	var bot_right = top_left + node.rect_size
	
	# the position and size of the four areas
	var up_pos = Vector2.ZERO
	var down_pos = Vector2(0, bot_right.y)
	var right_pos = Vector2(bot_right.x, 0)
	var left_pos = Vector2.ZERO
	var up_size = Vector2(rect_size.x, top_left.y)
	var down_size = Vector2(rect_size.x, rect_size.y - bot_right.y)
	var right_size = Vector2(rect_size.x - bot_right.x, rect_size.y)
	var left_size = Vector2(top_left.x, rect_size.y)
	
	# the areas themselves
	var up_area = Rect2(up_pos, up_size)
	var down_area = Rect2(down_pos, down_size)
	var right_area = Rect2(right_pos, right_size)
	var left_area = Rect2(left_pos, left_size)
	
	# a rect that represent on side of the node's rect, hence side
	var up_side = Rect2(top_left, Vector2(node.rect_size.x, 0))
	var down_side = Rect2(Vector2(top_left.x, bot_right.y), Vector2(node.rect_size.x, 0))
	var right_side = Rect2(Vector2(bot_right.x, top_left.y), Vector2(0, node.rect_size.y))
	var left_side = Rect2(top_left, Vector2(0, node.rect_size.y))
	
	# a rect that extends from the side to the container margin
	var up_side_rect = up_side.grow_individual(0, up_size.y, 0, 0)
	var down_side_rect = down_side.grow_individual(0, 0, 0, down_size.y)
	var right_side_rect = right_side.grow_individual(0, 0, right_size.x, 0)
	var left_side_rect = left_side.grow_individual(left_size.x, 0, 0, 0)
	
	var resul_area: Rect2
	var aux: Rect2
#	l.p('up')
	aux = _substract_intersections(up_area, node, nodes, up_side, up_side_rect, false)
	if aux.get_area() > resul_area.get_area():
		resul_area = aux
#	l.p('down')
	aux = _substract_intersections(down_area, node, nodes, down_side, down_side_rect, false)
	if aux.get_area() > resul_area.get_area():
		resul_area = aux
#	l.p('left')
	aux = _substract_intersections(left_area, node, nodes, left_side, left_side_rect, true)
	if aux.get_area() > resul_area.get_area():
		resul_area = aux
#	l.p('right')
	aux = _substract_intersections(right_area, node, nodes, right_side, right_side_rect, true)
	if aux.get_area() > resul_area.get_area():
		resul_area = aux
	
	return resul_area


func _substract_intersections(main_rect2: Rect2, node: Control, nodes: Array, side: Rect2, 
side_rect: Rect2, horizontal: bool):
	var aux
	var area = main_rect2
	var common_area: Rect2
	for i in range(nodes.size()):
		if node == nodes[i]:
			continue
		aux = nodes[i].get_rect()
		common_area = area.clip(aux)
		if not common_area.has_no_area():
#			l.p(nodes[i].name)
			area = _substract_rect(area, common_area, side, side_rect, horizontal)
	
	return area


func _substract_rect(main_rect2: Rect2, subs_rect2: Rect2, side: Rect2, side_rect: Rect2, 
horizontal: bool):
	var corner = subs_rect2.position + subs_rect2.size
	var origin = side.get_center()
	var cut_point = _get_cut_point(origin, subs_rect2.position, corner)
	var resul
	if side_rect.intersects(subs_rect2):
		if horizontal:
			resul = _cut_rect(main_rect2, origin, cut_point, true, false)
		else:
			resul = _cut_rect(main_rect2, origin, cut_point, false, true)
	else:
		resul = _cut_rect(main_rect2, origin, cut_point, true, true)
	
	return resul


func _cut_rect(rect2: Rect2, origin: Vector2, cut_point: Vector2, cut_x: bool, cut_y: bool):
	var cut_dir = cut_point - origin
	#var size_to_cut = rect2.size - cut_dir.abs() # here is the problem
	var size_to_cut: Vector2
	var area_a: Rect2
	var area_b: Rect2
	if cut_x:
		if cut_dir.x > 0:
			size_to_cut.x = (rect2.position.x + rect2.size.x) - cut_point.x
			area_a = rect2.grow_individual(0, 0, -size_to_cut.x, 0)
		elif cut_dir.x == 0:
			pass
		else:
			size_to_cut.x = rect2.position.x - cut_point.x 
			area_a = rect2.grow_individual(size_to_cut.x, 0, 0, 0)
	
	if cut_y:
		if cut_dir.y > 0:
			size_to_cut.y = (rect2.position.y + rect2.size.y) - cut_point.y
			area_b = rect2.grow_individual(0, 0, 0, -size_to_cut.y)
		elif cut_dir.y == 0:
			pass
		else:
			size_to_cut.y = rect2.position.y - cut_point.y
			area_b = rect2.grow_individual(0, size_to_cut.y, 0, 0)
	
#	l.p('size to cut: ' + str(size_to_cut) + " by dir: " + str(cut_dir) + 
#	' with rect at' + str(rect2))
	if area_a.get_area() > area_b.get_area():
		return area_a
	else:
		return area_b


func _get_cut_point(origin: Vector2, cut_rect2_pos: Vector2, 
cut_rect2_corner: Vector2):
	var corners: Array = []
	#corners.append(cut_rect2_pos)
	corners.append(cut_rect2_corner)
	corners.append(Vector2(cut_rect2_pos.x, cut_rect2_corner.y))
	corners.append(Vector2(cut_rect2_corner.x, cut_rect2_pos.y))
	var distance = origin.distance_squared_to(cut_rect2_pos)
	var aux
	var point = cut_rect2_pos
	for corner in corners:
		aux = origin.distance_squared_to(corner)
		if aux < distance:
			distance = aux
			point = corner
	
	return point


func _is_in_line_range(line_start, line_len, check_value):
	return check_value > line_start and check_value < (line_start + line_len)


func _on_enable_mouse_stop():
	mouse_filter = MOUSE_FILTER_STOP


func _on_disable_mouse_stop():
	mouse_filter = MOUSE_FILTER_IGNORE


func place_sprite_at(pos: Vector2):
	# This function was made for debugging purposes only, it has nothing to do with 
	# the actual inner workings of this module
	# Since this uses load, it will only work on the IDE, noe as a standalone
	if OS.has_feature("standalone"):
		return
	
	var texture_rect = TextureRect.new()
	add_child(texture_rect)
	texture_rect.texture = load("res://icon.png")
	texture_rect.rect_position = pos


