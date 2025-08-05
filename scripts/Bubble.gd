extends CharacterBody2D

# Nodes
@onready var letter = $letter
@onready var sprite = $Sprite2D  # Optional: for wobble offset

# Tuning Parameters
const SINK_SPEED = 3.0               # Slow downward drift
const BUOYANCY_STRENGTH = 80.0       # Upward push on tap
const AIR_DRAG_STRENGTH = 200.0      # Strength of drag steering
const DASH_CHARGE_TIME = 1.0         # Seconds to fully charge dash
const DASH_IMPULSE = 400.0           # Power of gust burst
const MAX_SPEED = 180.0              # Cap max speed for floatiness
const FLOAT_STRENGTH = 15.0          # Internal bubble wobble
const FLOAT_FREQUENCY = 2.0          # Wobble frequency
const LETTER_SWAY = 8.0              # How much letter lags behind

# State
var float_time := 0.0
var float_offset := Vector2.ZERO
var float_velocity := Vector2.ZERO

# Touch state
var is_charging_dash := false
var dash_charge := 0.0
var drag_start_pos := Vector2.ZERO
var last_touch_pos := Vector2.ZERO

# Called when the node enters the scene tree
func _ready():
	velocity = Vector2.ZERO
	last_touch_pos = position

# Input handling (touch only)
func _input(event):
	# Handle touch press and release
	if event is InputEventScreenTouch:
		var pos = event.position
		if event.pressed:
			# Finger touched screen — start charging
			drag_start_pos = pos
			last_touch_pos = pos
			is_charging_dash = true
			dash_charge = 0.0
		else:
			# Finger lifted — release action
			if is_charging_dash:
				var release_dir = (pos - drag_start_pos).normalized()
				if dash_charge >= 0.3:
					velocity += release_dir * DASH_IMPULSE * dash_charge
				else:
					velocity.y -= BUOYANCY_STRENGTH * 0.5  # Light buoyancy
				is_charging_dash = false
				dash_charge = 0.0

	# Handle drag position updates (no .pressed here!)
	if event is InputEventScreenDrag:
		last_touch_pos = event.position  # Just update position
		
# Physics update
func _physics_process(delta):
	float_time += delta

	# Handle input logic (charging, drag steering)
	handle_input(delta)

	# Apply floaty physics: drift, damping, max speed
	apply_floaty_physics(delta)

	# Update visual effects
	update_bubble_wobble(delta)
	update_letter_suspension(delta)

	# Move the body
	move_and_slide()

# Handle ongoing input (charging, drag steering)
func handle_input(delta):
	# Continue charging if touch is held
	if is_charging_dash:
		dash_charge = min(dash_charge + delta / DASH_CHARGE_TIME, 1.0)

		# Optional: Use drag to gently steer while charging (air current)
		var drag_vector = (last_touch_pos - drag_start_pos)
		var drag_force = drag_vector * AIR_DRAG_STRENGTH * delta
		velocity.x += drag_force.x * 0.5
		velocity.y += drag_force.y * 0.3  # Less vertical influence

# Apply floaty, graceful physics
func apply_floaty_physics(delta):
	# === Natural slow sink (like losing buoyancy) ===
	velocity.y += SINK_SPEED * delta

	# === Heavy damping for smooth, floaty feel ===
	velocity.x = lerp(velocity.x, 0.0, 0.08)  # Horizontal slows fast
	velocity.y = lerp(velocity.y, 0.0, 0.03)  # Vertical resists but drifts

	# === Cap max speed to prevent runaway ===
	velocity = velocity.limit_length(MAX_SPEED)

# Add organic jellyfish-like wobble to the bubble
func update_bubble_wobble(delta):
	var t = float_time
	var wobble = Vector2(
		sin(t * FLOAT_FREQUENCY * 1.3),
		-cos(t * FLOAT_FREQUENCY) * 0.4
	) * FLOAT_STRENGTH

	float_velocity = (wobble - float_offset) * 0.1
	float_offset += float_velocity * delta

	# Apply wobble as sprite offset (so physics center stays stable)
	if sprite:
		sprite.offset = float_offset

# Make the letter inside react to motion (like floating in gel)
func update_letter_suspension(delta):
	var sway_offset = -velocity * LETTER_SWAY * 0.01
	letter.position = letter.position.lerp(sway_offset, 0.2 * delta * 60.0)
