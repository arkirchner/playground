# frozen_string_literal: true

require "torch"

#
# Sequence Builder for LSTM Training
#
# Converts 2D feature tensor into 3D sequences using sliding windows
# Output shape: [num_sequences, sequence_length, num_features]
#
class SequenceBuilder
  attr_reader :sequences_x, :sequences_y

  def initialize(features_tensor, labels_tensor, sequence_length: 50)
    @features = features_tensor
    @labels = labels_tensor
    @sequence_length = sequence_length
    @num_samples = features_tensor.shape[0]
    @num_features = features_tensor.shape[1]
  end

  def build
    num_sequences = @num_samples - @sequence_length
    return nil if num_sequences <= 0

    # Pre-allocate tensors
    @sequences_x = Torch.zeros(
      [num_sequences, @sequence_length, @num_features],
      dtype: :float32
    )
    @sequences_y = Torch.zeros([num_sequences], dtype: :float32)

    # Create sliding windows
    num_sequences.times do |i|
      # Extract sequence window (row slicing)
      sequence_rows = []
      @sequence_length.times do |j|
        sequence_rows << @features[i + j].to_a
      end
      sequence = Torch.tensor(sequence_rows, dtype: :float32)
      @sequences_x[i] = sequence

      # Label corresponds to the last timestep in the sequence
      @sequences_y[i] = @labels[i + @sequence_length - 1]
    end

    { x: @sequences_x, y: @sequences_y }
  end

  def temporal_split(train_ratio: 0.70, val_ratio: 0.15)
    total = @sequences_x.shape[0]

    train_size = (total * train_ratio).to_i
    val_size = (total * val_ratio).to_i
    test_size = total - train_size - val_size

    # Temporal split (no shuffling to prevent leakage)
    train_x = @sequences_x[0...train_size]
    train_y = @sequences_y[0...train_size]

    val_x = @sequences_x[train_size...(train_size + val_size)]
    val_y = @sequences_y[train_size...(train_size + val_size)]

    test_x = @sequences_x[(train_size + val_size)..-1]
    test_y = @sequences_y[(train_size + val_size)..-1]

    {
      train: { x: train_x, y: train_y, size: train_size },
      val: { x: val_x, y: val_y, size: val_size },
      test: { x: test_x, y: test_y, size: test_size }
    }
  end

  def create_data_loader(x_tensor, y_tensor, batch_size: 32, shuffle: false)
    dataset = create_dataset(x_tensor, y_tensor)
    
    # Simple batching without DataLoader (torch-rb may have limited support)
    batches = []
    num_samples = x_tensor.shape[0]
    indices = (0...num_samples).to_a
    indices.shuffle! if shuffle

    indices.each_slice(batch_size) do |batch_indices|
      batch_x = Torch.stack(batch_indices.map { |i| x_tensor[i] })
      batch_y = Torch.tensor(batch_indices.map { |i| y_tensor[i].item })
      batches << [batch_x, batch_y]
    end

    batches
  end

  private

  def create_dataset(x_tensor, y_tensor)
    { x: x_tensor, y: y_tensor }
  end
end
