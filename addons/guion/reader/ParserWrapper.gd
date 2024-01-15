extends Node


signal parser_ready(parser)
signal marker_found(marker, indent_level)
signal indentation_change(old_indent, new_indent)
var parser: Parser = Parser.new()

func _ready():
# warning-ignore:return_value_discarded
	parser.connect("indentation_change", self, "_on_indentation_change")
# warning-ignore:return_value_discarded
	parser.connect("marker_found", self, "_on_marker_found")
# warning-ignore:return_value_discarded
	parser.connect("parser_ready", self, "_on_parser_ready")
	parser.emit_signal("parser_ready", parser)


func _on_indentation_change(old_indent, new_indent):
	emit_signal("indentation_change", old_indent, new_indent)

func _on_marker_found(marker, indent_level):
	emit_signal("marker_found", marker, indent_level)

func _on_parser_ready(_parser):
	emit_signal("parser_ready", _parser)
