tool
extends Node

const CONNECTION_FAILED = "Connection failed. "

enum {
	INFO,
	WARNING,
	ERROR,
	PRINT,
	DEBUG,
	IGNORE,
}


var time_before
var total_time
var log_array
var log_size = 50

export var print_lop_stack: bool = false
export var print_info_logs: bool = true
export var print_debug_logs: bool = true
export var push_errors_and_warnings: bool = false
export var output_errors_and_warnings: bool = true
export var push_eaw_at_release: bool = false
export var output_eaw_at_release: bool = true

var is_release_build: bool = false

signal log_changed


func _ready():
	if OS.has_feature("standalone"):
		# Overriden in order to achieve cleaner logs
		output_errors_and_warnings = output_eaw_at_release
		push_errors_and_warnings = push_eaw_at_release
		is_release_build = true


func g(message: String, log_level = ERROR):
	if is_release_build:
		message = "(" + Time.get_time_string_from_system() + ") " + message
	
	var m: String
	var logged = true
	match log_level:
		WARNING:
			if push_errors_and_warnings:
				push_warning(message)
			m = "WARNING: "
			m += message
			if output_errors_and_warnings:
				print(m)
		ERROR:
			if push_errors_and_warnings:
				push_error(message)
			m = "ERROR: "
			m += message
			if output_errors_and_warnings:
				printerr(m)
		PRINT:
			print("> " + message)
		INFO:
			if is_release_build:
				m = "     - "
			else:
				m = "INFO: "
			m += message
			if print_info_logs:
				print(m)
		DEBUG:
			m = "DEBUG: "
			m += message
			if print_debug_logs:
				print(m)
		IGNORE:
			logged = false
		_:
			logged = false
	
	if logged:
		emit_signal("log_changed")
	
	return message


func get_content():
	var file = File.new()
	var error = file.open("user://logs/godot.log", File.READ)
	if error != OK:
		g("Failure to open log file in Log module.")
		return ''
	
	var content = ''
	while not file.eof_reached():
		content += file.get_line() + '\n'
	
	return content


func p(message):
	if print_lop_stack:
		var stack = get_stack()
		stack.remove(0)
		print(stack)
	
	g(str(message), PRINT)


func start_measure():
	time_before = Time.get_ticks_usec()


func write_measure(note: String = ''):
	total_time = Time.get_ticks_usec() - time_before
	print("Time taken: " + str(total_time))
	print("\t", note)


func error(error_code, metadata: String = '', log_level = WARNING):
	if error_code == OK:
		return
	
	var m = "Error: " + str(error_code) + ". "
	if not metadata.empty():
		m += metadata
	
	g(m, log_level)
