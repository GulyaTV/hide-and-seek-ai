extends RefCounted

## Neural Network for Hide and Seek AI
## Inspired by OpenAI's reinforcement learning approach

class_name NeuralNetwork

var layers: Array[Array] = []
var weights: Array[Array] = []
var biases: Array[Array] = []
var learning_rate: float = 0.001
var activation_function: String = "relu"

func _init(layer_sizes: Array[int]):
	randomize()
	initialize_network(layer_sizes)

func initialize_network(layer_sizes: Array[int]):
	# Инициализируем слои
	for i in range(layer_sizes.size()):
		layers.append([])
		for j in range(layer_sizes[i]):
			layers[i].append(0.0)
	
	# Инициализируем веса и смещения
	for i in range(1, layer_sizes.size()):
		var layer_weights = []
		var layer_biases = []
		
		for j in range(layer_sizes[i]):
			var neuron_weights = []
			for k in range(layer_sizes[i-1]):
				neuron_weights.append(randf_range(-1.0, 1.0))
			layer_weights.append(neuron_weights)
			layer_biases.append(randf_range(-1.0, 1.0))
		
		weights.append(layer_weights)
		biases.append(layer_biases)

func forward(input_data: Array[float]) -> Array[float]:
	# Устанавливаем входные данные
	for i in range(input_data.size()):
		if i < layers[0].size():
			layers[0][i] = input_data[i]
	
	# Прямое распространение
	for i in range(1, layers.size()):
		var prev_layer = layers[i-1]
		var current_layer = layers[i]
		
		for j in range(current_layer.size()):
			var sum = biases[i-1][j]
			for k in range(prev_layer.size()):
				sum += prev_layer[k] * weights[i-1][j][k]
			
			current_layer[j] = activate(sum)
	
	return layers[layers.size() - 1]

func activate(value: float) -> float:
	match activation_function:
		"relu":
			return max(0.0, value)
		"tanh":
			return tanh(value)
		"sigmoid":
			return 1.0 / (1.0 + exp(-value))
		_:
			return value

func activate_derivative(value: float) -> float:
	match activation_function:
		"relu":
			return 1.0 if value > 0 else 0.0
		"tanh":
			var t = tanh(value)
			return 1.0 - t * t
		"sigmoid":
			var s = 1.0 / (1.0 + exp(-value))
			return s * (1.0 - s)
		_:
			return 1.0

func backward(target: Array[float], input_data: Array[float]):
	# Получаем выход сети
	var output = forward(input_data)
	
	# Вычисляем ошибку на выходном слое
	var output_error = []
	for i in range(output.size()):
		var error = target[i] - output[i]
		output_error.append(error * activate_derivative(layers[layers.size() - 1][i]))
	
	# Обратное распространение ошибки
	var layer_errors = [output_error]
	
	for i in range(layers.size() - 2, 0, -1):
		var current_error = []
		var next_layer_error = layer_errors[0]
		
		for j in range(layers[i].size()):
			var error_sum = 0.0
			for k in range(layers[i + 1].size()):
				error_sum += next_layer_error[k] * weights[i][k][j]
			current_error.append(error_sum * activate_derivative(layers[i][j]))
		
		layer_errors.insert(0, current_error)
	
	# Обновляем веса и смещения
	for i in range(weights.size()):
		for j in range(weights[i].size()):
			# Обновляем смещение
			biases[i][j] += learning_rate * layer_errors[i][j]
			
			# Обновляем веса
			for k in range(weights[i][j].size()):
				weights[i][j][k] += learning_rate * layer_errors[i][j] * layers[i][k]

func mutate(mutation_rate: float = 0.1, mutation_strength: float = 0.1):
	# Мутация для эволюционного подхода
	for i in range(weights.size()):
		for j in range(weights[i].size()):
			# Мутируем смещение
			if randf() < mutation_rate:
				biases[i][j] += randf_range(-mutation_strength, mutation_strength)
			
			# Мутируем веса
			for k in range(weights[i][j].size()):
				if randf() < mutation_rate:
					weights[i][j][k] += randf_range(-mutation_strength, mutation_strength)

func copy() -> NeuralNetwork:
	# Создаем копию нейронной сети
	var new_network = NeuralNetwork.new([])
	new_network.layers = layers.duplicate(true)
	new_network.weights = weights.duplicate(true)
	new_network.biases = biases.duplicate(true)
	new_network.learning_rate = learning_rate
	new_network.activation_function = activation_function
	return new_network

func save_to_dict() -> Dictionary:
	return {
		"layers": layers,
		"weights": weights,
		"biases": biases,
		"learning_rate": learning_rate,
		"activation_function": activation_function
	}

func load_from_dict(data: Dictionary):
	layers = data["layers"]
	weights = data["weights"]
	biases = data["biases"]
	learning_rate = data["learning_rate"]
	activation_function = data["activation_function"]
