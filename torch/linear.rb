require "torch"

# Training data
x_train = Torch.tensor([[1.0], [2.0], [3.0], [4.0]])
y_train = Torch.tensor([[3.0], [5.0], [7.0], [9.0]])

# Simple neural network
model = Torch::NN::Linear.new(1, 1)

# Optimizer
optimizer = Torch::Optim::SGD.new(model.parameters, lr: 0.01)

# Loss function
loss_fn = Torch::NN::MSELoss.new

1000.times do |epoch|
  # Predict
  predictions = model.call(x_train)

  # Calculate loss
  loss = loss_fn.call(predictions, y_train)

  # Reset gradients
  optimizer.zero_grad

  # Backpropagation
  loss.backward

  # Update weights
  optimizer.step

  if epoch % 100 == 0
    puts "Epoch #{epoch}: loss=#{loss.item}"
  end
end

# Test predictions
test = Torch.tensor([[10.0], [20.0]])
result = model.call(test)

puts "\nPredictions:"
p result
