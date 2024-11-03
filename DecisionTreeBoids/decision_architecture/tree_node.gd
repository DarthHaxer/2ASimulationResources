class_name TreeNode
var feature_index: int = -1  # Initialize with a default value
var threshold: float = 0.0
var left_node: TreeNode = null
var right_node: TreeNode = null
var info_gain: float = 0.0
var data: Variant = null  # Use Variant to allow null

func _init(isLeaf: bool, feature_index: int = -1, threshold: float = 0.0, left_node: TreeNode = null, right_node: TreeNode = null, info_gain: float = 0.0, data: Variant = null):
	if !isLeaf:
		self.feature_index = feature_index
		self.threshold = threshold
		self.left_node = left_node
		self.right_node = right_node
		self.info_gain = info_gain
	else:
		self.data = data

# Methods to get and update attributes
func getFeature():
	return feature_index
func updateFeature(feature):
	self.feature_index = feature

func getThreshold():
	return threshold
func updateThreshold(threshold):
	self.threshold = threshold

func getInfoGain():
	return info_gain

func getData():
	return data

func setLeft(node: TreeNode):
	self.left_node = node
func getLeft():
	return left_node

func setRight(node: TreeNode):
	self.right_node = node
func getRight():
	return right_node
