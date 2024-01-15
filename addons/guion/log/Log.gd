tool
extends Node

const CONNECTION_FAILED = "Connection failed. "

enum {
	INFO,
	WARNING,
	ERROR,
	PRINT
}


var time_before
var total_time
var log_array
var log_size = 50

export var print_lop_stack: bool = false
export var print_info_logs: bool = true
export var push_errors_and_warnings: bool = false
export var output_errors_and_warnings: bool = true

signal log_changed

func g(message: String, log_level = ERROR):
	var m: String
	var logged = true
	match log_level:
		WARNING:
			m = "WARNING: "
			m += message
			if push_errors_and_warnings:
				push_warning(m)
			if output_errors_and_warnings:
				print(m)
		ERROR:
			m = "ERROR: "
			m += message
			if push_errors_and_warnings:
				push_error(m)
			if output_errors_and_warnings:
				printerr(m)
		PRINT:
			print("> " + message)
		INFO:
			m = "INFO: "
			m += message
			if print_info_logs:
				print(m)
		_:
			logged = false
	
	if logged:
		emit_signal("log_changed")


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
