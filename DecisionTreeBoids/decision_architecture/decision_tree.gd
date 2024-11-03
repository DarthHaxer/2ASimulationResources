extends Node2D
class_name DecisionTree
var root = null
var min_samples_split = 12
var max_depth = 5

# Constructor
func _init(min_samples_split := 12, max_depth := 5):
	self.root = null
	self.min_samples_split = min_samples_split
	self.max_depth = max_depth

# Recursive function to build the tree
func build_tree(dataset: Array, curr_depth := 0) -> TreeNode:
	var X = []
	var Y = []

	# Extract X (all features) and Y (labels)
	for row in dataset:
		print("Building Tree")
		X.append(row.slice(0, row.size() - 1))  # Get all but the last column
		Y.append(row[-1])  # Get the last column
	
	var num_samples = X.size()
	var num_features = X[0].size()

	# Split until stopping conditions are met
	if num_samples >= self.min_samples_split and curr_depth <= self.max_depth:
		var best_split = get_best_split(dataset, num_samples, num_features)
		print("Splitting")
		if best_split.has("info_gain") and best_split["info_gain"] > 0:
			var left_subtree = build_tree(best_split["dataset_left"], curr_depth + 1)
			var right_subtree = build_tree(best_split["dataset_right"], curr_depth + 1)
			return TreeNode.new(false, best_split["feature_index"], best_split["threshold"], left_subtree, right_subtree, best_split["info_gain"], null)

	# Compute leaf node
	var leaf_value = calculate_leaf_value(Y)
	return TreeNode.new(true, -1, 0.0, null, null, 0, leaf_value)

# Function to get unique elements (replacement for `uniq`)
func get_unique_elements(array: Array) -> Array:
	var unique_set = {}
	for item in array:
		unique_set[item] = true
	return unique_set.keys()

# Function to calculate entropy
func entropy(y: Array) -> float:
	var class_labels = get_unique_elements(y)
	var entropy_value = 0.0
	for cls in class_labels:
		var p_cls = float(y.filter(func(item): return item == cls).size()) / y.size()
		entropy_value += -p_cls * (log(p_cls) / log(2))  # Replace log with base 2 calculation
	return entropy_value

# Function to split dataset
func split(dataset: Array, feature_index: int, threshold: float) -> Array:
	var dataset_left = []
	var dataset_right = []
	for row in dataset:
		if row[feature_index] <= threshold:
			dataset_left.append(row)
		else:
			dataset_right.append(row)
	return [dataset_left, dataset_right]

# Function to get the best split
func get_best_split(dataset: Array, num_samples: int, num_features: int) -> Dictionary:
	var best_split = {}
	var max_info_gain = -INF

	for feature_index in range(num_features):
		var feature_values = dataset.map(func(row): return row[feature_index])
		var possible_thresholds = get_unique_elements(feature_values)

		for threshold in possible_thresholds:
			var splits = split(dataset, feature_index, threshold)
			var dataset_left = splits[0]
			var dataset_right = splits[1]
			if dataset_left.size() > 0 and dataset_right.size() > 0:
				var y = dataset.map(func(row): return row[-1])
				var left_y = dataset_left.map(func(row): return row[-1])
				var right_y = dataset_right.map(func(row): return row[-1])
				var curr_info_gain = information_gain(y, left_y, right_y)

				if curr_info_gain > max_info_gain:
					best_split = {
						"feature_index": feature_index,
						"threshold": threshold,
						"dataset_left": dataset_left,
						"dataset_right": dataset_right,
						"info_gain": curr_info_gain
					}
					max_info_gain = curr_info_gain

	return best_split

# Function to compute information gain
func information_gain(parent: Array, left: Array, right: Array) -> float:
	var weight_l = float(left.size()) / parent.size()
	var weight_r = float(right.size()) / parent.size()
	return entropy(parent) - (weight_l * entropy(left) + weight_r * entropy(right))

# Function to compute leaf node
func calculate_leaf_value(Y: Array) -> int:
	var frequency_dict = {}
	
	# Create a frequency dictionary
	for value in Y:
		if frequency_dict.has(value):
			frequency_dict[value] += 1
		else:
			frequency_dict[value] = 1
	
	# Find the value with the maximum frequency
	var max_value = null
	var max_count = -1
	
	for value in frequency_dict.keys():
		if frequency_dict[value] > max_count:
			max_value = value
			max_count = frequency_dict[value]
	
	return max_value

# Print tree function with type fixed for 'tree'
func print_decision_tree(tree: TreeNode = null, indent: String = " "):
	if tree == null:
		tree = self.root

	if tree.data != null:
		print(tree.data)
	else:
		print("X_" + str(tree.feature_index), "<=", str(tree.threshold), "?", str(tree.info_gain))
		print(indent + "left:")
		print_decision_tree(tree.left_node, indent + indent)
		print(indent + "right:")
		print_decision_tree(tree.right_node, indent + indent)

# Function to fit the model (train the tree)
func fit(X: Array, Y: Array):
	var dataset = []
	for i in range(X.size()):
		var row = X[i] + [Y[i]]
		dataset.append(row)
	
	print("Starting to fit the model with ", dataset.size(), " samples.")
	self.root = build_tree(dataset)
	print("Done Fitting!")

# Function to predict new data points
func predict(X: Array) -> Array:
	var predictions = []
	#print("Big un: ", X)
	for x in X:
		predictions.append(make_prediction(x, self.root))
		#print("Smol un: ", x)
	return predictions

# Function to predict a single data point
func make_prediction(x: Array, tree: TreeNode) -> int:
	if tree.data != null:
		return tree.data
	if x[tree.feature_index] <= tree.threshold:
		return make_prediction(x, tree.left_node)
	else:
		return make_prediction(x, tree.right_node)
