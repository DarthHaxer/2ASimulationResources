extends Node2D

@export var max_circles: int = 51  # Max number of circles to maintain
var current_circles: int = 0
var circle_hp = 1
var scaleAmt = 1
# List of colors (red, blue, green)
var colors = [Color(1, 0, 0), Color(0, 0, 1), Color(0, 1, 0)]

# List to store references to circle bodies

# Preload circle textures (you need to provide the path to actual textures)
var circle_texture = preload("res://task_scene/taskObj.png")

# Called when the node enters the scene tree
func _ready():
	# Ensure there are as many unique colors as max_circles
	await(Boids)
	for i in range(max_circles):
		create_circle(colors[i % colors.size()])

# Function to create a circle at a random location with a specified color
var circle_bodies = []

func create_circle(circle_color: Color):
	# Create a new Sprite2D to represent the circle visually
	var circle_visual = Sprite2D.new()
	circle_visual.texture = circle_texture  # Assign the circle texture
	circle_visual.scale = Vector2(scaleAmt, scaleAmt)  # Adjust size based on texture scale

	# Set random position for the circle within the window
	circle_visual.position = Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y)
	
	# Apply the specified modulate color to the texture
	circle_visual.modulate = circle_color

	# Add the visual circle to the main scene (ensure it's added under a parent)
	add_child(circle_visual)
	var boidList = []
	#print("V: ", circle_visual, "hp: ", circle_hp)
	circle_bodies.append([circle_visual, circle_hp, boidList])  # Add an empty list to track boids that interacted
	#print("circ: ", circle_bodies)
	current_circles += 1

# Function to check if a Boid is near enough to a circle
func check_interactions(boid_position: Vector2, boid):
	for circle in circle_bodies:
		if circle[0] != null:
			var dist = circle[0].position.distance_to(boid_position)
			var color_name
			var circle_color = circle[0].modulate
			match circle_color:
				Color(1,0,0):
					color_name = "red"
				Color(0,0,1):
					color_name = "blue"
				Color(0,1,0):
					color_name = "green"
			if dist < 15 * scaleAmt:
				_on_circle_interacted(circle, circle_color, boid)
				if boid.max_task == color_name:  # Within pixels range
					_on_circle_interacted(circle, circle_color, boid)
				else:
					$"..".shoutLocated(color_name, boid.position)

func _on_circle_interacted(circle, circle_color, boid):
	if circle[0] != null and boid.boidID not in circle[2]:  # Check if boidID hasn't interacted yet
		var color_name
		match circle_color:
			Color(1,0,0):
				color_name = "red"
			Color(0,0,1):
				color_name = "blue"
			Color(0,1,0):
				color_name = "green"
		$"../TaskCompletionTracker".tasks_completed[color_name] += 1
		boid.current_result[color_name] += 1
		circle[2].append(boid.boidID)  # Mark the boid as having interacted
		boid.task_count(circle_color)  # Tell the Boid about the interaction
		circle[1] -= 1  # Decrease the HP count
		if circle[1] <= 0:
			circle[0].queue_free()  # Remove the circle
			circle_bodies.erase(circle)  # Remove from tracking list
			current_circles -= 1
			# Respawn a new circle with the same color but at a different position
			create_circle(circle_color)
