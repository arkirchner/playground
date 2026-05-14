# frozen_string_literal: true

require "torch"

#
# Volatility Breakout Prediction Model
#
# Stacked 2-layer LSTM for binary classification
# Predicts probability of volatility breakout within next N candles
#
class VolatilityBreakoutLSTM < Torch::NN::Module
  attr_reader :input_size, :hidden_size, :num_layers

  def initialize(input_size, hidden_size: 128, num_layers: 2, dropout: 0.3)
    super()
    
    @input_size = input_size
    @hidden_size = hidden_size
    @num_layers = num_layers

    # Stacked LSTM with dropout between layers
    @lstm = Torch::NN::LSTM.new(
      input_size,
      hidden_size,
      num_layers: num_layers,
      dropout: dropout,
      batch_first: true
    )

    # Fully connected layer for binary classification
    @fc = Torch::NN::Linear.new(hidden_size, 1)

    # Sigmoid activation for probability output
    @sigmoid = Torch::NN::Sigmoid.new
  end

  def forward(x)
    # x shape: [batch_size, sequence_length, input_size]
    
    # LSTM forward pass
    # output shape: [batch_size, sequence_length, hidden_size]
    # hidden shape: [num_layers, batch_size, hidden_size]
    lstm_out, _hidden = @lstm.call(x)

    # Take the output from the last timestep
    # Extract last timestep: [batch_size, hidden_size]
    batch_size = lstm_out.shape[0]
    last_output = lstm_out.select(1, -1)

    # Fully connected layer
    # logits shape: [batch_size, 1]
    logits = @fc.call(last_output)

    # Apply sigmoid to get probabilities [0, 1]
    probs = @sigmoid.call(logits)

    # Squeeze to [batch_size]
    probs.squeeze(-1)
  end

  def forward_logits(x)
    # Version without sigmoid for BCEWithLogitsLoss
    lstm_out, _hidden = @lstm.call(x)
    last_output = lstm_out.select(1, -1)
    logits = @fc.call(last_output)
    logits.squeeze(-1)
  end
end
