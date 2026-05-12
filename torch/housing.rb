require "torch"

#
# Training Data
#
# Each row:
# [house_size_in_m2, number_of_rooms]
#
x_train = Torch.tensor([
  [50.0, 1.0],
  [60.0, 1.0],
  [80.0, 2.0],
  [100.0, 2.0],
  [120.0, 3.0],
  [150.0, 4.0]
])

#
# Expected prices
#
y_train = Torch.tensor([
  [100.0],
  [120.0],
  [180.0],
  [220.0],
  [300.0],
  [380.0]
])

#
# Model
#
# 2 inputs:
# - size
# - rooms
#
# 1 output:
# - price
#
model = Torch::NN::Linear.new(2, 1)

#
# Optimizer
#
optimizer = Torch::Optim::SGD.new(
  model.parameters,
  lr: 0.0001
)

#
# Loss function
#
loss_fn = Torch::NN::MSELoss.new

#
# Training Loop
#
5000.times do |epoch|
  # Make predictions
  predictions = model.call(x_train)

  # Compare predictions with correct answers
  loss = loss_fn.call(predictions, y_train)

  # Reset gradients
  optimizer.zero_grad

  # Calculate gradients
  loss.backward

  # Update weights
  optimizer.step

  if epoch % 500 == 0
    puts "Epoch #{epoch} | Loss: #{loss.item}"
  end
end

#
# Test the model
#
test_houses = Torch.tensor([
  [70.0, 2.0],
  [130.0, 3.0],
  [200.0, 5.0]
])

predictions = model.call(test_houses)

puts "\nPredictions:"
predictions.to_a.each_with_index do |prediction, index|
  price = prediction[0].round(2)

  puts "House #{index + 1}: predicted price = #{price}"
end

#
# Show learned parameters
#
weights = model.weight
bias = model.bias

puts "\nLearned Parameters:"
puts "Weights:"
p weights

puts "Bias:"
p bias
