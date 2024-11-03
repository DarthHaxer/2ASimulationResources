extends Node2D

var map_size = 1
var maps_x = 1
var maps_y = 1

#Make it so when a Boid obj enters a grid it is considered "solved"

func _draw():
	var inv = get_global_transform().inverse()
	draw_set_transform(inv.get_origin(), inv.get_rotation(), inv.get_scale())
	
	for i in range(0,maps_x):
		draw_line(Vector2(i*map_size,get_viewport_rect().size.y), Vector2(i*map_size,0), Color(Color.GREEN))
		
	for i in range(0,maps_y):
		draw_line(Vector2(0,i*map_size), Vector2(get_viewport_rect().size.x,i*map_size), Color(Color.GREEN))
