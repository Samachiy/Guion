extends Timer

const DEFAUL_TEXT_SPEED = 0.03

var array: Array = Array()
var cursor: int = 0
var prev_time: float = -1

# VALUES RECEIVED FROM PARENT
var should_wait = false
var text: String = ''
var text_type_int: int = 1

signal finished
signal read_next_char



func set_and_read_line(line_array: Array, time: float = 0):
	extract_text_from_line_array(line_array)
	set_line(line_array)
	start_reading(time)


func start_reading(time):
	# This is done so that the first character/role/cues are read 
	# instantaneously instead of waiting for the timer
	emit_signal("read_next_char")
	# this is_finished() does not hold false because the if the next char is not text,
	# but a cue, and there's no more stuff in that line, it will read all the cues and
	# since there would be no more text, it will stop there, the signal on the is_finishe()
	# makes it check if the text is empty and continue reading if that's the case
	if not is_finished() and not should_wait:
		#L.p("line timer started")
		prev_time = time
		start(time)


func resume():
	if prev_time != -1:
		start_reading(prev_time)
		return true
	# if else, then nothing to resume, since the prev_time is set on start reading on the first
	# place
	return false


func set_line(line_array: Array):
	array = line_array
	cursor = 0


func extract_text_from_line_array(line_array: Array):
	if text_type_int == -1:
		text = ''
		return
	
	# fragment = [content, type]
	for fragment in line_array:
		if not fragment is Array and fragment.size() <= 1:
			continue
		
		if fragment[1] == text_type_int:
			text = fragment[0] + ' '


func is_finished(should_emit_signal: bool = true) -> bool:
	var finish = false
	if array.size() == 0:
		self.stop()
		if should_emit_signal:
			emit_signal("finished")
		finish = true
	
	return finish


func _on_Line_timeout():
	if not is_finished():
		emit_signal("read_next_char")

