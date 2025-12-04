# res://scripts/ui/HealCooldownHUD.gd
extends Control
class_name HealCooldownHUD

@onready var cooldown_label: Label = get_node_or_null("VBoxContainer/CooldownLabel")
@onready var cooldown_progress: ProgressBar = get_node_or_null("VBoxContainer/CooldownProgress")
@onready var fragment_icon: TextureRect = get_node_or_null("VBoxContainer/FragmentIcon")

var inventory: InventoryComponent
var current_player: Player

func _ready() -> void:
	visible = false
	print("⏳ HealCooldownHUD inicializado (esperando jugador...)")

# ============================================
# 🆕 CONECTAR CON JUGADOR
# ============================================

func connect_to_player(player: Player) -> void:
	if not player:
		push_error("❌ Player es null")
		return
	
	current_player = player
	
	inventory = player.get_node_or_null("InventoryComponent") as InventoryComponent
	
	if not inventory:
		push_warning("⚠️ InventoryComponent no encontrado")
		return
	
	# Conectar señales
	if not inventory.heal_cooldown_started.is_connected(_on_heal_cooldown_started):
		inventory.heal_cooldown_started.connect(_on_heal_cooldown_started)
	if not inventory.heal_cooldown_ended.is_connected(_on_heal_cooldown_ended):
		inventory.heal_cooldown_ended.connect(_on_heal_cooldown_ended)
	
	print("✅ HealCooldownHUD conectado al jugador")

func _process(_delta: float) -> void:
	if not inventory or not inventory.is_heal_on_cooldown:
		return
	
	_update_cooldown_display()

# ============================================
# CALLBACKS
# ============================================

func _on_heal_cooldown_started(cooldown_duration: float) -> void:
	visible = true
	
	if cooldown_progress:
		cooldown_progress.max_value = cooldown_duration
		cooldown_progress.value = cooldown_duration
	
	print("⏳ HealCooldownHUD: Cooldown iniciado (", cooldown_duration, "s)")

func _on_heal_cooldown_ended() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	visible = false
	modulate.a = 1.0
	
	print("✅ HealCooldownHUD: Cooldown terminado")

# ============================================
# DISPLAY
# ============================================

func _update_cooldown_display() -> void:
	if not inventory:
		return
	
	var time_remaining = inventory.get_heal_cooldown_remaining()
	
	if cooldown_label:
		cooldown_label.text = "⏳ Curación: %.1fs" % time_remaining
		
		if time_remaining <= 3.0:
			cooldown_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		elif time_remaining <= 5.0:
			cooldown_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
		else:
			cooldown_label.add_theme_color_override("font_color", Color(1, 0.5, 0.3))
	
	if cooldown_progress:
		cooldown_progress.value = time_remaining
		
		var style = StyleBoxFlat.new()
		if time_remaining <= 3.0:
			style.bg_color = Color(0.3, 1, 0.3)
		elif time_remaining <= 5.0:
			style.bg_color = Color(1, 1, 0.3)
		else:
			style.bg_color = Color(1, 0.5, 0.3)
		
		cooldown_progress.add_theme_stylebox_override("fill", style)
	
	if fragment_icon:
		var selected_fragment = inventory.get_selected_fragment()
		if selected_fragment:
			pass
