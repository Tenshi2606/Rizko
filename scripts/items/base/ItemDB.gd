extends Node
# ⚠️ NO USES class_name EN AUTOLOADS

# ============================================
# CREAR ITEMS - CENTRALIZADO
# ============================================

# ❌ REMOVER "static" de TODAS las funciones
func create_item(item_id: String) -> Item:  # 🔧 SIN "static"
	match item_id:
		# Fragmentos de Alma
		"soul_basic":
			return _create_soul_basic()
		"soul_intermediate":
			return _create_soul_intermediate()
		"soul_pure":
			return _create_soul_pure()
		
		# 🆕 MONEDA ÚNICA (Asteriones)
		"asterion":
			return Currency.create_asterion(10)  # Cantidad por defecto
		
		# Consumibles
		"health_potion":
			return _create_health_potion()
		
		_:
			push_warning("⚠️ Item no encontrado en ItemDatabase: ", item_id)
			return null

# ============================================
# FRAGMENTOS DE ALMA
# ============================================

# 🔧 REMOVER "static" de todas las funciones internas
func _create_soul_basic() -> SoulFragment:
	var fragment = SoulFragment.new()
	fragment.id = "soul_basic"
	fragment.name = "Fragmento de Alma Básico"
	fragment.description = "Golpea enemigos 3 veces para curarte 3 HP"
	fragment.fragment_type = SoulFragment.FragmentType.BASIC
	fragment.hits_required = 3
	fragment.max_stack = 5
	fragment.rarity = Item.ItemRarity.COMMON
	return fragment

func _create_soul_intermediate() -> SoulFragment:
	var fragment = SoulFragment.new()
	fragment.id = "soul_intermediate"
	fragment.name = "Fragmento de Alma Intermedio"
	fragment.description = "Golpea enemigos 5 veces para curarte 5 HP"
	fragment.fragment_type = SoulFragment.FragmentType.INTERMEDIATE
	fragment.hits_required = 5
	fragment.max_stack = 5
	fragment.rarity = Item.ItemRarity.UNCOMMON
	return fragment

func _create_soul_pure() -> SoulFragment:
	var fragment = SoulFragment.new()
	fragment.id = "soul_pure"
	fragment.name = "Fragmento de Alma Puro"
	fragment.description = "Golpea enemigos 8 veces para curarte 8 HP"
	fragment.fragment_type = SoulFragment.FragmentType.PURE
	fragment.hits_required = 8
	fragment.max_stack = 5
	fragment.rarity = Item.ItemRarity.EPIC
	return fragment

# ============================================
# CONSUMIBLES
# ============================================

func _create_health_potion() -> Item:
	var potion = Item.new()
	potion.id = "health_potion"
	potion.name = "Poción de Vida"
	potion.description = "Restaura 3 HP instantáneamente"
	potion.max_stack = 5
	potion.rarity = Item.ItemRarity.COMMON
	potion.can_use = true
	return potion

# ============================================
# 🆕 CREAR ASTERIONES CON CANTIDAD ESPECÍFICA
# ============================================

func create_asterion(amount: int) -> Currency:
	return Currency.create_asterion(amount)

# ============================================
# UTILIDADES
# ============================================

func get_all_item_ids() -> Array[String]:
	return [
		"soul_basic",
		"soul_intermediate",
		"soul_pure",
		"asterion",
		"health_potion"
	]

func item_exists(item_id: String) -> bool:
	return get_all_item_ids().has(item_id)

func get_item_info(item_id: String) -> Dictionary:
	var item = create_item(item_id)
	if not item:
		return {}
	
	return {
		"id": item.id,
		"name": item.name,
		"description": item.description,
		"rarity": item.rarity,
		"max_stack": item.max_stack
	}
