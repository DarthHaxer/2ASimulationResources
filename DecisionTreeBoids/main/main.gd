extends Node2D
var DEBUG_LOG = false

var trackerLog = false
var dataLog = false
var taskLog = false

var NUM_BOIDS = 75;
var max_group_num = 0;
var active_groups = []
var tasks = 50

var Boids
var DecisionTree

var boids = []
var instantiatedTree

var boid_pos = []
var boid_vel = []

var IMAGE_SIZE = int(ceil(sqrt(NUM_BOIDS)))
var boid_data: Image
var boid_data_texture: ImageTexture

@export_category("Boid Settings")
@export_range(0, 100) var friend_radius = 30.0
@export_range(50, 150) var comm_radius = 50.0
@export_range(0, 50) var avoid_radius = 20.0
@export_range(0, 100) var min_vel = 20.0
@export_range(0, 100) var max_vel = 30.0
@export_range(0, 100) var alignment_factor = 10.0
@export_range(0, 100) var cohesion_factor = 1.0
@export_range(0, 100) var separation_factor = 30.0

@export_category("Rendering")
@export var boid_color = Color(Color.WHITE):
	set(new_color):
		boid_color = new_color
		if is_inside_tree():
			$BoidParticles.process_material.set_shader_parameter("color", boid_color)

enum BoidColorMode {SOLID, HEADING, FRIENDS, BIN, DETECTION, GROUPING}
@export var boid_color_mode: BoidColorMode:
	set(new_color_mode):
		boid_color_mode = new_color_mode
		if is_inside_tree():
			$BoidParticles.process_material.set_shader_parameter("color_mode", boid_color_mode)
			$BoidParticles.process_material.set_shader_parameter("max_boids", NUM_BOIDS)
			$BoidParticles.process_material.set_shader_parameter("num_groups", active_groups.size())

@export var boid_max_friends = 10:
	set(new_max_friends):
		boid_max_friends = new_max_friends
		if is_inside_tree():
			$BoidParticles.process_material.set_shader_parameter("max_friends", boid_max_friends)

@export var boid_scale = Vector2(.5, .5):
	set(new_scale):
		boid_scale = new_scale
		if is_inside_tree():
			$BoidParticles.process_material.set_shader_parameter("scale", boid_scale)

@export var bin_grid = false:
	set(new_grid):
		bin_grid = new_grid
		if is_inside_tree():
			$Grid.visible = bin_grid

@export var map_grid = false:
	set(new_grid):
		map_grid = new_grid
		if is_inside_tree():
			$MapGrid.visible = map_grid

@export_category("Other")
@export var pause = false:
	set(new_value):
		pause = new_value

# GPU Variables
var SIMULATE_GPU = false
var rd: RenderingDevice
var boid_compute_shader: RID
var boid_pipeline: RID
var bindings: Array
var uniform_set: RID

var boid_pos_buffer: RID
var boid_vel_buffer: RID
var params_buffer: RID
var params_uniform: RDUniform
var boid_data_buffer: RID

# BIN Variables
var BIN_SIZE = 128
var BINS = Vector2i.ZERO
var NUM_BINS = 0

# MAP Variables for detection
var MAP_SIZE = 32
var MAPS = Vector2i.ZERO
var NUM_MAPS = 0

var bin_sum_shader: RID
var bin_sum_pipeline: RID
var bin_prefix_sum_shader: RID
var bin_prefix_sum_pipeline: RID
var bin_reindex_shader: RID
var bin_reindex_pipeline: RID

var bin_buffer: RID
var bin_sum_buffer: RID
var bin_prefix_sum_buffer: RID
var bin_index_tracker_buffer: RID
var bin_reindex_buffer: RID
var bin_params_buffer: RID

var tasks_scene
var tasks_node
var data_node

func _ready():

	$AssignedTasks.max_circles = tasks
	tasks_node = $AssignedTasks
	data_node = $DataRecorder
	
	Boids = load("res://main/Boids.gd")
	DecisionTree = $DecisionTree
	
	trainTree("res://boid_data_log.csv", DecisionTree)
	
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH)
	boid_data_texture = ImageTexture.create_from_image(boid_data)

	boid_color = boid_color
	boid_color_mode = boid_color_mode
	boid_max_friends = boid_max_friends
	boid_scale = boid_scale
	map_grid = map_grid
	bin_grid = bin_grid

	BINS = Vector2i(snapped(get_viewport_rect().size.x / BIN_SIZE + .4, 1),
					snapped(get_viewport_rect().size.y / BIN_SIZE + .4, 1))
	NUM_BINS = BINS.x * BINS.y

	$Grid.bin_size = BIN_SIZE
	$Grid.bins_x = BINS.x
	$Grid.bins_y = BINS.y

	MAPS = Vector2i(snapped(get_viewport_rect().size.x / MAP_SIZE + .4, 1),
					snapped(get_viewport_rect().size.y / MAP_SIZE + .4, 1))
	NUM_MAPS = MAPS.x * MAPS.y

	$MapGrid.map_size = MAP_SIZE
	$MapGrid.maps_x = MAPS.x
	$MapGrid.maps_y = MAPS.y

	print(NUM_BINS)

	_generate_boids()

	if DEBUG_LOG:
		print(boid_pos)
		print(boid_vel)
		for i in boids.size():
			print("Boid: ", i, " groupID: ", boids[i].groupID, " Pos: ", boids[i].position, " Vel: ", boids[i].velocity)

	$BoidParticles.amount = NUM_BOIDS
	$BoidParticles.process_material.set_shader_parameter("boid_data", boid_data_texture)

	if SIMULATE_GPU:
		_setup_compute_shader()
		_update_boids_gpu(0)

func _generate_boids():
	for i in NUM_BOIDS:
		var pos = Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y)
		var vel = Vector2(randf_range(-1.0, 1.0) * max_vel, randf_range(-1.0, 1.0) * max_vel)
		var random_integers = []
		for num in range(3):
			random_integers.append(randi_range(20, 150))
		var boid = Boids.new(self, data_node, tasks_node, i, pos, vel, 0, sqrt(pow(get_viewport_rect().size.y, 2) + pow(get_viewport_rect().size.x, 2)), DecisionTree, random_integers)
		boids.append(boid)
		boid_pos = boids.map(func(a): return a["position"])
		boid_vel = boids.map(func(a): return a["velocity"])
		#print("Dist RBG: ", random_integers)

func trainTree(file, tree):
	# Load and split data in CSV file
	var dataset = load_csv_data(file)

	if dataset.size() == 0:
		print("Dataset Load Exception!")
		return
	
	var X = []
	var Y = []
	
	# Process data in batches of three rows
	for i in range(0, dataset.size(), 3):
		# Check if there are at least three rows left
		if i + 2 < dataset.size():
			# Collect columns 2 to 5 for the three rows
			var batch_X = []
			for j in range(i, i + 3):
				batch_X.append_array(dataset[j].slice(1, 5))
			X.append(batch_X)
			Y.append(dataset[i][5])
	#print(X.size(), " ", Y.size())
	DecisionTree.fit(X, Y)
	

func maxDepthDetermination():
	pass

# Function to load data from CSV file
func load_csv_data(file_path: String) -> Array:
	var data = []
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	while file.get_position() < file.get_length():
		var line = file.get_line().strip_edges()
		if line.length() == 0:
			continue  # Skip empty lines
		var row = []
		for value in line.split(","):
			row.append(value.to_float())
		data.append(row)

	file.close()
	return data

func shoutLocated(color, pos):
	match color:
		Color(1, 0, 0):
			color = "red"
		Color(0, 1, 0):
			color = "green"
		Color(0, 0, 1):
			color = "blue"
	for boid in boids:
		if (boid.position - pos).length() < comm_radius:
			if boid.nearest_tasks[color] > pos.normalized():
				boid.nearest_tasks[color] = pos.normalized()
		#print("Shouted: ", color, " at ", pos)

func shoutCompleted(color, task_pos):
	match color:
		Color(1, 0, 0):
			color = "red"
		Color(0, 1, 0):
			color = "green"
		Color(0, 0, 1):
			color = "blue"
	for boid in boids:
		if (boid.position - task_pos).length() < comm_radius:
			if boid.nearest_task[color] == task_pos.normalized():
				boid.nearest_task[color] == Vector2(INF,INF)
				boid.velocity = boid.velocity.rotate(PI)
				boid.findMotivationForGoal(boid.position)

func _process(delta):
	
	get_window().title = "GPU: " + str(SIMULATE_GPU) + " / Boids: " + str(NUM_BOIDS) + " / FPS: " + str(Engine.get_frames_per_second())
	
	if SIMULATE_GPU:
		for i in NUM_BOIDS:
			boids[i].check_task_interaction()

	if SIMULATE_GPU:
		_sync_boids_gpu()
	else:
		_update_boids_cpu(delta)

	#var test_output = rd.buffer_get_data(bin_sum_buffer).to_int32_array()
	#print("bin_sum",test_output)

	_update_data_texture()

	if SIMULATE_GPU:
		_update_boids_gpu(delta)

func _update_boids_cpu(delta):
	if trackerLog == true and dataLog == true and taskLog == true:
		get_tree().quit()
	for i in NUM_BOIDS:
		boids[i].check_task_interaction()
		boids[i].findMotivationForGoal(boids[i].position)
		var my_pos = boids[i].position
		var my_vel = boids[i].velocity
		var avg_vel = Vector2.ZERO
		var midpoint = Vector2.ZERO
		var separation_vec = Vector2.ZERO
		var num_friends = 0
		var num_avoids = 0

		# Reflective boundary behavior
		if my_pos.x < 0 or my_pos.x > get_viewport_rect().size.x or my_pos.y < 0 or my_pos.y > get_viewport_rect().size.y:
			boids[i].velocity = boids[i].velocity.rotated(deg_to_rad(randi_range(90, 270))) # Rotate velocity 90-270 degrees randomly

		if my_pos.x < 0 or my_pos.x > get_viewport_rect().size.x:
			my_vel.x = -my_vel.x # Reverse velocity in x direction
		if my_pos.y < 0 or my_pos.y > get_viewport_rect().size.y:
			my_vel.y = -my_vel.y # Reverse velocity in y direction

		# Boundary correction for offscreen boids
		if my_pos.x < -10:
			my_pos.x = 10
		elif my_pos.x > get_viewport_rect().size.x + 10:
			my_pos.x = get_viewport_rect().size.x - 10
		if my_pos.y < -10:
			my_pos.y = 10
		elif my_pos.y > get_viewport_rect().size.y + 10:
			my_pos.y = get_viewport_rect().size.y - 10

		# Calculate neighbor influence
		for j in NUM_BOIDS:
			if i != j:
				var other_pos = boids[j].position
				var other_vel = boids[j].velocity
				var dist = my_pos.distance_to(other_pos)
				if (dist < friend_radius) and (boids[i].groupID == boids[j].groupID):
					num_friends += 1
					avg_vel += other_vel
					midpoint += other_pos
					for task_est in boids[i].nearest_tasks.keys():
						if boids[j].nearest_tasks[task_est] < boids[i].nearest_tasks[task_est]:
							boids[i].nearest_tasks[task_est] = boids[j].nearest_tasks[task_est]
						if boids[j].nearest_tasks[task_est] > boids[i].nearest_tasks[task_est]:
							boids[i].nearest_tasks[task_est] = boids[j].nearest_tasks[task_est]
				if dist < avoid_radius:
					num_avoids += 1
					separation_vec += my_pos - other_pos

		# Update velocity with alignment, cohesion, and separation
		if num_friends > 0:
			avg_vel /= num_friends
			my_vel += avg_vel.normalized() * alignment_factor
			midpoint /= num_friends
			my_vel += (midpoint - my_pos).normalized() * cohesion_factor

		if num_avoids > 0:
			separation_vec /= num_avoids
			my_vel += separation_vec.normalized() * separation_factor

		# Clamp velocity within min and max
		var vel_mag = my_vel.length()
		vel_mag = clamp(vel_mag, min_vel, max_vel)
		my_vel = my_vel.normalized() * vel_mag
		my_pos += my_vel * delta

		# Apply updated position and velocity
		boids[i].position = my_pos
		boids[i].velocity = my_vel

func _update_boids_gpu(delta):
	boid_pos = boids.map(func(a): return a["position"])
	boid_vel = boids.map(func(a): return a["velocity"])
	rd.free_rid(params_buffer)
	params_buffer = _generate_parameter_buffer(delta)
	params_uniform.clear_ids()
	params_uniform.add_id(params_buffer)
	uniform_set = rd.uniform_set_create(bindings, boid_compute_shader, 0)

	_run_compute_shader(bin_sum_pipeline)
	rd.sync()
	_run_compute_shader(bin_prefix_sum_pipeline)
	rd.sync()
	_run_compute_shader(bin_reindex_pipeline)
	rd.sync()

	_run_compute_shader(boid_pipeline)

func _run_compute_shader(pipeline):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, ceil(NUM_BOIDS / 1024.), 1, 1)
	rd.compute_list_end()
	rd.submit()

func _sync_boids_gpu():
	rd.sync()

func _update_data_texture():
	if SIMULATE_GPU:
		var boid_data_image_data := rd.texture_get_data(boid_data_buffer, 0)
		boid_data.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH, boid_data_image_data)
	else:
		for i in NUM_BOIDS:
			var pixel_pos = Vector2(int(i % IMAGE_SIZE), int(i / float(IMAGE_SIZE)))
			var color = Color(0,0,0)
			boid_data.set_pixel(pixel_pos.x, pixel_pos.y, Color(boids[i].position.x, boids[i].position.y, boids[i].velocity.angle(), 0))

	boid_data_texture.update(boid_data)

func _setup_compute_shader():

	rd = RenderingServer.create_local_rendering_device()

	var shader_file := load("res://compute_shaders/boid_simulation.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	boid_compute_shader = rd.shader_create_from_spirv(shader_spirv)
	boid_pipeline = rd.compute_pipeline_create(boid_compute_shader)

	boid_pos_buffer = _generate_vec2_buffer(boid_pos)
	var boid_pos_uniform = _generate_uniform(boid_pos_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)

	boid_vel_buffer = _generate_vec2_buffer(boid_vel)
	var boid_vel_uniform = _generate_uniform(boid_vel_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)

	params_buffer = _generate_parameter_buffer(0)
	params_uniform = _generate_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)

	var fmt := RDTextureFormat.new()
	fmt.width = IMAGE_SIZE
	fmt.height = IMAGE_SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	var view := RDTextureView.new()
	boid_data_buffer = rd.texture_create(fmt, view, [boid_data.get_data()])
	var boid_data_buffer_uniform = _generate_uniform(boid_data_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 3)

	shader_file = load("res://compute_shaders/bin_sum.glsl")
	shader_spirv = shader_file.get_spirv()
	bin_sum_shader = rd.shader_create_from_spirv(shader_spirv)
	bin_sum_pipeline = rd.compute_pipeline_create(bin_sum_shader)

	shader_file = load("res://compute_shaders/bin_prefix_sum.glsl")
	shader_spirv = shader_file.get_spirv()
	bin_prefix_sum_shader = rd.shader_create_from_spirv(shader_spirv)
	bin_prefix_sum_pipeline = rd.compute_pipeline_create(bin_prefix_sum_shader)

	shader_file = load("res://compute_shaders/bin_reindex.glsl")
	shader_spirv = shader_file.get_spirv()
	bin_reindex_shader = rd.shader_create_from_spirv(shader_spirv)
	bin_reindex_pipeline = rd.compute_pipeline_create(bin_reindex_shader)

	var bin_params_buffer_bytes = PackedInt32Array([BIN_SIZE, BINS.x, BINS.y, NUM_BINS]).to_byte_array()
	bin_params_buffer = rd.storage_buffer_create(bin_params_buffer_bytes.size(), bin_params_buffer_bytes)
	var bin_params_uniform = _generate_uniform(bin_params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)

	bin_buffer = _generate_int_buffer(NUM_BOIDS)
	var bin_buffer_uniform = _generate_uniform(bin_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 5)

	bin_sum_buffer = _generate_int_buffer(NUM_BINS)
	var bin_sum_uniform = _generate_uniform(bin_sum_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 6)

	bin_prefix_sum_buffer = _generate_int_buffer(NUM_BINS)
	var bin_prefix_sum_uniform = _generate_uniform(bin_prefix_sum_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 7)

	bin_index_tracker_buffer = _generate_int_buffer(NUM_BINS)
	var bin_index_tracker_uniform = _generate_uniform(bin_index_tracker_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 8)

	bin_reindex_buffer = _generate_int_buffer(NUM_BOIDS)
	var bin_reindex_uniform = _generate_uniform(bin_reindex_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 9)

	bindings = [boid_pos_uniform,
				boid_vel_uniform,
				params_uniform,
				boid_data_buffer_uniform,
				bin_params_uniform,
				bin_buffer_uniform,
				bin_sum_uniform,
				bin_prefix_sum_uniform,
				bin_index_tracker_uniform,
				bin_reindex_uniform]

func _generate_vec2_buffer(data):
	var data_buffer_bytes := PackedVector2Array(data).to_byte_array()
	var data_buffer = rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)
	return data_buffer

func _generate_int_buffer(size):
	var data = []
	data.resize(size)
	var data_buffer_bytes = PackedInt32Array(data).to_byte_array()
	var data_buffer = rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)
	return data_buffer

func _generate_uniform(data_buffer, type, binding):
	var data_uniform = RDUniform.new()
	data_uniform.uniform_type = type
	data_uniform.binding = binding
	data_uniform.add_id(data_buffer)
	return data_uniform

func _generate_parameter_buffer(delta):
	var params_buffer_bytes: PackedByteArray = PackedFloat32Array(
		[NUM_BOIDS,
		IMAGE_SIZE,
		friend_radius,
		avoid_radius,
		min_vel,
		max_vel,
		alignment_factor,
		cohesion_factor,
		separation_factor,
		get_viewport_rect().size.x,
		get_viewport_rect().size.y,
		delta,
		pause,
		boid_color_mode]).to_byte_array()

	return rd.storage_buffer_create(params_buffer_bytes.size(), params_buffer_bytes)

func _exit_tree():
	if SIMULATE_GPU:
		_sync_boids_gpu()
		rd.free_rid(uniform_set)
		rd.free_rid(boid_data_buffer)
		rd.free_rid(params_buffer)
		rd.free_rid(boid_pos_buffer)
		rd.free_rid(boid_vel_buffer)
		rd.free_rid(bin_buffer)
		rd.free_rid(bin_sum_buffer)
		rd.free_rid(bin_prefix_sum_buffer)
		rd.free_rid(bin_index_tracker_buffer)
		rd.free_rid(bin_reindex_buffer)
		rd.free_rid(bin_params_buffer)
		rd.free_rid(bin_sum_pipeline)
		rd.free_rid(bin_sum_shader)
		rd.free_rid(bin_prefix_sum_pipeline)
		rd.free_rid(bin_prefix_sum_shader)
		rd.free_rid(bin_reindex_pipeline)
		rd.free_rid(bin_reindex_shader)
		rd.free_rid(boid_pipeline)
		rd.free_rid(boid_compute_shader)
		rd.free()

