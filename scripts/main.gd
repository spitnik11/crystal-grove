extends Node2D

const SPEED := 105.0
const MAP_RECT := Rect2(32, 80, 576, 368)
const CRYSTAL_POSITIONS := [Vector2(128, 160), Vector2(512, 150), Vector2(195, 325), Vector2(445, 340), Vector2(320, 245)]
const ROCK_POSITIONS := [Vector2(220, 180), Vector2(420, 205), Vector2(285, 365)]
const SLIME_ROUTES := [[Vector2(150, 235), Vector2(250, 235)], [Vector2(390, 285), Vector2(520, 285)]]

var player: CharacterBody2D
var player_sprite: AnimatedSprite2D
var crystals: Array[Sprite2D] = []
var slimes: Array[Dictionary] = []
var hearts := 3
var collected := 0
var invulnerable := 0.0
var finished := false
var status_label: Label
var gate_label: Label
var result_panel: ColorRect
var result_label: Label


func _ready() -> void:
	_ensure_input_actions()
	_run_self_check()
	RenderingServer.set_default_clear_color(Color("10201c"))
	_build_ground()
	_build_world()
	_build_player()
	_build_hud()
	print("CRYSTAL_GROVE_MVP_READY")
	if OS.get_cmdline_user_args().has("--mvp-test"):
		_run_mvp_test.call_deferred()


func _physics_process(delta: float) -> void:
	if finished:
		return
	invulnerable = maxf(0.0, invulnerable - delta)
	_update_player()
	_update_slimes(delta)
	_collect_crystals()
	_check_gate()


func _run_self_check() -> void:
	for path in ["ground.png", "tree.png", "rock.png", "crystal.png", "house.png", "swordsman_walk.png", "slime_walk.png"]:
		assert(ResourceLoader.exists("res://third_party/%s" % path), "Run tools/setup-assets.ps1 first: %s" % path)
	assert(CRYSTAL_POSITIONS.size() == 5)
	assert(SLIME_ROUTES.size() == 2)


func _run_mvp_test() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		assert(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty())
	for animation in ["front", "back", "left", "right"]:
		assert(player_sprite.sprite_frames.has_animation(animation))
	for position in CRYSTAL_POSITIONS:
		player.position = position
		_collect_crystals()
	assert(collected == 5 and crystals.is_empty())
	player.position = Vector2(320, 100)
	_check_gate()
	assert(finished)
	finished = false
	hearts = 1
	invulnerable = 0.0
	player.position = slimes[0].node.position
	_update_slimes(0.0)
	assert(hearts == 0 and finished)
	print("CRYSTAL_GROVE_MVP_TEST_PASSED")
	get_tree().quit()


func _build_ground() -> void:
	var texture := load("res://third_party/ground.png")
	for y in range(2, 15):
		for x in range(20):
			var tile := Sprite2D.new()
			tile.texture = texture
			tile.position = Vector2(x * 32 + 16, y * 32 + 16)
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.z_index = -10
			add_child(tile)


func _build_world() -> void:
	var world := Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	for x in range(32, 609, 64):
		_add_prop(world, "tree.png", Vector2(x, 82), 0.5)
		_add_prop(world, "tree.png", Vector2(x, 448), 0.5)
	for y in range(130, 430, 64):
		_add_prop(world, "tree.png", Vector2(34, y), 0.5)
		_add_prop(world, "tree.png", Vector2(606, y), 0.5)
	for position in ROCK_POSITIONS:
		_add_prop(world, "rock.png", position, 0.75)
	var house := _add_prop(world, "house.png", Vector2(320, 112), 0.75)
	house.z_index = 112
	for position in CRYSTAL_POSITIONS:
		var crystal := _add_prop(world, "crystal.png", position, 1.0)
		crystals.append(crystal)
	for route in SLIME_ROUTES:
		var slime := AnimatedSprite2D.new()
		slime.sprite_frames = _sheet_frames("res://third_party/slime_walk.png", 8, ["front", "back", "left", "right"])
		slime.animation = "front"
		slime.play()
		slime.position = route[0]
		slime.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		world.add_child(slime)
		slimes.append({"node": slime, "a": route[0], "b": route[1], "forward": true})


func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2(320, 405)
	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = _sheet_frames("res://third_party/swordsman_walk.png", 6, ["left", "right", "front", "back"])
	player_sprite.animation = "front"
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(player_sprite)
	add_child(player)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color("d91c2625")
	panel.position = Vector2(12, 10)
	panel.size = Vector2(616, 52)
	canvas.add_child(panel)
	var title := _label("CRYSTAL GROVE", Vector2(26, 22), 20, Color("f3d58a"))
	canvas.add_child(title)
	status_label = _label("", Vector2(245, 22), 17, Color("f4f0dc"))
	canvas.add_child(status_label)
	gate_label = _label("Gate sealed", Vector2(498, 22), 16, Color("e69b7b"))
	canvas.add_child(gate_label)
	var help_panel := ColorRect.new()
	help_panel.color = Color("c91c2625")
	help_panel.position = Vector2(138, 444)
	help_panel.size = Vector2(364, 28)
	canvas.add_child(help_panel)
	canvas.add_child(_label("ARROWS / WASD MOVE  •  COLLECT 5  •  AVOID SLIMES", Vector2(142, 449), 13, Color("f3d58a")))
	result_panel = ColorRect.new()
	result_panel.color = Color("ed1c2625")
	result_panel.position = Vector2(145, 185)
	result_panel.size = Vector2(350, 110)
	result_panel.visible = false
	canvas.add_child(result_panel)
	result_label = _label("", Vector2(18, 20), 20, Color("f3d58a"))
	result_label.size = Vector2(314, 76)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_panel.add_child(result_label)
	_update_hud()


func _update_player() -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if wasd != Vector2.ZERO:
		input = wasd
	player.velocity = input * SPEED
	if input != Vector2.ZERO:
		var old_position := player.position
		player.move_and_slide()
		player.position.x = clampf(player.position.x, MAP_RECT.position.x, MAP_RECT.end.x)
		player.position.y = clampf(player.position.y, MAP_RECT.position.y, MAP_RECT.end.y)
		if _blocked(player.position):
			player.position = old_position
		_set_direction(input)
		player_sprite.play()
	else:
		player_sprite.stop()
		player_sprite.frame = 0


func _set_direction(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		player_sprite.animation = "right" if direction.x > 0 else "left"
	else:
		player_sprite.animation = "front" if direction.y > 0 else "back"


func _blocked(position: Vector2) -> bool:
	if position.y < 135.0 and absf(position.x - 320.0) < 75.0:
		return collected < 5 or absf(position.x - 320.0) > 32.0
	for rock in ROCK_POSITIONS:
		if position.distance_to(rock) < 30.0:
			return true
	return false


func _update_slimes(delta: float) -> void:
	for slime_data in slimes:
		var slime: AnimatedSprite2D = slime_data.node
		var target: Vector2 = slime_data.b if slime_data.forward else slime_data.a
		slime.position = slime.position.move_toward(target, 48.0 * delta)
		if slime.position.distance_to(target) < 1.0:
			slime_data.forward = not slime_data.forward
		slime.animation = "right" if target.x > slime.position.x else "left"
		if invulnerable <= 0.0 and player.position.distance_to(slime.position) < 29.0:
			hearts -= 1
			invulnerable = 1.2
			player.position = Vector2(320, 405)
			player_sprite.modulate = Color("ff8a7a")
			create_tween().tween_property(player_sprite, "modulate", Color.WHITE, 0.35)
			_update_hud()
			if hearts <= 0:
				_finish("The grove overwhelmed you.", false)


func _collect_crystals() -> void:
	for crystal in crystals.duplicate():
		if player.position.distance_to(crystal.position) < 25.0:
			crystals.erase(crystal)
			crystal.queue_free()
			collected += 1
			_update_hud()


func _check_gate() -> void:
	if collected == 5 and player.position.y < 120.0 and absf(player.position.x - 320.0) < 50.0:
		_finish("The grove is restored.", true)


func _finish(message: String, won: bool) -> void:
	finished = true
	result_panel.visible = true
	result_label.text = "%s\nPress ENTER to play again" % message
	result_label.add_theme_color_override("font_color", Color("9ff2c9") if won else Color("f29b8f"))


func _unhandled_key_input(event: InputEvent) -> void:
	if finished and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()


func _update_hud() -> void:
	status_label.text = "Crystals %d/5     Hearts %s" % [collected, "♥".repeat(hearts)]
	gate_label.text = "Gate open" if collected == 5 else "Gate sealed"
	gate_label.add_theme_color_override("font_color", Color("8fe0b0") if collected == 5 else Color("e69b7b"))


func _ensure_input_actions() -> void:
	var bindings := {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)


func _add_prop(parent: Node, file_name: String, position_value: Vector2, scale_value: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://third_party/%s" % file_name)
	sprite.position = position_value
	sprite.scale = Vector2.ONE * scale_value
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite


func _sheet_frames(path: String, columns: int, row_names: Array) -> SpriteFrames:
	var texture: Texture2D = load(path)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in row_names.size():
		var animation_name: String = row_names[row]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 8.0)
		frames.set_animation_loop(animation_name, true)
		for column in columns:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * 64, row * 64, 64, 64)
			frames.add_frame(animation_name, atlas)
	return frames


func _label(text_value: String, position_value: Vector2, size_value: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label
