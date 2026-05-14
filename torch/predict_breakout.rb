# frozen_string_literal: true

require "torch"
require "json"
require_relative "lib/synthetic_ohlc"
require_relative "lib/ohlc_features"
require_relative "lib/breakout_labeler"
require_relative "lib/sequence_builder"
require_relative "lib/volatility_lstm_model"

#
# Predict and Evaluate Volatility Breakout Model
#
# Usage: ruby predict_breakout.rb [num_samples]
#

num_samples = (ARGV[0] || 1000).to_i
SEQUENCE_LENGTH = 50
THRESHOLD = 0.5

puts "=" * 60
puts "Evaluating Volatility Breakout LSTM"
puts "=" * 60

# Load training info
unless File.exist?("models/training_info.json")
  puts "Error: No trained model found. Run train_breakout_model.rb first."
  exit 1
end

training_info = JSON.parse(File.read("models/training_info.json"))
puts "Loaded model trained on #{training_info['num_samples']} samples"
puts

# Step 1: Generate same data (with same seed)
puts "[1/5] Generating data..."
generator = SyntheticOHLC.new(num_samples: num_samples, seed: 42)
ohlc_data = generator.generate

# Step 2: Calculate features
puts "[2/5] Calculating features..."
feature_calculator = OHLCFeatures.new(ohlc_data)
feature_calculator.calculate

# Create labels
atr_raw = feature_calculator.features[:atr_raw]
labeler = BreakoutLabeler.new(atr_raw, threshold: 2.0, lookback: 20, lookahead: 10)
labels = labeler.label
label_tensor = labeler.to_tensor

# Step 3: Build sequences
puts "[3/5] Building sequences..."
builder = SequenceBuilder.new(
  feature_calculator.to_tensor,
  label_tensor,
  sequence_length: SEQUENCE_LENGTH
)
builder.build
splits = builder.temporal_split(train_ratio: 0.70, val_ratio: 0.15)

# Normalize using saved parameters
train_indices = (0...splits[:train][:size])
feature_calculator.normalize!(fit_indices: train_indices)

# Use test set for evaluation
test_x = splits[:test][:x]
test_y = splits[:test][:y]

puts "  ✓ Test set: #{splits[:test][:size]} sequences"

# Step 4: Load model
puts "[4/5] Loading model..."
num_features = feature_calculator.feature_names.length
model = VolatilityBreakoutLSTM.new(
  num_features,
  hidden_size: 128,
  num_layers: 2,
  dropout: 0.3
)

model.load_state_dict(Torch.load("models/best_model.pt"))
model.eval
puts "  ✓ Model loaded from models/best_model.pt"

# Step 5: Predict and evaluate
puts "[5/5] Evaluating..."
puts

predictions = []
actuals = []

Torch.no_grad do
  # Predict in batches
  batch_size = 32
  num_batches = (test_x.shape[0].to_f / batch_size).ceil

  num_batches.times do |i|
    start_idx = i * batch_size
    end_idx = [start_idx + batch_size, test_x.shape[0]].min
    
    batch_x = test_x[start_idx...end_idx]
    batch_y = test_y[start_idx...end_idx]
    
    probs = model.call(batch_x)
    
    probs.shape[0].times do |j|
      predictions << probs[j].item
      actuals << batch_y[j].item
    end
  end
end

# Convert probabilities to binary predictions
binary_preds = predictions.map { |p| p > THRESHOLD ? 1 : 0 }

# Calculate confusion matrix
tp = binary_preds.zip(actuals).count { |pred, actual| pred == 1 && actual == 1 }
fp = binary_preds.zip(actuals).count { |pred, actual| pred == 1 && actual == 0 }
tn = binary_preds.zip(actuals).count { |pred, actual| pred == 0 && actual == 0 }
fn = binary_preds.zip(actuals).count { |pred, actual| pred == 0 && actual == 1 }

# Calculate metrics
total = tp + tn + fp + fn
accuracy = (tp + tn).to_f / total
precision = tp > 0 ? tp.to_f / (tp + fp) : 0.0
recall = tp > 0 ? tp.to_f / (tp + fn) : 0.0
f1 = (precision + recall) > 0 ? 2 * (precision * recall) / (precision + recall) : 0.0

# Calculate average probability for each class
breakout_probs = actuals.zip(predictions).select { |a, _| a == 1 }.map { |_, p| p }
normal_probs = actuals.zip(predictions).select { |a, _| a == 0 }.map { |_, p| p }

avg_breakout_prob = breakout_probs.any? ? breakout_probs.sum / breakout_probs.length : 0.0
avg_normal_prob = normal_probs.any? ? normal_probs.sum / normal_probs.length : 0.0

# Print results
puts "=" * 60
puts "Test Set Performance (threshold=#{THRESHOLD})"
puts "=" * 60
puts
puts "Confusion Matrix:"
puts "                Predicted"
puts "                Breakout  Normal"
puts "  Actual Breakout   #{tp.to_s.rjust(4)}    #{fn.to_s.rjust(4)}"
puts "  Actual Normal     #{fp.to_s.rjust(4)}    #{tn.to_s.rjust(4)}"
puts
puts "Classification Metrics:"
puts "  Accuracy:  #{(accuracy * 100).round(2)}%"
puts "  Precision: #{(precision * 100).round(2)}%"
puts "  Recall:    #{(recall * 100).round(2)}%"
puts "  F1-Score:  #{(f1 * 100).round(2)}%"
puts
puts "Probability Analysis:"
puts "  Avg prob for actual breakouts: #{(avg_breakout_prob * 100).round(2)}%"
puts "  Avg prob for actual normal:    #{(avg_normal_prob * 100).round(2)}%"
puts "  Separation: #{((avg_breakout_prob - avg_normal_prob) * 100).round(2)}%"
puts
puts "=" * 60

# Sample predictions
puts "Sample Predictions (first 20):"
puts "  Index | Actual | Predicted | Probability"
puts "  " + "-" * 45
20.times do |i|
  break if i >= actuals.length
  actual_label = actuals[i] == 1 ? "Breakout" : "Normal  "
  pred_label = binary_preds[i] == 1 ? "Breakout" : "Normal  "
  prob = (predictions[i] * 100).round(1)
  match = actuals[i] == binary_preds[i] ? "✓" : "✗"
  puts "  #{i.to_s.rjust(5)} | #{actual_label} | #{pred_label} | #{prob.to_s.rjust(5)}% #{match}"
end

puts
puts "=" * 60
puts "Evaluation Complete!"
puts "=" * 60
