class_name TreeNode
var feature_index
var threshold
var left_node
var right_node
var info_gain
var data

func _init(isLeaf, feature_index, threshold, left_node: TreeNode, right_node: TreeNode, info_gain, data):
	if !isLeaf:
		self.feature_index
		self.threshold
		self.left_node
		self.right_node
		self.info_gain
	else:
		self.data = data

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
	left_node = node
func getLeft():
	return left_node

func setRight(node: TreeNode):
	right_node = node

func getRight():
	return right_node
