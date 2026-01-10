extends Node2D

@export_range(1, 1000)
var scaling_factor: int = 100

@export_range(1, 10)
var rings: int = 3

const CORNERS = [PI / 6, 3 * PI / 6, 5 * PI / 6, 7 * PI / 6, 9 * PI / 6, 11 * PI / 6]

var vertices: Array[Vector2] = [Vector2(0, 0)]
var triangles: Array[Vector3i] = []

func _ready() -> void:
	generate_triangles()

func generate_triangles():
	for i: int in range(1, rings + 1):
		# Generate vertices
		for j: int in range(len(CORNERS)):
			var start_angle = CORNERS[j]
			var start_position = Vector2(cos(start_angle), sin(start_angle)) * i
			var end_angle = CORNERS[(j + 1) % len(CORNERS)]
			var end_position = Vector2(cos(end_angle), sin(end_angle)) * i
			
			for k in range(i):
				var vertex_position = start_position.lerp(end_position, float(k) / i)
				vertices.append(vertex_position)
		
		# Generate triangles
		var previous_ring_vertex_count = maxi(1, 6 * (i - 1))
		var current_ring_vertex_count = 6 * i
		var current_ring_start_index = len(vertices) - current_ring_vertex_count
		var previous_ring_start_index = current_ring_start_index - previous_ring_vertex_count
		
		for j: int in range(6):
			var previous_sector_start_index = j * (i - 1)
			var current_sector_start_index = j * i
			
			# Create quads
			for k: int in range(i - 1):
				var index1 = current_ring_start_index + (current_sector_start_index + k) % current_ring_vertex_count
				var index2 = current_ring_start_index + (current_sector_start_index + k + 1) % current_ring_vertex_count
				var index3 = previous_ring_start_index + (previous_sector_start_index + k) % previous_ring_vertex_count
				var index4 = previous_ring_start_index + (previous_sector_start_index + k + 1) % previous_ring_vertex_count

				triangles.append(Vector3i(index1, index2, index3))
				triangles.append(Vector3i(index2, index4, index3))
			
			# Create final triangle
			triangles.append(Vector3i(current_ring_start_index + (current_sector_start_index + i) % current_ring_vertex_count,
				current_ring_start_index + current_sector_start_index + i - 1,
				previous_ring_start_index + (previous_sector_start_index + i - 1) % previous_ring_vertex_count))

func _draw() -> void:
	for v: Vector2 in vertices:
		draw_circle(v * scaling_factor, 5, Color.YELLOW)
	
	draw_circle(Vector2.ZERO, 5, Color.GREEN)
	
	for i in len(triangles):
		var t = triangles[i]
		for j: int in range(3):
			var colour = Color.AQUA if i % 2 == 0 else Color.BLUE
			var width = 5 if i % 2 == 0 else 3
			draw_line(vertices[t[j]] * scaling_factor, vertices[t[(j + 1) % 3]] * scaling_factor, colour, width)
	
	for i: int in range(len(CORNERS)):
		draw_line(Vector2.ZERO, Vector2(cos(CORNERS[i]), sin(CORNERS[i])) * rings * scaling_factor, Color.BLACK)
