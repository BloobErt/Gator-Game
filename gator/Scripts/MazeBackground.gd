# SimpleLatticeBackground3D.gd
extends Node3D

# Simple settings
@export var cell_size: int = 32
@export var line_width: int = 2
@export var movement_speed: float = 50.0
@export var background_distance: float = -100.0  # Fixed: negative distance

# Color schemes
var game_colors = {
	"primary": Color("#2a1810"),
	"secondary": Color("#4a2818"),
}

var shop_colors = {
	"primary": Color("#102a18"),
	"secondary": Color("#184a28"),
}

# Current state
var current_colors: Dictionary
var is_shop_mode: bool = false
var movement_direction: float = 1.0

# Simple 3D background
var background_quad: MeshInstance3D
var background_material: ShaderMaterial  # Changed from StandardMaterial3D
var background_texture: ImageTexture
var texture_image: Image
var scroll_offset: float = 0.0

# Texture settings
var texture_width: int = 1280
var texture_height: int = 1280  # Make it square instead of wide and short
var grid_cols: int
var rows_generated: int = 0

# 2D overlay for shop
var canvas_layer: CanvasLayer
var canvas_background: TextureRect

func _ready():
	print("🟢 Simple 3D lattice background starting...")
	
	# Initialize
	current_colors = game_colors.duplicate()
	grid_cols = texture_width / cell_size
	
	# Create simple 3D background
	create_simple_3d_background()
	
	# Create 2D overlay for shop
	create_2d_overlay()
	
	# Start in 3D mode
	set_3d_mode()
	
	print("✅ Simple lattice background ready!")

func create_simple_3d_background():
	print("Creating simple 3D quad...")
	
	# Create quad
	background_quad = MeshInstance3D.new()
	background_quad.name = "SimpleBackgroundQuad"
	add_child(background_quad)
	
	# Calculate proper aspect ratio for square cells
	var texture_aspect = float(texture_width) / float(texture_height)
	
	# Make the quad much larger to fill the camera view
	var world_height = 50.0  # Base this on height instead of width
	var world_width = world_height * texture_aspect  # Width to maintain square cells
	
	# Set up mesh with correct aspect ratio
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(world_width, world_height)
	background_quad.mesh = quad_mesh
	
	print("   Texture size: ", texture_width, "x", texture_height)
	print("   Texture aspect ratio: ", texture_aspect)
	print("   Quad size for proper coverage: ", world_width, " x ", world_height)
	
	# Position behind, NO ROTATION
	background_quad.position = Vector3(0, 0, background_distance)
	
	print("   Quad positioned at: ", background_quad.position)
	
	# Create material with scrolling shader
	background_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = create_scrolling_shader()
	background_material.shader = shader
	
	# Generate lattice texture
	generate_simple_lattice()
	
	# Apply texture
	background_material.set_shader_parameter("lattice_texture", background_texture)
	background_material.set_shader_parameter("scroll_offset", 0.0)
	background_quad.material_override = background_material
	
	# Make sure it's visible
	background_quad.visible = true
	
	print("✅ 3D quad created with proper size for camera coverage")

func create_scrolling_shader() -> String:
	return """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D lattice_texture : source_color, filter_nearest;
uniform float scroll_offset : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 scrolled_uv = UV + vec2(0.0, scroll_offset);
	vec4 tex_color = texture(lattice_texture, scrolled_uv);
	ALBEDO = tex_color.rgb;
	ALPHA = 1.0;
}
"""

func generate_simple_lattice():
	print("Generating perfectly tileable lattice texture...")
	
	# Make texture height a multiple of cell_size for perfect tiling
	var rows_needed = (texture_height / cell_size) + 1
	texture_height = int(rows_needed) * cell_size  # Ensure perfect multiple
	
	# Recalculate grid columns based on current texture width
	grid_cols = texture_width / cell_size
	
	# Create texture
	texture_image = Image.create(texture_width, texture_height, false, Image.FORMAT_RGB8)
	texture_image.fill(current_colors.primary)
	
	print("   Adjusted texture size: ", texture_width, "x", texture_height)
	print("   Cell size: ", cell_size)
	print("   Grid columns: ", grid_cols, " (should see ", int(grid_cols), " squares across)")
	print("   Grid rows: ", texture_height / cell_size)
	
	# Draw simple grid - designed for seamless tiling
	draw_tileable_grid()
	
	# Create texture
	background_texture = ImageTexture.new()
	background_texture.set_image(texture_image)
	
	print("✅ Perfectly tileable lattice texture created")

func draw_tileable_grid():
	print("Drawing perfectly tileable grid...")
	
	var vertical_lines = 0
	var horizontal_lines = 0
	
	# Draw vertical lines (naturally tile horizontally)
	for col in range(int(grid_cols) + 1):
		var x = col * cell_size
		if x < texture_width:
			draw_vertical_line(x)
			vertical_lines += 1
	
	# Draw horizontal lines - CRUCIAL: skip the very bottom line for perfect tiling
	var rows = texture_height / cell_size
	for row in range(int(rows)):  # NOT +1 - this ensures perfect vertical tiling
		var y = row * cell_size
		draw_horizontal_line(y)
		horizontal_lines += 1
	
	print("   Drew ", vertical_lines, " vertical lines and ", horizontal_lines, " horizontal lines")
	print("   Skipped bottom edge for seamless tiling")

func draw_vertical_line(x: int):
	for y in range(texture_height):
		for thickness in range(line_width):
			var line_x = x + thickness
			if line_x < texture_width:
				texture_image.set_pixel(line_x, y, current_colors.secondary)

func draw_horizontal_line(y: int):
	for x in range(texture_width):
		for thickness in range(line_width):
			var line_y = y + thickness
			if line_y < texture_height:
				texture_image.set_pixel(x, line_y, current_colors.secondary)

func create_2d_overlay():
	# Simple 2D overlay for shop mode
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 1
	canvas_layer.visible = false
	add_child(canvas_layer)
	
	canvas_background = TextureRect.new()
	canvas_background.anchor_left = 0
	canvas_background.anchor_top = 0
	canvas_background.anchor_right = 1
	canvas_background.anchor_bottom = 1
	canvas_background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	canvas_background.stretch_mode = TextureRect.STRETCH_TILE
	canvas_layer.add_child(canvas_background)

func _process(delta):
	# Update scroll offset for smooth scrolling effect
	scroll_offset += movement_speed * delta * movement_direction
	
	# Update shader for smooth scrolling (this creates the visual movement)
	if background_material:
		var normalized_offset = fmod(scroll_offset / texture_height, 1.0)
		background_material.set_shader_parameter("scroll_offset", normalized_offset)
	
	# When we've scrolled a full texture height, reset without any generation
	# This creates seamless infinite scrolling since the texture is designed to tile
	if abs(scroll_offset) >= texture_height:
		scroll_offset = fmod(scroll_offset, texture_height)
		print("Seamless texture wrap - no generation needed!")

# Remove all the generation functions since we don't need them anymore!
# The shader handles infinite scrolling automatically with the existing texture

func add_new_lattice_row():
	# Generate less frequently to reduce load
	if Engine.get_process_frames() % 3 != 0:  # Every 3rd frame
		return
	
	print("Adding aligned lattice row...")
	
	# Shift by exactly one cell size to keep alignment
	shift_texture_by_cell()
	
	# Generate one properly aligned row
	generate_aligned_row()
	
	# Update texture
	background_texture.set_image(texture_image)
	background_material.set_shader_parameter("lattice_texture", background_texture)
	
	rows_generated += 1

func shift_texture_by_cell():
	# Shift by exactly cell_size pixels to maintain grid alignment
	var shift_pixels = cell_size
	
	# Create new image
	var new_image = Image.create(texture_width, texture_height, false, Image.FORMAT_RGB8)
	new_image.fill(current_colors.primary)
	
	if movement_direction > 0:  # Moving down - shift content up
		for y in range(shift_pixels, texture_height):
			for x in range(texture_width):
				var target_y = y - shift_pixels
				if target_y >= 0:
					var pixel = texture_image.get_pixel(x, y)
					new_image.set_pixel(x, target_y, pixel)
	else:  # Moving up - shift content down
		for y in range(texture_height - shift_pixels - 1, -1, -1):
			for x in range(texture_width):
				var target_y = y + shift_pixels
				if target_y < texture_height:
					var pixel = texture_image.get_pixel(x, y)
					new_image.set_pixel(x, target_y, pixel)
	
	texture_image = new_image

func generate_aligned_row():
	# Generate exactly one row at the correct edge
	var new_row_y: int
	
	if movement_direction > 0:  # Moving down - add at bottom
		new_row_y = texture_height - cell_size
	else:  # Moving up - add at top
		new_row_y = 0
	
	# Draw complete horizontal line for the row top
	draw_horizontal_line_at_y_aligned(new_row_y)
	
	# Draw all vertical lines for this row (but only this row)
	for col in range(int(grid_cols) + 1):
		var x = col * cell_size
		if x < texture_width:
			draw_vertical_line_segment_aligned(x, new_row_y, new_row_y + cell_size)

func draw_horizontal_line_at_y_aligned(y: int):
	if y >= texture_height or y < 0:
		return
	
	# Draw complete horizontal line
	for x in range(texture_width):
		for thickness in range(line_width):
			var line_y = y + thickness
			if line_y < texture_height and line_y >= 0:
				texture_image.set_pixel(x, line_y, current_colors.secondary)

func draw_vertical_line_segment_aligned(x: int, y_start: int, y_end: int):
	if x >= texture_width or x < 0:
		return
	
	# Draw complete vertical line segment
	for y in range(max(0, y_start), min(texture_height, y_end)):
		for thickness in range(line_width):
			var line_x = x + thickness
			if line_x < texture_width and line_x >= 0:
				texture_image.set_pixel(line_x, y, current_colors.secondary)

func shift_texture_content():
	# Create new image
	var new_image = Image.create(texture_width, texture_height, false, Image.FORMAT_RGB8)
	new_image.fill(current_colors.primary)
	
	# Copy existing content, shifted by one row
	var shift_pixels = cell_size
	
	if movement_direction > 0:  # Moving down - shift content up
		for y in range(shift_pixels, texture_height):
			for x in range(texture_width):
				var source_y = y
				var target_y = y - shift_pixels
				if target_y >= 0 and source_y < texture_height:
					var pixel = texture_image.get_pixel(x, source_y)
					new_image.set_pixel(x, target_y, pixel)
	else:  # Moving up - shift content down
		for y in range(texture_height - shift_pixels - 1, -1, -1):
			for x in range(texture_width):
				var source_y = y
				var target_y = y + shift_pixels
				if target_y < texture_height and source_y >= 0:
					var pixel = texture_image.get_pixel(x, source_y)
					new_image.set_pixel(x, target_y, pixel)
	
	texture_image = new_image

func generate_new_row():
	# Generate new lattice row at the appropriate edge
	var new_row_y: int
	
	if movement_direction > 0:  # Moving down - add new content at bottom
		new_row_y = texture_height - cell_size
	else:  # Moving up - add new content at top
		new_row_y = 0
	
	# Draw horizontal line for new row
	draw_horizontal_line_at_y(new_row_y)
	
	# Draw vertical lines for new row
	for col in range(int(grid_cols) + 1):
		var x = col * cell_size
		if x < texture_width:
			draw_vertical_line_segment(x, new_row_y, new_row_y + cell_size)

func draw_horizontal_line_at_y(y: int):
	if y >= texture_height or y < 0:
		return
	
	for x in range(texture_width):
		for thickness in range(line_width):
			var line_y = y + thickness
			if line_y < texture_height and line_y >= 0:
				texture_image.set_pixel(x, line_y, current_colors.secondary)

func draw_vertical_line_segment(x: int, y_start: int, y_end: int):
	if x >= texture_width or x < 0:
		return
	
	for y in range(max(0, y_start), min(texture_height, y_end)):
		for thickness in range(line_width):
			var line_x = x + thickness
			if line_x < texture_width and line_x >= 0:
				texture_image.set_pixel(line_x, y, current_colors.secondary)

func set_3d_mode():
	if background_quad:
		background_quad.visible = true
	if canvas_layer:
		canvas_layer.visible = false
	print("Switched to 3D background mode")

func set_2d_mode():
	if background_quad:
		background_quad.visible = false
	if canvas_layer:
		canvas_layer.visible = true
		canvas_background.texture = background_texture
	print("Switched to 2D overlay mode")

# Public functions

func enter_shop_mode():
	if is_shop_mode:
		return
	
	is_shop_mode = true
	movement_direction = -1.0
	set_2d_mode()
	
	# Simple rotation
	var tween = create_tween()
	tween.tween_property(canvas_background, "rotation", canvas_background.rotation + PI, 1.5)
	canvas_background.pivot_offset = get_viewport().size / 2
	
	transition_colors(shop_colors)

func exit_shop_mode():
	if not is_shop_mode:
		return
	
	is_shop_mode = false
	movement_direction = 1.0
	
	var tween = create_tween()
	tween.tween_property(canvas_background, "rotation", canvas_background.rotation + PI, 1.5)
	tween.tween_callback(set_3d_mode).set_delay(1.5)
	
	transition_colors(game_colors)

func new_round_rotation():
	# NO ROTATION - but this function exists for GameManager compatibility
	print("new_round_rotation called - background scrolling continues, no rotation")

func transition_colors(new_colors: Dictionary):
	var start_colors = current_colors.duplicate()
	var tween = create_tween()
	
	var update_colors = func(progress: float):
		current_colors.primary = start_colors.primary.lerp(new_colors.primary, progress)
		current_colors.secondary = start_colors.secondary.lerp(new_colors.secondary, progress)
		generate_simple_lattice()
		if background_material:
			background_material.albedo_texture = background_texture
		if canvas_background:
			canvas_background.texture = background_texture
	
	tween.tween_method(update_colors, 0.0, 1.0, 2.0)

func set_custom_colors(primary: Color, secondary: Color):
	var custom_colors = {
		"primary": primary,
		"secondary": secondary
	}
	transition_colors(custom_colors)

func set_movement_speed(new_speed: float):
	movement_speed = new_speed
