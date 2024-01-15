extends TextureRect

onready var viewport = $SubViewport

var prev_focus_owner: Control = self


func _ready():
# warning-ignore:return_value_discarded
	get_viewport().connect("gui_focus_changed", self, "_on_focus_changed2")
	viewport.connect("gui_focus_changed", self, "_on_focus_changed")
	pass


func _on_focus_changed(control:Control) -> void:
	print(control.name + ": stage: " + str(control.get_path()))
	prev_focus_owner = control


func _on_focus_changed2(control:Control) -> void: 
	print(control.name + ": root:" + str(control.get_path()))
	prev_focus_owner = control


func _input(event):
	# <PENDING fix this menu thing, < means delayed until this is it's own repo
	if not event is InputEventMouse: # and not Menu.is_open:
		viewport.input(event)


func _on_Screen_gui_input(event):
	# <PENDING fix this menu thing, < means delayed until this is it's own repo
#	if Menu.is_open and event is InputEventMouseButton:
#		Menu.close_menu()
#	else:
	viewport.input(event)
