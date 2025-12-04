extends Node
class_name Wallet

signal currency_changed(new_amount: int)  # 🔧 Simplificado para Asterion
signal currency_added(amount: int)
signal currency_spent(amount: int)
signal not_enough_currency(required: int, current: int)

var player: Player
var asteriones: int = 0  # 🔧 Variable directa

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("Wallet debe ser hijo de un Player")
		return
	
	print("💰 Wallet inicializado")
	print_wallet()

# ============================================
# 🔧 AÑADIR ASTERIONES (SIMPLIFICADO)
# ============================================

func add_asteriones(amount: int) -> void:
	if amount <= 0:
		return
	
	asteriones += amount
	print("💰 +", amount, " Asteriones | Total: ", asteriones)
	
	# 🔧 EMITIR SEÑALES (CRÍTICO)
	currency_added.emit(amount)
	currency_changed.emit(asteriones)

# ============================================
# GASTAR ASTERIONES
# ============================================

func spend_asteriones(amount: int) -> bool:
	if amount <= 0:
		return false
	
	if asteriones < amount:
		print("❌ No tienes suficiente Asterion (Necesitas: ", amount, ", Tienes: ", asteriones, ")")
		not_enough_currency.emit(amount, asteriones)
		return false
	
	asteriones -= amount
	print("💸 -", amount, " Asteriones | Restante: ", asteriones)
	
	currency_spent.emit(amount)
	currency_changed.emit(asteriones)
	return true

# ============================================
# CONSULTAS
# ============================================

func get_asteriones() -> int:
	return asteriones

func has_asteriones(amount: int) -> bool:
	return asteriones >= amount

func can_afford(amount: int) -> bool:
	return asteriones >= amount

# ============================================
# COMPATIBILIDAD (para no romper código anterior)
# ============================================

func add_currency(currency_type: String, amount: int) -> void:
	if currency_type == "asterion":
		add_asteriones(amount)
	else:
		push_warning("⚠️ Solo se soporta 'asterion' como moneda")

func spend_currency(currency_type: String, amount: int) -> bool:
	if currency_type == "asterion":
		return spend_asteriones(amount)
	else:
		push_warning("⚠️ Solo se soporta 'asterion' como moneda")
		return false

func get_currency(currency_type: String) -> int:
	if currency_type == "asterion":
		return asteriones
	return 0

# ============================================
# DEBUG
# ============================================

func print_wallet() -> void:
	print("=== 💰 BILLETERA ===")
	print("  Asteriones: ", asteriones)
	print("====================")

# ============================================
# GUARDADO
# ============================================

func serialize() -> Dictionary:
	return {
		"asteriones": asteriones
	}

func deserialize(data: Dictionary) -> void:
	if data.has("asteriones"):
		asteriones = data["asteriones"]
	
	print("💰 Billetera cargada")
	print_wallet()
