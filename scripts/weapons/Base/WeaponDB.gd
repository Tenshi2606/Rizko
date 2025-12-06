extends Node

# ============================================
# CATÁLOGO DE ARMAS - SOLO 3 ARMAS + BÁSICO
# ============================================
var weapons: Dictionary = {}

func _ready() -> void:
	_initialize_weapons()
	print("🗡️ WeaponDatabase inicializado - ", weapons.size(), " armas")

func _initialize_weapons() -> void:
	# === 3 ARMAS PRINCIPALES ===
	weapons["scythe"] = _create_scythe()           # 1️⃣ Guaraña (melee pesada)
	weapons["m16"] = _create_m16()                 # 2️⃣ M16 (ráfagas)
	weapons["flamethrower"] = _create_flamethrower()  # 3️⃣ Lanzallamas (DOT)

# ============================================
# 1️⃣ GUARAÑA ESPECTRAL - MELEE PESADA
# ============================================

func _create_scythe() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_id = "scythe"
	weapon.weapon_name = "Guaraña Espectral"
	weapon.description = "Guadaña absorbida del alma de un segador. Golpes lentos pero devastadores con alto crítico."
	
	weapon.weapon_type = WeaponData.WeaponType.MELEE
	weapon.base_damage = 10.0        # Daño MUY alto
	weapon.attack_speed_multiplier = 0.8  # Lenta (60% velocidad)
	weapon.attack_range = 25.0       # Rango extendido
	weapon.knockback_force = Vector2(50, 50)  # Knockback fuerte
	
	# 🔥 BONUS DE CRÍTICO ALTO
	weapon.crit_chance_bonus = 0.02    # +2% crítico (20% total)
	weapon.crit_multiplier_bonus = 0.5  # +0.5x daño crítico (2.5x total)
	weapon.lifesteal_bonus = 0         # +0 HP en crítico
	
	# Animaciones específicas de guaraña
	weapon.attack_animation = "attack_scythe"
	weapon.attack_up_animation = "attack_scythe_up"
	weapon.attack_down_animation = "attack_scythe_down"
	
	# Sprite de manos transformadas (opcional)
	weapon.hand_sprite = "res://assets/sprites/weapons/hands_scythe.png"
	
	# Puede romper metal ligero (puertas reforzadas)
	weapon.can_break = WeaponData.BreakableType.METAL_LIGHT
	
	return weapon

# ============================================
# 2️⃣ M16 ESPECTRAL - RÁFAGAS
# ============================================

func _create_m16() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_id = "m16"
	weapon.weapon_name = "M16 Espectral"
	weapon.description = "Rifle de asalto fantasmal. Dispara ráfagas de 3 balas espectrales con alta cadencia."
	
	weapon.weapon_type = WeaponData.WeaponType.RANGED
	weapon.base_damage = 4.0        # Daño moderado por bala
	weapon.attack_speed_multiplier = 0.8
	weapon.attack_range = 350.0      # Rango largo
	weapon.knockback_force = Vector2(50, 20)
	
	# 🔫 CONFIGURACIÓN DE PROYECTIL
	weapon.has_projectile = true
	weapon.projectile_scene = load("res://assets/scenas/weapons/projectiles/bullet.tscn")
	weapon.projectile_speed = 600.0
	weapon.fire_rate = 0.8           # Cooldown entre ráfagas (0.8s)
	weapon.burst_count = 3           # 3 balas por ráfaga
	weapon.burst_delay = 0.12        # 0.12s entre cada bala
	weapon.projectile_piercing = false
	
	# Bonus leve de crítico
	weapon.crit_chance_bonus = 0.0  # +5% crítico
	
	# Animación de disparo
	weapon.attack_animation = "attack_m16"
	
	# Sprite de manos (opcional)
	weapon.hand_sprite = "res://assets/sprites/weapons/hands_m16.png"
	
	# Puede romper madera (cajas, puertas débiles)
	weapon.can_break = WeaponData.BreakableType.WOOD
	
	return weapon

# ============================================
# 3️⃣ LANZALLAMAS ESPECTRAL - DOT (DAÑO CONTINUO)
# ============================================

func _create_flamethrower() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_id = "flamethrower"
	weapon.weapon_name = "Lanzallamas Espectral"
	weapon.description = "Lanza fuego fantasmal que quema a los enemigos con el tiempo. Daño bajo inicial pero acumulativo."
	
	weapon.weapon_type = WeaponData.WeaponType.RANGED
	weapon.base_damage = 3.0         # Daño bajo por proyectil
	weapon.attack_speed_multiplier = 0.5
	weapon.attack_range = 150.0      # Rango corto
	weapon.knockback_force = Vector2(80, -30)  # Knockback débil
	
	# 🔥 CONFIGURACIÓN DE PROYECTIL CON DOT
	weapon.has_projectile = true
	weapon.projectile_scene = load("res://assets/scenas/weapons/projectiles/flame.tscn")
	weapon.projectile_speed = 250.0   # Más lento que balas
	weapon.fire_rate = 0.1            # Dispara MUY rápido (stream de fuego)
	weapon.burst_count = 1            # 1 llama por click
	weapon.burst_delay = 0.0
	weapon.projectile_piercing = false
	
	# 🔥 EFECTO DOT (DAMAGE OVER TIME)
	weapon.has_dot = true
	weapon.dot_damage = 3.0          # 3 de daño por segundo
	weapon.dot_duration = 3.0        # Quema durante 3 segundos
	
	# Sin bonus de crítico
	weapon.crit_chance_bonus = 0.0
	
	# Animación de disparo
	weapon.attack_animation = "attack_flamethrower"
	
	# Sprite de manos (opcional)
	weapon.hand_sprite = "res://assets/sprites/weapons/hands_flamethrower.png"
	
	# Puede derretir hielo (puertas congeladas)
	weapon.can_break = WeaponData.BreakableType.ICE
	
	return weapon

# ============================================
# UTILIDADES
# ============================================

func get_weapon(weapon_id: String) -> WeaponData:
	if weapons.has(weapon_id):
		return weapons[weapon_id]
	push_warning("⚠️ Arma no encontrada: ", weapon_id)
	return null

func get_all_weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in weapons.keys():
		ids.append(key)
	return ids

func weapon_exists(weapon_id: String) -> bool:
	return weapons.has(weapon_id)

# Imprimir catálogo (debug)
func print_weapon_catalog() -> void:
	print("=== CATÁLOGO DE ARMAS ===")
	for weapon_id in weapons.keys():
		var weapon = weapons[weapon_id]
		print("  🗡️ ", weapon.weapon_name, " (", weapon_id, ")")
		print("     Tipo: ", weapon.weapon_type)
		print("     Daño: ", weapon.base_damage)
	print("========================")
