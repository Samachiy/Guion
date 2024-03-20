extends Node

class_name TutorialOrganizer

const TUTORIAL_METHOD = "_tutorial"

var subscriptions: Dictionary = {}

func subscribe(requesting_object: Object, id: String):
	var subscription = subscriptions.get(id, null)
	if not subscription is TutorialSubscription:
		subscription = TutorialSubscription.new(id)
	
	subscription.connect("prepare_requested", requesting_object, TUTORIAL_METHOD)
	subscriptions[id] = subscription


func prepare(id: String, step_names: Array = []):
	var tutorial_seq = TutorialSequence.new(step_names, id)
	var subscription = subscriptions.get(id, null)
	if subscription is TutorialSubscription:
		subscription.prepare(tutorial_seq)
	else:
		l.g("Can't prepare tutorial of id: " + id)


func start(id: String):
	var subscription = subscriptions.get(id, null)
	if subscription is TutorialSubscription:
		subscription.start()
	else:
		l.g("Can't start tutorial of id: " + id)


func reset_by_flags(tutorial_flags: Array):
	Flags.remove(Cue.new('', '').args(tutorial_flags))


func cancel(id: String):
	var sub = subscriptions.get(id, null)
	if sub is TutorialSubscription:
		sub.cancel()


func cancel_all():
	for sub in subscriptions:
		if sub is TutorialSubscription:
			sub.cancel()




class TutorialSubscription extends Reference:
	
	signal prepare_requested(tutorial_sequence)
	
	var id
	var sequence: TutorialSequence = null
	var started: bool = false
	var completed: bool = false
	
	func _init(subscription_id: String):
		id = subscription_id
	
	func prepare(tutorial_sequence: TutorialSequence):
		sequence = tutorial_sequence
		sequence.connect("sequence_completed", self, "_on_sequence_completed")
		emit_signal("prepare_requested", tutorial_sequence)
	
	
	func start():
		if is_instance_valid(sequence):
			sequence.start()
			started = true
		else:
			l.g("Can't start tutorial sequence of id: " + id)
	
	
	func cancel():
		if is_instance_valid(sequence):
			sequence.cancel()
			started = false
	
	
	func _on_sequence_completed(_name):
		completed = true
