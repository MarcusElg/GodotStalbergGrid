extends Node2D

@export_range(1, 1000)
var scaling_factor: int = 100

@export_range(1, 10)
var rings: int = 3

const CORNERS = [PI / 6, 3 * PI / 6, 5 * PI / 6, 7 * PI / 6, 9 * PI / 6, 11 * PI / 6]

var vertices = [Vector2(0, 0)]
var triangles = []

func _ready() -> void:
	generate_triangles()

func generate_triangles():
	for i in range(1, rings + 1):
		for j in range(len(CORNERS)):
			var start_angle = CORNERS[j]
			var start_position = Vector2(cos(start_angle), sin(start_angle)) * i
			var end_angle = CORNERS[(j + 1) % len(CORNERS)]
			var end_position = Vector2(cos(end_angle), sin(end_angle)) * i
			
			for k in range(i):
				var vertex_position = start_position.lerp(end_position, float(k) / i)
				vertices.append(vertex_position)

func _draw() -> void:
	for v in vertices:
		draw_circle(v * scaling_factor, 5, Color.YELLOW)
