tool
extends EditorPlugin

var DIRECTOR_AUTOLOAD_NAME = "Director"
var LOG_AUTOLOAD_NAME = "l"
var FLAGS_AUTOLOAD_NAME = "Flags"
var ROLES_AUTOLOAD_NAME = "Roles"
var UI_ORGANIZER_AUTOLOAD_NAME = "UIOrganizer"


func _enter_tree():
	if not Engine.has_singleton(LOG_AUTOLOAD_NAME):
		add_autoload_singleton(LOG_AUTOLOAD_NAME, "res://addons/guion/log/Log.tscn")
		
	if not Engine.has_singleton(FLAGS_AUTOLOAD_NAME):
		add_autoload_singleton(FLAGS_AUTOLOAD_NAME, "res://addons/guion/director/flags.tscn")
		
	if not Engine.has_singleton(ROLES_AUTOLOAD_NAME):
		add_autoload_singleton(ROLES_AUTOLOAD_NAME, "res://addons/guion/director/roles.tscn")
		
	if not Engine.has_singleton(UI_ORGANIZER_AUTOLOAD_NAME):
		add_autoload_singleton(UI_ORGANIZER_AUTOLOAD_NAME, "res://addons/guion/director/ui_organizer.tscn")
		
	if not Engine.has_singleton(DIRECTOR_AUTOLOAD_NAME):
		add_autoload_singleton(DIRECTOR_AUTOLOAD_NAME, "res://addons/guion/director/Director.tscn")
	
#	add_custom_type("ManagerTicket", "Node", 
#			preload("res://addons/guion/manager/ManagedTicket.gd"),
#			preload("res://addons/guion/icons/g1975.png"))


func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_custom_type("ManagerTicket")
	remove_autoload_singleton(DIRECTOR_AUTOLOAD_NAME)
	remove_autoload_singleton(LOG_AUTOLOAD_NAME)
	remove_autoload_singleton(FLAGS_AUTOLOAD_NAME)
	remove_autoload_singleton(ROLES_AUTOLOAD_NAME)
	remove_autoload_singleton(UI_ORGANIZER_AUTOLOAD_NAME)
