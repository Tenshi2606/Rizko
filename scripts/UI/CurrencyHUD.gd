# res://scripts/ui/CurrencyHUD.gd
extends Control
class_name CurrencyHUD

@export var fade_delay: float = 60.0
@export var fade_duration: float = 1.0

var wallet: Wallet
var current_player: Player
var current_amount: int = 0
var fade_timer: float = 0.0
var is_fading: bool = false
var is_visible_state: bool = false

@onready var currency_label: Label = $CurrencyLabel

func _ready() -> void:
	modulate.a = 0
	is_visible_state = false
	
	# 🎯 CONECTAR A EVENTBUS
	EventBus.currency_collected.connect(_on_currency_collected_event)
	
	print("💰 CurrencyHUD inicializado")

# ============================================
# 🆕 CONECTAR CON JUGADOR
# ============================================

func connect_to_player(player: Player) -> void:
	if not player:
		push_error("❌ Player es null")
		return
	
	current_player = player
	
	wallet = player.get_node_or_null("Wallet") as Wallet
	if not wallet:
		push_warning("⚠️ Player no tiene Wallet component")
		return
	
	# 🎯 SOLO CONECTAR currency_changed PARA ACTUALIZAR DISPLAY
	if not wallet.currency_changed.is_connected(_on_currency_changed):
		wallet.currency_changed.connect(_on_currency_changed)
	
	_update_display()
	
	print("✅ CurrencyHUD conectado al jugador")

# 🎯 LISTENER DE EVENTBUS
func _on_currency_collected_event(amount: int, collector: Node) -> void:
	# Solo mostrar si el collector es el player actual
	if collector != current_player:
		return
	
	print("💰 CurrencyHUD: +", amount, " Asteriones detectado")
	
	_show_hud()
	fade_timer = fade_delay
	is_fading = false

func _process(delta: float) -> void:
	if not is_visible_state:
		return
	
	if fade_timer > 0:
		fade_timer -= delta
		
		if fade_timer <= 0 and not is_fading:
			_start_fade_out()

# ============================================
# CALLBACKS
# ============================================

func _on_currency_changed(new_amount: int) -> void:
	current_amount = new_amount
	_update_display()

# ============================================
# DISPLAY
# ============================================

func _update_display() -> void:
	if not wallet:
		return
	
	var amount = wallet.get_asteriones()
	current_amount = amount
	
	if currency_label:
		currency_label.text = "🪙 " + str(amount) + " Asteriones"

func _show_hud() -> void:
	if is_visible_state:
		return
	
	is_visible_state = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	print("💰 CurrencyHUD: Mostrando")

func _start_fade_out() -> void:
	if is_fading:
		return
	
	is_fading = true
	print("💰 CurrencyHUD: Fade out iniciado")
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished
	
	is_visible_state = false
	is_fading = false
	
	print("💰 CurrencyHUD: Oculto")
