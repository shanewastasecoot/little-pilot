class_name RecipientData
extends Resource
## Someone you can deliver a parcel to (or, with deliverable off, a post
## office's postie). Looks are built like the player's outfits: a KayKit
## base character with palette repaints and props on bones.

@export var id := ""
## The clothes (OutfitData: base character, palette, props, hidden parts).
@export var look: OutfitData
## The head: [KayKit character, palette repaints {cell: colour}].
@export var head: Array = []
## Where they stand (world x, z) and which way they face (degrees, 0 = -Z north).
@export var spot := Vector2.ZERO
@export var face_deg := 0.0
## Which parcels come first: 0 = a short walk from the airport post office,
## 1 = elsewhere on the main island, 2 = another island (fly and land).
@export var tier := 0
@export var deliverable := true
## The colour of their beacon and portrait bubble.
@export var colour := Color("ffd23f")
## Where they are, as a picture in the bubble: airport, farm, lighthouse,
## city, town, ice, dino, castle.
@export var place := "airport"
## A good place to land the plane for them (tests walk from here).
@export var land_at := Vector2.ZERO


static func make(p_id: String, p_look: OutfitData, p_head: Array, p_spot: Vector2, p_face: float,
		p_colour: Color, p_place: String, p_tier := 0, p_land_at := Vector2.ZERO, p_deliverable := true) -> RecipientData:
	var r := RecipientData.new()
	r.id = p_id
	r.look = p_look
	r.head = p_head
	r.spot = p_spot
	r.face_deg = p_face
	r.colour = p_colour
	r.place = p_place
	r.tier = p_tier
	r.land_at = p_land_at
	r.deliverable = p_deliverable
	return r
