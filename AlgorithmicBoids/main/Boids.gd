extends Node # Using Resource to allow export and reference

#var task_handle = preload("res://task_scene/assigned_tasks.tscn")
var task_handle
var tasks_node
var main
var DataLog

var max_task
var decisionTree
var frame
# Properties of each Boid
var boidID: int
var position: Vector2
var velocity: Vector2
var groupID: int
var interaction_count = 0

#Primary Characteristics for Expectancy Theory
var task
var time_est: float
var effort: float
var tasks_uncompleted: int
var reward: float
var value

var nearest_tasks: Dictionary = {"red": Vector2(INF,INF), "blue": Vector2(INF,INF), "green": Vector2(INF,INF)}

var seeking

var given_need: Dictionary = {
	"red": 80.0,
	"blue": 150.0,
	"green": 20.0
}

# Parameters for Expectancy Theory
var instrumentality = 0
var expectancy

# Computational Variables for Instrumentality
var timeFromGoal
var discrete_time_est
var current_result: Dictionary = {"red": 0.0, "blue": 0.0, "green": 0.0}

@export_category("Boid Settings")
@export_range(0, 5) var reward_weight = 1.5

# Initialize the Boid with position, velocity, and groupID
func _init(main_node, data_node, tasks_node, boidID, pos, vel, group, frame, decisionTree, need = [10,15,8]) -> void:
	#tasks_node = task_handle.instantiate()
	#add_child(tasks_node)
	DataLog = data_node
	self.tasks_node = tasks_node # Store reference to Tasks
	main = main_node # Store reference to Main
	position = pos
	velocity = vel
	groupID = group
	self.frame = frame
	self.decisionTree = decisionTree
	#for i in range(given_need.keys().size()):
		#given_need[given_need.keys()[i]] = need[i]
	findMotivationForGoal(position)
#Data gathering for decision tree
func makeDecision(time_est, effort, tasks_completed, reward):
	var new_gID = decisionTree.predict(time_est, effort, tasks_completed, reward)
	return new_gID

func gotoTask(task):
	if task in nearest_tasks and nearest_tasks[task] != Vector2(INF,INF) and nearest_tasks[task] != Vector2(0,0):
		velocity += (nearest_tasks[task] - position).normalized()

func findMotivationForGoal(position):
	max_task = "none"
	instrumentality = 0
	for i in given_need.keys().size():
		task = given_need.keys()[i]
		var instrumentality_current = computeInstrumentality(nearest_tasks[task], task)
		#print(instrumentality, " abc " ,instrumentality_current)
		if (instrumentality < instrumentality_current):
			instrumentality = instrumentality_current
			max_task = task
	if instrumentality == 0:
		if given_need == current_result:
			max_task = "none"
		#max_task = given_need.find_key(given_need.values().max())
		#max_task = ["red","blue","green"].pick_random()
	#print("\n")
	#print("ID: ", boidID, " Task: ", max_task, " gID: ", groupID)
	#if current_result["red"] > 0 or current_result["green"] > 0 or current_result["blue"] > 0:
		#print("Task: ", max_task, " total: ", current_result)
	#print("")
	#print("New iteration")

	match max_task:
		"red":
			groupID = 1
		"blue":
			groupID = 2
		"green":
			groupID = 3
		"none":
			groupID = boidID
	if is_instance_valid(DataLog):
		DataLog.groupID = groupID
	else:
		print("GID - Node is null or has not been initialized.")
	gotoTask(max_task)
	return max_task

func computeInstrumentality(est_goal_pos: Vector2, task: String):

	var I: float
	time_est = est_goal_pos.length() / velocity.length()
	if time_est == 0:
		time_est = 1
	tasks_uncompleted = given_need[task] - current_result[task]
	#var reward = ((tasks_uncompleted)/given_need[task])
	reward = (tasks_uncompleted)/given_need[task] #(0,1)
	effort = (abs(est_goal_pos - position).length() + 1) / frame #(0,1)
	var k = 1 # Coefficient to fine-tune decay rate.
	var time_est_normalised = ( (time_est - 1) / (100 - 1) ) * 5
	if est_goal_pos == Vector2(INF,INF) or effort == 0:
		I = 0
	else:
		value = reward/effort
		I = reward / pow(effort, -1 * time_est_normalised) #(1,inf)
	#print("R: ", reward)
	#print("E: ", effort)
	#print("Time Est: ", time_est_normalised)
	#print("I: ", I)
	if is_instance_valid(DataLog):
		DataLog.update_task_data(task, time_est, reward, effort, tasks_uncompleted)
	else:
		print("Node is null or has not been initialized.")
	return I

func getExpectancy():
	#gets the competence of the model for a given input for/from decision_tree
	pass

func cogniseValence(instrumentality, expectancy):
	#how high is the expectancy for this action? if too low then ignore.
	pass

#This is what main will access to then share the message with other boids. This should be outside but is here for now.

func check_task_interaction():
	# Ensure we're getting the right path
	if is_instance_valid(tasks_node):
		tasks_node.check_interactions(position, self)
		#findMotivationForGoal(position)
	else:
		print("Tasks node not found.")

func task_count(color):
	#print(color)
	#print("popo")
	var color_name
	if seeking == color: # Check if the color matches what the Boid is seeking
		interaction_count += 1
		print("interaction_count")
		match color:
			Color(1, 0, 0):
				current_result["red"] += 1
			Color(0, 1, 0):
				current_result["green"] += 1
			Color(0, 0, 1):
				current_result["blue"] += 1
		main.shoutCompleted(color, self.position.normalized())
	else:
		match color:
			Color(1, 0, 0):
				color_name = "red"
			Color(0, 1, 0):
				color_name = "green"
			Color(0, 0, 1):
				color_name = "blue"
		# Call shoutLocated in main if the Boid doesn't need the task
		main.shoutLocated(color, self.position.normalized()) # Use the reference to Main
		nearest_tasks[color_name] = position
	findMotivationForGoal(self.position)

