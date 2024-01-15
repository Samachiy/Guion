extends Node


var expression

func _ready():
	expression = Expression.new()


func solve(cue: Cue):
	var string = ''
	for arg in cue._arguments:
		string += arg + ' '
	
	expression.parse(string)
	return expression.execute()



