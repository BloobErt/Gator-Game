# MazeBackground.gd
extends CanvasLayer

# Maze generation settings
@export var maze_width: int = 64
@export var maze_height: int = 64
@export var cell_size: int = 8
@export var line_width: float = 2.0

# Animation settings
@export var movement_speed: float = 50.0
@export var rotation_duration: float = 1.5
@export var color_transition_duration: float = 2.0

# Color schemes for different states
var game_colors = {
	"primary": Color("#2a1810"),
	"secondary": Color("#4a2818"),
	"accent": Color("#6a3820")
}

var shop_colors = {
	"primary": Color("#102a18"),
	"secondary": Color("#184a28"),
	"accent": Color("#206a38")
}

# Current state
var current_colors: Dictionary
var is_shop_mode: bool = false
var movement_direction: Vector2 = Vector2(1, 1)

# Nodes
var background_texture: ImageTexture
var background_rect: TextureRect
var movement_offset: Vector2 = Vector2.ZERO

# Maze data
var maze_grid: Array[Array] = []

func _ready():
	# Setup the background rect
	setup_background_rect()
	
	# Initialize with game colors
	current_colors = game_colors.duplicate()
	
	# Generate initial maze
	generate_maze()
	create_background_texture()
	
	# Start gentle movement
	start_background_movement()

func setup_background_rect():
	background_rect = TextureRect.new()
	background_rect.name = "BackgroundRect"
	add_child(background_rect)
	
	# Fill the entire screen with some extra space for scrolling
	background_rect.anchor_left = -0.5
	background_rect.anchor_top = -0.5
	background_rect.anchor_right = 1.5
	background_rect.anchor_bottom = 1.5
	
	# Set texture repeat
	background_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	background_rect.stretch_mode = TextureRect.STRETCH_TILE

func generate_maze():
	# Initialize maze grid - true = wall, false = path
	maze_grid = []
	for x in range(maze_width):
		maze_grid.append([])
		for y in range(maze_height):
			maze_grid[x].append(true)
	
	# Generate maze using recursive backtracking
	var stack: Array[Vector2i] = []
	var current = Vector2i(1, 1)
	maze_grid[current.x][current.y] = false
	
	while true:
		var neighbors = get_unvisited_neighbors(current)
		
		if neighbors.size() > 0:
			# Choose random neighbor
			var next = neighbors[randi() % neighbors.size()]
			stack.push_back(current)
			
			# Remove wall between current and next
			var wall = Vector2i(
				(current.x + next.x) / 2,
				(current.y + next.y) / 2
			)
			maze_grid[wall.x][wall.y] = false
			maze_grid[next.x][next.y] = false
			
			current = next
		elif stack.size() > 0:
			current = stack.pop_back()
		else:
			break
	
	# Add some random squiggly connections for more organic feel
	add_squiggly_paths()

func get_unvisited_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0)]
	
	for direction in directions:
		var neighbor = cell + direction
		if (neighbor.x > 0 and neighbor.x < maze_width - 1 and 
			neighbor.y > 0 and neighbor.y < maze_height - 1 and
			maze_grid[neighbor.x][neighbor.y]):
			neighbors.append(neighbor)
	
	return neighbors

func add_squiggly_paths():
	# Add random squiggly connections to make it less rigid
	var squiggle_count = (maze_width * maze_height) / 20
	
	for i in range(squiggle_count):
		var x = randi() % (maze_width - 2) + 1
		var y = randi() % (maze_height - 2) + 1
		
		# Create small squiggly pattern
		if randf() > 0.5:
			maze_grid[x][y] = false
			if x + 1 < maze_width:
				maze_grid[x + 1][y] = false
			if y + 1 < maze_height:
				maze_grid[x][y + 1] = false

func create_background_texture():
	var image = Image.create(maze_width * cell_size, maze_height * cell_size, false, Image.FORMAT_RGBA8)
	
	# Fill with primary color
	image.fill(current_colors.primary)
	
	# Draw maze paths with secondary and accent colors
	for x in range(maze_width):
		for y in range(maze_height):
			if not maze_grid[x][y]:  # This is a path
				draw_squiggly_cell(image, x, y)
	
	# Create texture
	background_texture = ImageTexture.new()
	background_texture.set_image(image)
	background_rect.texture = background_texture

func draw_squiggly_cell(image: Image, grid_x: int, grid_y: int):
	var start_x = grid_x * cell_size
	var start_y = grid_y * cell_size
	
	# Use different colors for variety
	var color = current_colors.secondary
	if randf() > 0.7:
		color = current_colors.accent
	
	# Draw squiggly pattern instead of solid rectangles
	for local_x in range(cell_size):
		for local_y in range(cell_size):
			var world_x = start_x + local_x
			var world_y = start_y + local_y
			
			# Create squiggly effect using sine waves
			var wave_x = sin((world_y + movement_offset.y) * 0.1) * 2
			var wave_y = cos((world_x + movement_offset.x) * 0.1) * 2
			
			var distance_from_center = Vector2(
				local_x - cell_size/2 + wave_x,
				local_y - cell_size/2 + wave_y
			).length()
			
			# Create squiggly paths with varying thickness
			if distance_from_center < line_width + sin((world_x + world_y) * 0.2) * 0.5:
				if world_x < image.get_width() and world_y < image.get_height():
					image.set_pixel(world_x, world_y, color)

func start_background_movement():
	# We'll handle movement in _process instead of using a tween
	pass

func _process(delta):
	# Update movement offset
	movement_offset += movement_direction * movement_speed * delta
	
	# Move the TextureRect itself to create scrolling effect
	background_rect.position += movement_direction * movement_speed * delta
	
	# Reset position when it gets too far to prevent floating point precision issues
	var reset_distance = 1000
	if abs(background_rect.position.x) > reset_distance:
		background_rect.position.x = fmod(background_rect.position.x, reset_distance)
	if abs(background_rect.position.y) > reset_distance:
		background_rect.position.y = fmod(background_rect.position.y, reset_distance)
	
	# Regenerate texture occasionally for animated squiggles (every 30 frames for smooth animation)
	var frame_count = Engine.get_process_frames()
	if frame_count % 30 == 0:
		create_background_texture()

# Public functions for game state changes

func enter_shop_mode():
	if is_shop_mode:
		return
	
	is_shop_mode = true
	
	# Move to positive layer (above other elements)
	layer = 1
	
	# Flip direction
	movement_direction = -movement_direction
	
	# Start rotation and color transition
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 180 degree rotation
	var current_rotation = background_rect.rotation
	tween.tween_property(background_rect, "rotation", current_rotation + PI, rotation_duration)
	tween.tween_property(background_rect, "rotation", current_rotation + PI, rotation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Color transition
	transition_colors(shop_colors)

func exit_shop_mode():
	if not is_shop_mode:
		return
	
	is_shop_mode = false
	
	# Move back to negative layer (behind other elements)
	layer = -1
	
	# Flip direction back
	movement_direction = -movement_direction
	
	# Rotate back and transition colors
	var tween = create_tween()
	tween.set_parallel(true)
	
	var current_rotation = background_rect.rotation
	tween.tween_property(background_rect, "rotation", current_rotation + PI, rotation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Color transition back to game colors
	transition_colors(game_colors)

func new_round_rotation():
	# Quick rotation for new round
	var tween = create_tween()
	var current_rotation = background_rect.rotation
	tween.tween_property(background_rect, "rotation", current_rotation + PI/2, rotation_duration * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)

func transition_colors(new_colors: Dictionary):
	var start_colors = current_colors.duplicate()
	var tween = create_tween()
	
	var update_colors = func(progress: float):
		current_colors.primary = start_colors.primary.lerp(new_colors.primary, progress)
		current_colors.secondary = start_colors.secondary.lerp(new_colors.secondary, progress)
		current_colors.accent = start_colors.accent.lerp(new_colors.accent, progress)
		create_background_texture()
	
	tween.tween_method(update_colors, 0.0, 1.0, color_transition_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func set_custom_colors(primary: Color, secondary: Color, accent: Color):
	var custom_colors = {
		"primary": primary,
		"secondary": secondary,
		"accent": accent
	}
	transition_colors(custom_colors)

# Regenerate maze (for level changes, etc.)
func regenerate_maze():
	generate_maze()
	create_background_texture()

# Adjust movement speed
func set_movement_speed(new_speed: float):
	movement_speed = new_speed
