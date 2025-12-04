extends Item
class_name SoulFragment

enum FragmentType { BASIC, INTERMEDIATE, PURE }

var fragment_type: FragmentType = FragmentType.BASIC
var hits_required: int = 3

func _init():
	can_use = true

static func create_basic() -> SoulFragment:
	var fragment = SoulFragment.new()
	fragment.id = "soul_fragment_basic"
	fragment.name = "Fragmento de Alma Básico"
	fragment.description = "Permite curar golpeando enemigos (3 golpes máx)"
	fragment.fragment_type = FragmentType.BASIC
	fragment.hits_required = 3
	fragment.max_stack = 5  # 🔧 CAMBIADO de 10 a 5
	fragment.rarity = ItemRarity.COMMON
	return fragment

static func create_intermediate() -> SoulFragment:
	var fragment = SoulFragment.new()
	fragment.id = "soul_fragment_intermediate"
	fragment.name = "Fragmento de Alma Intermedio"
	fragment.description = "Permite curar golpeando enemigos (5 golpes máx)"
	fragment.fragment_type = FragmentType.INTERMEDIATE
	fragment.hits_required = 5
	fragment.max_stack = 5  # 🔧 CAMBIADO de 10 a 5
	fragment.rarity = ItemRarity.UNCOMMON
	return fragment

static func create_pure() -> SoulFragment:
	var fragment = SoulFragment.new()
	fragment.id = "soul_fragment_pure"
	fragment.name = "Fragmento de Alma Puro"
	fragment.description = "Permite curar golpeando enemigos (8 golpes máx)"
	fragment.fragment_type = FragmentType.PURE
	fragment.hits_required = 8
	fragment.max_stack = 5  # 🔧 CAMBIADO de 10 a 5
	fragment.rarity = ItemRarity.EPIC
	return fragment

func use(_player: Player) -> bool:
	return true

func get_rarity_color() -> Color:
	match rarity:
		ItemRarity.COMMON:
			return Color(0.8, 0.8, 0.8)
		ItemRarity.UNCOMMON:
			return Color(0.3, 1, 0.3)
		ItemRarity.RARE:
			return Color(0.3, 0.5, 1)
		ItemRarity.EPIC:
			return Color(0.8, 0.3, 1)
		ItemRarity.LEGENDARY:
			return Color(1, 0.65, 0)
		_:
			return Color(1, 1, 1)
