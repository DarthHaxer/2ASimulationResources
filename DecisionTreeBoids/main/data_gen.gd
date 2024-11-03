extends Node
@export var tracking_duration = 3600.0 # Duration in seconds for tracking
@export var sampling_interval = 1.0   # Interval in seconds for recording data

var time_passed = 0.0
var task_data = []
var tracking_active = true

# Task-specific data
var tasks = {
	"red": {"task_name": "red", "time_est": 0, "reward": 0, "effort": 0, "tasks_completed": 0},
	"blue": {"task_name": "blue", "time_est": 0, "reward": 0, "effort": 0, "tasks_completed": 0},
	"green": {"task_name": "green", "time_est": 0, "reward": 0, "effort": 0, "tasks_completed": 0}
}

# Y, outcome
var groupID

func _ready():
	set_process(true)

func _process(delta):
	if not tracking_active:
		return

	time_passed += delta

	# Record task data at intervals
	if time_passed >= sampling_interval:
		_record_task_data()
		time_passed = 0.0

	# Stop tracking after duration and save data
	if Time.get_ticks_msec() / 1000.0 >= tracking_duration:
		tracking_active = false
		set_process(false)
		_save_data()

func update_task_data(task, time_est, reward, effort, tasks_completed):
	var taskVariables = tasks[task]
	taskVariables["time_est"] = time_est
	taskVariables["reward"] = reward
	taskVariables["effort"] = effort
	taskVariables["tasks_completed"] = tasks_completed
	#print("Task data: ", task)
func _record_task_data():
	# Append data for each task with groupID at the end
	for task_name in tasks.keys():
		var task = tasks[task_name]
		#print(task)
		task_data.append([task["task_name"], task["time_est"], task["reward"], task["effort"], task["tasks_completed"], groupID])

func _save_data():
	var file = FileAccess.open("user://boid_data_log.csv", FileAccess.WRITE)
	file.store_line("Task Name,Time Est,Reward,Effort,Tasks Unompleted,Group ID")
	for entry in task_data:
		file.store_line(str(entry[0]) + "," + str(entry[1]) + "," + str(entry[2]) + "," + str(entry[3]) + "," + str(entry[4]) + "," + str(entry[5]))
	file.close()
	print("Boid data saved to boid_data_log.csv")
	$"..".dataLog = true
