class_name OutfitData
extends Resource
## One outfit for the player character (see Outfits for the list).
##   base     which KayKit character's body, arms and legs it wears
##            ("Rogue", "Knight", "Mage", "Barbarian")
##   palette  repaints of that character's palette texture, {cell: Color};
##            cells are "r<row>c<col>" in its 8x4 grid of colour swatches
##   props    [[prop name, bone], ...]: props from props.glb hung on bones
##   hide     base part names not shown (e.g. legs under a long gown)
##   icon     colours for the outfit's picture on the character screen

@export var id := ""
@export var base := "Rogue"
@export var palette := {}
@export var props: Array = []
@export var hide: Array = []
@export var icon: Array = []


static func make(p_id: String, p_base: String, p_palette := {}, p_props: Array = [], p_hide: Array = [], p_icon: Array = []) -> OutfitData:
	var o := OutfitData.new()
	o.id = p_id
	o.base = p_base
	o.palette = p_palette
	o.props = p_props
	o.hide = p_hide
	o.icon = p_icon
	return o
