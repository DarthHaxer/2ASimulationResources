extends Node
@export var chart_recording_time = 3600.0 # in seconds
@export var sampling_interval = 1.0 # record data every 1 second

var boid_task_counts = { "red": 0, "green": 0, "blue": 0, "standby": 0 }
var time_passed = 0.0
var task_data = []

var start_time

func _ready():
	start_time = Time.get_ticks_msec() / 1000.0  # Store the start time in seconds
	print("Chart recording started at: ", start_time, " seconds")
	
	# Schedule data recording over the next specified time
	set_process(true)

func _process(delta):
	time_passed += (Time.get_ticks_msec()-start_time)/1000.0
	
	print("Time Passed: ", time_passed, " Remaining: ", chart_recording_time - time_passed)
	#print(boid_task_counts)
	
	# Record task distribution at each sampling interval
	if (chart_recording_time - time_passed) >= 0:
		_record_task_distribution()
		time_passed = 0.0

	# Stop recording after the specified time and save the data
	if (chart_recording_time - time_passed) <= 0:
		set_process(false)
		_save_chart()

func _record_task_distribution():
	var red_count = 0
	var green_count = 0
	var blue_count = 0
	var standby = 0

	# Count the number of Boids assigned to each task
	for boid in $"..".boids:
		match boid.max_task:
			"red":
				red_count += 1
			"green":
				green_count += 1
			"blue":
				blue_count += 1
			"none":
				standby += 1

	boid_task_counts["red"] = red_count
	boid_task_counts["green"] = green_count
	boid_task_counts["blue"] = blue_count
	boid_task_counts["standby"] = standby

	# Record the counts for the current time point
	task_data.append({
		"time": Time.get_ticks_msec() / 1000.0 - start_time,
		"red": red_count,
		"green": green_count,
		"blue": blue_count,
		"standby": standby
	})

func _save_chart():
	print("Saving data to CSV")
	var file = FileAccess.open("user://boid_task_data.csv", FileAccess.WRITE)

	if file:
		# Write the header
		file.store_line("Time,Red,Green,Blue,Standby")
		
		# Write each data entry
		for data in task_data:
			var line = str(data["time"]) + "," + str(data["red"]) + "," + str(data["green"]) + "," + str(data["blue"]) + "," + str(data["standby"])
			file.store_line(line)
		
		file.close()
		print("Data saved as boid_task_data.csv")
	else:
		print("Error opening file for writing")
