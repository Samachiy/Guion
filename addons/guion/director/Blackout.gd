extends ColorRect

onready var animationPlayer = $AnimationPlayer

# VALUES RECEIVED FROM PARENT
var screen_v: int = 1080 setget set_screen_v
var screen_h: int = 1920 setget set_screen_h

signal blackout_started
signal blackout_ended

func refresh_size():
	rect_size.x = screen_h
	rect_size.y = screen_v


func set_screen_v(value):
	screen_v = value
	refresh_size()


func set_screen_h(value):
	screen_h = value
	refresh_size()


func start_blackout():
	animationPlayer.play("startBlackout")


func end_blackout():
	animationPlayer.play("endBlackout")


func _blackout_started():
	emit_signal("blackout_started")


func _blackout_ended():
	emit_signal("blackout_ended")
