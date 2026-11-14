class_name Paint
extends RefCounted
## Paint colours for the planes, in D-pad order. Bright and easy to tell
## apart for a small child. The models' red parts are recoloured to these.

const COLORS: Array[Color] = [
	Color("ff4d4d"),  # red
	Color("3f8cff"),  # blue
	Color("ffd23f"),  # yellow
	Color("4cc06a"),  # green
	Color("9b5de5"),  # purple
	Color("ff7eb9"),  # pink
	Color("ff8c42"),  # orange
	Color("f2f2f2"),  # white
]


static func color(idx: int) -> Color:
	return COLORS[posmod(idx, COLORS.size())]
