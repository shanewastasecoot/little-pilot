class_name RecipientData
extends Resource
## Someone you can deliver a parcel to (or, with deliverable off, the
## post office's postie). Looks are built like the player's outfits: a
## KayKit base character with palette repaints and props on bones.

@export var id := ""
## The clothes (OutfitData: base character, palette, props, hidden parts).
@export var look: OutfitData
## The head: [KayKit character, palette repaints {cell: colour}].
@export var head: Array = []
## Where they stand (world x, z) and which way they face (degrees, 0 = -Z north).
@export var spot := Vector2.ZERO
@export var face_deg := 0.0
## Close to the airport post office: the first deliveries go to them.
@export var lesson := false
@export var deliverable := true
## The colour of their beacon and portrait bubble.
@export var colour := Color("ffd23f")


static func make(p_id: String, p_look: OutfitData, p_head: Array, p_spot: Vector2, p_face: float,
		p_colour: Color, p_lesson := false, p_deliverable := true) -> RecipientData:
	var r := RecipientData.new()
	r.id = p_id
	r.look = p_look
	r.head = p_head
	r.spot = p_spot
	r.face_deg = p_face
	r.colour = p_colour
	r.lesson = p_lesson
	r.deliverable = p_deliverable
	return r
