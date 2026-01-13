class_name Grid
extends Node2D

@export_range(1, 1000)
var scaling_factor: int = 100

@export_range(1, 10)
var rings: int = 3

@export_range(1, 20)
var smoothing_iterations: int = 10

@export
var debug_rendering: bool = false

const CORNERS = [PI / 6, 3 * PI / 6, 5 * PI / 6, 7 * PI / 6, 9 * PI / 6, 11 * PI / 6]

var vertices: Array[Vector2] = [Vector2(0, 0)]
var triangles: Array[Vector3i] = [] # Vector of vertex indexes
var quads: Array[Vector4i] = [] # Vector of vertex indexes
var border_vertices: Dictionary[int, bool] = {} # Dictionary of vertex indexes

func generate() -> void:
	generate_triangles()
	dissolve_triangles()
	
	var triangle_quads: Array[Vector4i] = subdivide_triangles()
	var quad_quads: Array[Vector4i] = subdivide_quads()
	quads.clear()
	quads.append_array(triangle_quads)
	quads.append_array(quad_quads)
	
	remove_duplicate_vertices()
	var adjacency_list: Dictionary[int, Array] = create_adjacency_list()
	relax_grid(adjacency_list, border_vertices, {})

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
				
				if i == rings:
					border_vertices[len(vertices) - 1] = true
		
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

func dissolve_triangles() -> void:
	# Create lookup table for triangles
	var edge_triangle_lookup: Dictionary[Vector2i, Array] = {}
	var edge_indexes : Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
	var shuffled_edge_index: Array[Vector2i] = edge_indexes.duplicate()
	
	for t: Vector3i in triangles:
		for edge_index: Vector2i in edge_indexes:
			_add_edge_to_triangle_lookup(t[edge_index[0]], t[edge_index[1]], t, edge_triangle_lookup)
	
	# Try to dissolve each triangle
	for triangle: Vector3i in triangles.duplicate():
		shuffled_edge_index.shuffle()
		
		for j: int in len(shuffled_edge_index):
			var edge_list = edge_triangle_lookup[_get_edge_index(triangle[shuffled_edge_index[j][0]], triangle[shuffled_edge_index[j][1]])]
			
			if len(edge_list) < 2:
				continue # No triangle to merge with
			
			var other_triangle = edge_list[0] if edge_list[1] == triangle else edge_list[1]
			var combined_indexes = []
			
			# Create combined quad
			for k: int in range(3):
				if not triangle[k] in combined_indexes:
					combined_indexes.append(triangle[k])
			
			for k: int in range(3):
				if not other_triangle[k] in combined_indexes:
					combined_indexes.append(other_triangle[k])
			
			var quad_center_position: Vector2 = (vertices[combined_indexes[0]] + vertices[combined_indexes[1]] + 
				vertices[combined_indexes[2]] + vertices[combined_indexes[3]]) / 4
			combined_indexes.sort_custom(func(a, b):
				var da := vertices[a] - quad_center_position
				var db := vertices[b] - quad_center_position
				return atan2(da.y, da.x) > atan2(db.y, db.x)
			)
			
			quads.append(Vector4i(combined_indexes[0], combined_indexes[1], combined_indexes[2], combined_indexes[3]))
			
			# Remove triangles
			for edge_index: Vector2i in edge_indexes:
				edge_triangle_lookup[_get_edge_index(triangle[edge_index[0]], triangle[edge_index[1]])].erase(triangle)
				edge_triangle_lookup[_get_edge_index(other_triangle[edge_index[0]], other_triangle[edge_index[1]])].erase(other_triangle)
			
			triangles.erase(triangle)
			triangles.erase(other_triangle)
			
			break

func subdivide_triangles() -> Array[Vector4i]:
	var triangle_quads: Array[Vector4i] = []
	
	for triangle: Vector3i in triangles:
		# Create new vertices
		var center_position: Vector2 = (vertices[triangle[0]] + vertices[triangle[1]] + vertices[triangle[2]]) / 3
		var edge_center_positions: Array[Vector2] = []
		
		for i: int in range(3):
			edge_center_positions.append((vertices[triangle[i]] + vertices[triangle[(i + 1) % 3]]) / 2)
			
		vertices.append(center_position)
		
		for i: int in range(3):
			vertices.append(edge_center_positions[i])
			
			# Vertex created between two border vertices is also a border vertex
			if border_vertices.has(triangle[i]) and border_vertices.has(triangle[(i + 1) % 3]):
				border_vertices[len(vertices) - 1] = true
		
		for i in range(3):
			triangle_quads.append(Vector4i(triangle[i], len(vertices) - (3 - i), len(vertices) - 4, len(vertices) - (1 + (3 - i) % 3)))

	
	triangles.clear()
	
	return triangle_quads

func subdivide_quads() -> Array[Vector4i]:
	var quad_quads: Array[Vector4i] = []
	
	for quad: Vector4i in quads:
		# Create new vertices
		var center_position: Vector2 = (vertices[quad[0]] + vertices[quad[1]] + vertices[quad[2]] + vertices[quad[3]]) / 4
		var edge_center_positions: Array[Vector2] = []
		
		for i: int in range(4):
			edge_center_positions.append((vertices[quad[i]] + vertices[quad[(i + 1) % 4]]) / 2)
		
		vertices.append(center_position)
		
		for i: int in range(4):
			vertices.append(edge_center_positions[i])
			
			# Vertex created between two border vertices is also a border vertex
			if border_vertices.has(quad[i]) and border_vertices.has(quad[(i + 1) % 4]) == true:
				border_vertices[len(vertices) - 1] = true
		
		# Create new quads
		quad_quads.append(Vector4i(quad[0], len(vertices) - 4, len(vertices) - 5, len(vertices) - 1))
		quad_quads.append(Vector4i(quad[1], len(vertices) - 3, len(vertices) - 5, len(vertices) - 4))
		quad_quads.append(Vector4i(quad[2], len(vertices) - 2, len(vertices) - 5, len(vertices) - 3))
		quad_quads.append(Vector4i(quad[3], len(vertices) - 1, len(vertices) - 5, len(vertices) - 2))
		
		for i in range(4):
			quad_quads.append(Vector4i(quad[i], len(vertices) - (4 - i), len(vertices) - 5, len(vertices) - (1 + (4 - i) % 4)))
	
	return quad_quads

func _add_edge_to_triangle_lookup(vertex1: int, vertex2: int, triangle: Vector3i, edge_triangle_lookup: Dictionary[Vector2i, Array]):
	var index = _get_edge_index(vertex1, vertex2)
	var edge_list = edge_triangle_lookup.get(index, [])
	edge_list.append(triangle)
	edge_triangle_lookup[index] = edge_list

func _get_edge_index(vertex1: int, vertex2: int) -> Vector2i:
	var smallest_index = min(vertex1, vertex2)
	var largest_index = max(vertex1, vertex2)
	var index = Vector2i(smallest_index, largest_index)
	
	return index

func remove_duplicate_vertices() -> void:
	var position_index_mapping: Dictionary[Vector2, int] = {}
	var old_to_new_index: Array[int] = []
	var new_vertices: Array[Vector2] = []
	var new_border_vertices: Dictionary[int, bool] = {}

	# Deduplicate vertices
	for i in range(len(vertices)):
		var vertex: Vector2 = vertices[i]
		if vertex in position_index_mapping:
			old_to_new_index.append(position_index_mapping[vertex])
		else:
			var new_index = new_vertices.size()
			position_index_mapping[vertex] = new_index
			old_to_new_index.append(new_index)
			new_vertices.append(vertex)
			
			if border_vertices.has(i):
				new_border_vertices[len(new_vertices) - 1] = true

	vertices = new_vertices
	border_vertices = new_border_vertices

	# Remap quads
	for i in range(len(quads)):
		var quad = quads[i]
		quads[i] = Vector4i(
			old_to_new_index[quad[0]],
			old_to_new_index[quad[1]],
			old_to_new_index[quad[2]],
			old_to_new_index[quad[3]]
		)

func create_adjacency_list() -> Dictionary[int, Array]:
	var adjacency_list: Dictionary[int, Array] = {}
	
	for quad: Vector4i in quads:
		for i: int in range(4):
			_add_edge_to_adjacency_list(quad[i], quad[(i + 1) % 4], adjacency_list)
			_add_edge_to_adjacency_list(quad[(i + 1) % 4], quad[i], adjacency_list)
	
	return adjacency_list

# Laplacian smoothing
func relax_grid(adjacency_list: Dictionary[int, Array], static_vertices1: Dictionary[int, bool], static_vertices2: Dictionary[int, bool]) -> void:
	for i: int in range(smoothing_iterations):
		# Calculate new vertex positions
		var new_vertices: Array[Vector2] = []
		
		for j: int in range(len(vertices)):
			# Don't move border vertices
			if static_vertices1.has(j) or static_vertices2.has(j):
				new_vertices.append(vertices[j])
				continue
			
			var new_position: Vector2 = Vector2.ZERO
			var count: int = 0
			
			for neighbour: int in adjacency_list[j]:
				new_position += vertices[neighbour]
				count += 1
			
			new_position /= count
			new_vertices.append(new_position)
		
		# Apply new vertex positions
		vertices = new_vertices

func _add_edge_to_adjacency_list(vertex1: int, vertex2: int, adjacency_list: Dictionary[int, Array]):
	var neighbours = adjacency_list.get(vertex1, [])
	if not vertex2 in neighbours:
		neighbours.append(vertex2)
	adjacency_list[vertex1] = neighbours

func _find_closest_point_on_segment(start: Vector2, end: Vector2, point: Vector2) -> Vector2:
	var ab: Vector2 = end - start
	var ap: Vector2 = point - start
	
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq == 0.0:
		return start
	
	var t = ap.dot(ab) / ab_len_sq
	t = clamp(t, 0.0, 1.0)
	
	return start + ab * t

func _draw() -> void:
	# Draw triangles
	for i in len(triangles):
		var triangle = triangles[i]
		for j: int in range(3):
			var colour = Color.AQUA if i % 2 == 0 else Color.BLUE
			var width = 5 if i % 2 == 0 else 3
			draw_line(vertices[triangle[j]] * scaling_factor, vertices[triangle[(j + 1) % 3]] * scaling_factor, colour, width)
	
	# Draw quads
	for i in len(quads):
		var quad = quads[i]
		for j: int in range(4):
			draw_line(vertices[quad[j]] * scaling_factor, vertices[quad[(j + 1) % 4]] * scaling_factor, Color.PURPLE, 3)
	
	if debug_rendering:
		# Draw vertices
		for v: Vector2 in vertices:
			draw_circle(v * scaling_factor, 5, Color.YELLOW)
		
		# Draw sectors
		for i: int in range(len(CORNERS)):
			draw_line(Vector2.ZERO, Vector2(cos(CORNERS[i]), sin(CORNERS[i])) * rings * scaling_factor, Color.BLACK, 2)
