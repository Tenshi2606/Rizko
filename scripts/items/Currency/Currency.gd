extends Item
class_name Currency

# Solo una variable para cantidad
var amount: int = 10

# ✅ NO LLAMAR A super() - Item no tiene _init()
func _init() -> void:
	can_use = false
	max_stack = 999999
	id = "asterion"
	name = "Asteriones"
	description = "Moneda del reino"
	rarity = ItemRarity.COMMON
	type = ItemType.MATERIAL  # 🆕 Añadido para compatibilidad

# 🆕 CREAR ASTERIONES (cantidad variable)
static func create_asterion(amount_value: int = 10) -> Currency:
	var currency = Currency.new()
	currency.id = "asterion"
	currency.name = "Asteriones"
	currency.description = "%d Asteriones" % amount_value
	currency.amount = amount_value
	currency.rarity = ItemRarity.COMMON
	currency.type = ItemType.MATERIAL
	return currency

# Ícono único
func get_currency_icon() -> String:
	return "⭐"
