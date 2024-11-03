extends Node
@export var tracking_duration = 42.0 # Duration in seconds for tracking
@export var sampling_interval = 1.0  # How often to record task completions

var time_passed = 0.0
var task_completion_data = []  # Stores the number of tasks completed at each interval
var tasks_completed = {
	"red": 0,
	"blue": 0,
	"green": 0
}

func _ready():
	# Schedule task tracking
	set_process(true)

func _process(delta):
	time_passed += Time.get_ticks_msec() / 1000.0

	# Record task completions at each interval
	if (tracking_duration - time_passed) >= 0:
		_record_task_completion()
		time_passed = 0.0  # Reset interval

	# Stop tracking after the set duration
	if (tracking_duration - time_passed) <= 0:
		set_process(false)
		_save_data()

# Simulate task completion
func complete_task():
	tasks_completed += 1

func _record_task_completion():
	# Record current time and completed tasks
	var current_time = Time.get_ticks_msec() / 1000.0
	task_completion_data.append({
		"time": current_time,
		"red_completed": tasks_completed["red"],
		"blue_completed": tasks_completed["blue"],
		"green_completed": tasks_completed["green"]
	})
	print("Time: ", current_time, " Tasks completed: ", tasks_completed)

func _save_data():
	var file = FileAccess.open("user://task_completion_data.csv", FileAccess.WRITE_READ)
	file.store_line("Time,Red,Blue,Green")
	
	# Save each record to the CSV file
	for record in task_completion_data:
		file.store_line(str(record["time"]) + "," + str(record["red_completed"]) + "," + str(record["blue_completed"]) + "," + str(record["green_completed"]))
		
	file.close()
	print("Task completion data saved to task_completion_data.csv")
