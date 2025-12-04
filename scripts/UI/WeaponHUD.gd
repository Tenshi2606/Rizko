# res://scripts/ui/WeaponHUD.gd
extends Control
class_name WeaponHUD

@onready var weapon_name_label: Label = get_node_or_null("VBoxContainer/WeaponNameLabel")
@onready var ammo_label: Label = get_node_or_null("VBoxContainer/AmmoLabel")
@onready var reload_progress: ProgressBar = get_node_or_null("VBoxContainer/ReloadProgress")
@onready var weapon_icon: TextureRect = get_node_or_null("VBoxContainer/WeaponIcon")

var current_player: Player

func _ready() -> void:
	if reload_progress:
		reload_progress.visible = false
	
	print("🗡️ WeaponHUD inicializado (esperando jugador...)")

# ============================================
# 🆕 CONECTAR CON JUGADOR
# ============================================

func connect_to_player(player: Player) -> void:
	if not player:
		push_error("❌ Player es null")
		return
	
	current_player = player
	
	# Conectar señales del WeaponSystem
	if player.weapon_system:
		if not player.weapon_system.weapon_equipped.is_connected(_on_weapon_equipped):
			player.weapon_system.weapon_equipped.connect(_on_weapon_equipped)
		if not player.weapon_system.weapon_changed.is_connected(_on_weapon_changed):
			player.weapon_system.weapon_changed.connect(_on_weapon_changed)
	
	print("✅ WeaponHUD conectado al jugador")

func _process(_delta: float) -> void:
	if not current_player or not current_player.weapon_system:
		return
	
	_update_weapon_display()
	_update_ammo_display()

# ============================================
# ACTUALIZAR DISPLAYS
# ============================================

func _update_weapon_display() -> void:
	if not current_player:
		return
	
	var weapon = current_player.weapon_system.get_current_weapon()
	
	if not weapon:
		if weapon_name_label:
			weapon_name_label.text = ""
		if weapon_icon:
			weapon_icon.visible = false
		return
	
	if weapon_name_label:
		weapon_name_label.text = weapon.weapon_name
		
		match weapon.weapon_type:
			WeaponData.WeaponType.MELEE:
				weapon_name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
			WeaponData.WeaponType.RANGED:
				weapon_name_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1))
	
	if weapon_icon:
		if weapon.icon:
			weapon_icon.texture = weapon.icon
			weapon_icon.visible = true
		else:
			weapon_icon.visible = false

func _update_ammo_display() -> void:
	if not current_player:
		return
	
	var weapon = current_player.weapon_system.get_current_weapon()
	
	if not weapon:
		if ammo_label:
			ammo_label.visible = false
		if reload_progress:
			reload_progress.visible = false
		return
	
	# Solo mostrar munición para M16
	if weapon.weapon_id == "m16":
		if not ammo_label:
			return
		
		var ammo_info = current_player.weapon_system.get_ammo_info()
		
		if ammo_info["is_reloading"]:
			ammo_label.text = "🔄 Recargando..."
			ammo_label.add_theme_color_override("font_color", Color(1, 0.5, 0))
			
			if reload_progress:
				reload_progress.visible = true
				reload_progress.value = ammo_info["reload_progress"] * 100
		else:
			var current = ammo_info["current"]
			var max_ammo = ammo_info["max"]
			
			ammo_label.text = "💥 %d / %d" % [current, max_ammo]
			
			if current == 0:
				ammo_label.add_theme_color_override("font_color", Color(1, 0, 0))
			elif current <= 1:
				ammo_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
			else:
				ammo_label.add_theme_color_override("font_color", Color(1, 1, 1))
			
			if reload_progress:
				reload_progress.visible = false
		
		ammo_label.visible = true
	else:
		if ammo_label:
			ammo_label.visible = false
		if reload_progress:
			reload_progress.visible = false

# ============================================
# CALLBACKS
# ============================================

func _on_weapon_equipped(_weapon: WeaponData) -> void:
	if not weapon_name_label:
		return
	
	var tween = create_tween()
	tween.tween_property(weapon_name_label, "modulate:a", 0.0, 0.1)
	tween.tween_property(weapon_name_label, "modulate:a", 1.0, 0.1)

func _on_weapon_changed(_old_weapon: WeaponData, _new_weapon: WeaponData) -> void:
	print("🔄 Arma cambiada: ", _old_weapon.weapon_name, " → ", _new_weapon.weapon_name)
