extends Node2D

@export
var grid_scene: PackedScene

@export
var camera: Camera2D

@export_range(1, 10)
var rings: int = 3

@export_range(1, 5)
var generation_radius: int = 3 # Radius of grids generated around camera

@export_range(1, 1000)
var scaling_factor: int = 100

@export
var debug_rendering: bool = false

var placed_grids: Dictionary[Vector2i, bool] = {}

func _process(delta: float) -> void:
	# Calculate approximate camera grid position
	var camera_grid_y: int = round(camera.position.y / (3.0 / 2 * rings * scaling_factor))
	var camera_grid_x: int = round(camera.position.x / (sqrt(3.0) * rings * scaling_factor))
	
	# Try to generate grid cells
	for xi: int in range(-generation_radius, generation_radius + 1):
		for yi: int in range(-generation_radius, generation_radius + 1):
			spawn_grid(Vector2i(camera_grid_x + xi, camera_grid_y + yi))

func spawn_grid(position: Vector2i):
	if placed_grids.has(position):
		return
	
	placed_grids[position] = true
	
	var x_index = position.x + 0.5 if position.y % 2 == 0 else position.x
	var x: float = x_index * sqrt(3.0) * rings * scaling_factor
	var y: float = position.y * 3.0 / 2 * rings * scaling_factor
	
	var spawned_scene: Grid = grid_scene.instantiate()
	self.add_child(spawned_scene)
	spawned_scene.global_position = Vector2(x, y)
	
	spawned_scene.scaling_factor = scaling_factor
	spawned_scene.rings = rings
	spawned_scene.debug_rendering = debug_rendering
	spawned_scene.generate()
