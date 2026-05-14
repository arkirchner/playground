# frozen_string_literal: true

require "torch"
require "csv"
require "json"
require_relative "lib/synthetic_ohlc"
require_relative "lib/ohlc_features"
require_relative "lib/breakout_labeler"
require_relative "lib/sequence_builder"
require_relative "lib/volatility_lstm_model"

#
# Train Volatility Breakout LSTM Model
#
# Usage: ruby train_breakout_model.rb [num_samples]
#

num_samples = (ARGV[0] || 1000).to_i
SEQUENCE_LENGTH = 50
BATCH_SIZE = 32
EPOCHS = 500
LEARNING_RATE = 0.001
EARLY_STOP_PATIENCE = 30

puts "=" * 60
puts "Training Volatility Breakout LSTM"
puts "=" * 60
puts "Configuration:"
puts "  Samples: #{num_samples}"
puts "  Sequence Length: #{SEQUENCE_LENGTH}"
puts "  Batch Size: #{BATCH_SIZE}"
puts "  Epochs: #{EPOCHS}"
puts "  Learning Rate: #{LEARNING_RATE}"
puts

# Step 1: Generate or load data
puts "[1/6] Generating data..."
generator = SyntheticOHLC.new(num_samples: num_samples, seed: 42)
ohlc_data = generator.generate
puts "  ✓ Generated #{ohlc_data[:close].length} candles"

# Step 2: Calculate features
puts "[2/6] Calculating features..."
feature_calculator = OHLCFeatures.new(ohlc_data)
feature_calculator.calculate

# Create labels
atr_raw = feature_calculator.features[:atr_raw]
labeler = BreakoutLabeler.new(atr_raw, threshold: 2.0, lookback: 20, lookahead: 10)
labels = labeler.label
label_tensor = labeler.to_tensor

distribution = labeler.class_distribution
puts "  ✓ Features: #{feature_calculator.feature_names.length}"
puts "  ✓ Breakouts: #{distribution[:breakouts]} (#{distribution[:breakout_pct]}%)"

# Step 3: Build sequences
puts "[3/6] Building sequences..."
builder = SequenceBuilder.new(
  feature_calculator.to_tensor,
  label_tensor,
  sequence_length: SEQUENCE_LENGTH
)
builder.build
splits = builder.temporal_split(train_ratio: 0.70, val_ratio: 0.15)

puts "  ✓ Train: #{splits[:train][:size]} sequences"
puts "  ✓ Val:   #{splits[:val][:size]} sequences"
puts "  ✓ Test:  #{splits[:test][:size]} sequences"

# Normalize features (fit on training data only)
train_indices = (0...splits[:train][:size])
feature_calculator.normalize!(fit_indices: train_indices)

# Create data loaders
train_loader = builder.create_data_loader(
  splits[:train][:x], splits[:train][:y],
  batch_size: BATCH_SIZE, shuffle: true
)
val_loader = builder.create_data_loader(
  splits[:val][:x], splits[:val][:y],
  batch_size: BATCH_SIZE, shuffle: false
)

# Step 4: Initialize model
puts "[4/6] Initializing model..."
num_features = feature_calculator.feature_names.length
model = VolatilityBreakoutLSTM.new(
  num_features,
  hidden_size: 128,
  num_layers: 2,
  dropout: 0.3
)

# Loss function with class weighting
pos_weight = Torch.tensor([distribution[:class_ratio]])
criterion = Torch::NN::BCEWithLogitsLoss.new

# Optimizer
optimizer = Torch::Optim::Adam.new(model.parameters, lr: LEARNING_RATE)

puts "  ✓ Model: 2-layer LSTM, 128 hidden units"
puts "  ✓ Class weight: #{distribution[:class_ratio].round(2)}:1"

# Step 5: Training loop
puts "[5/6] Training..."
puts

best_val_loss = Float::INFINITY
patience_counter = 0
final_epoch = 0

EPOCHS.times do |epoch|
  final_epoch = epoch
  
  # Training phase
  model.train
  train_loss = 0.0

  train_loader.each do |batch_x, batch_y|
    optimizer.zero_grad
    
    # Forward pass (use logits version for BCEWithLogitsLoss)
    predictions = model.forward_logits(batch_x)
    loss = criterion.call(predictions, batch_y)
    
    # Backward pass
    loss.backward
    optimizer.step
    
    train_loss += loss.item
  end

  avg_train_loss = train_loss / train_loader.length

  # Validation phase
  model.eval
  val_loss = 0.0

  Torch.no_grad do
    val_loader.each do |batch_x, batch_y|
      predictions = model.forward_logits(batch_x)
      loss = criterion.call(predictions, batch_y)
      val_loss += loss.item
    end
  end

  avg_val_loss = val_loss / val_loader.length

  # Early stopping
  if avg_val_loss < best_val_loss
    best_val_loss = avg_val_loss
    Torch.save(model.state_dict, "models/best_model.pt")
    patience_counter = 0
    improvement = "✓ saved"
  else
    patience_counter += 1
    improvement = ""
  end

  # Print progress every 10 epochs
  if epoch % 10 == 0 || epoch == EPOCHS - 1
    puts "Epoch #{epoch.to_s.rjust(3)}: train_loss=#{avg_train_loss.round(4)} val_loss=#{avg_val_loss.round(4)} #{improvement}"
  end

  # Early stopping check
  if patience_counter >= EARLY_STOP_PATIENCE
    puts
    puts "Early stopping triggered at epoch #{epoch}"
    break
  end
end

puts
puts "  ✓ Training complete"
puts "  ✓ Best validation loss: #{best_val_loss.round(4)}"

# Step 6: Save training info
puts "[6/6] Saving training info..."
training_info = {
  num_samples: num_samples,
  sequence_length: SEQUENCE_LENGTH,
  batch_size: BATCH_SIZE,
  epochs_trained: final_epoch + 1,
  learning_rate: LEARNING_RATE,
  best_val_loss: best_val_loss,
  num_features: num_features,
  feature_names: feature_calculator.feature_names,
  scaler_params: feature_calculator.scaler_params,
  model_config: {
    hidden_size: 128,
    num_layers: 2,
    dropout: 0.3
  },
  class_distribution: distribution,
  trained_at: Time.now.to_s
}

File.write("models/training_info.json", JSON.pretty_generate(training_info))
puts "  ✓ Saved to models/training_info.json"
puts

puts "=" * 60
puts "Training Complete!"
puts "=" * 60
puts "Model saved to: models/best_model.pt"
puts "Next step: ruby predict_breakout.rb"
puts
