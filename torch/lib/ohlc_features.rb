# frozen_string_literal: true

require "torch"

#
# Feature Engineering for OHLC Data
#
# Calculates technical indicators with proper temporal alignment
# to prevent lookahead bias (all features shifted by 1 period)
#
class OHLCFeatures
  attr_reader :features, :feature_names, :scaler_params

  def initialize(ohlc_data)
    @ohlc = ohlc_data
    @num_samples = ohlc_data[:close].length
    @features = {}
    @feature_names = []
    @scaler_params = {}
  end

  def calculate
    # Price-based features (4)
    calculate_returns
    calculate_hl_range
    calculate_oc_diff

    # Volatility-based features (4)
    calculate_atr
    calculate_volatility
    calculate_bollinger_bands

    # Momentum-based features (2)
    calculate_rsi
    calculate_ma_distance

    # Volume-based features (1)
    calculate_volume_ratio

    # Combine all features into matrix
    combine_features

    # CRITICAL: Shift all features by 1 to prevent lookahead bias
    shift_features

    self
  end

  def normalize!(fit_indices: nil)
    # Fit scaler on training data only
    fit_data = if fit_indices
                 # Extract rows for fit_indices
                 rows = []
                 fit_indices.each do |idx|
                   rows << @feature_matrix[idx].to_a
                 end
                 rows
               else
                 @feature_matrix.to_a
               end

    # Calculate mean and std for each feature
    @scaler_params[:mean] = []
    @scaler_params[:std] = []

    @feature_names.length.times do |col|
      values = fit_data.map { |row| row[col] }
      mean = values.sum / values.length
      variance = values.map { |v| (v - mean)**2 }.sum / values.length
      std = Math.sqrt(variance)
      std = 1.0 if std < 1e-8 # Prevent division by zero

      @scaler_params[:mean] << mean
      @scaler_params[:std] << std
    end

    # Apply normalization to all data
    normalized = @feature_matrix.to_a.map.with_index do |row, i|
      row.map.with_index do |val, j|
        (val - @scaler_params[:mean][j]) / @scaler_params[:std][j]
      end
    end

    @feature_matrix = Torch.tensor(normalized, dtype: :float32)
    self
  end

  def to_tensor
    @feature_matrix
  end

  private

  def calculate_returns
    close = @ohlc[:close]

    # 1-day returns
    returns_1d = [0.0]
    (1...@num_samples).each do |i|
      returns_1d << (close[i] - close[i - 1]) / close[i - 1]
    end
    @features[:returns_1d] = returns_1d

    # 5-day returns
    returns_5d = [0.0] * 5
    (5...@num_samples).each do |i|
      returns_5d << (close[i] - close[i - 5]) / close[i - 5]
    end
    @features[:returns_5d] = returns_5d
  end

  def calculate_hl_range
    hl_range = []
    @num_samples.times do |i|
      range_val = (@ohlc[:high][i] - @ohlc[:low][i]) / @ohlc[:close][i]
      hl_range << range_val
    end
    @features[:hl_range] = hl_range
  end

  def calculate_oc_diff
    oc_diff = []
    @num_samples.times do |i|
      diff = (@ohlc[:open][i] - @ohlc[:close][i]) / @ohlc[:close][i]
      oc_diff << diff
    end
    @features[:oc_diff] = oc_diff
  end

  def calculate_atr(period: 14)
    # True Range
    tr = [0.0]
    (1...@num_samples).each do |i|
      high_low = @ohlc[:high][i] - @ohlc[:low][i]
      high_close = (@ohlc[:high][i] - @ohlc[:close][i - 1]).abs
      low_close = (@ohlc[:low][i] - @ohlc[:close][i - 1]).abs
      tr << [high_low, high_close, low_close].max
    end

    # ATR using EMA
    atr = [0.0] * period
    atr[period - 1] = tr[0...period].sum / period

    (period...@num_samples).each do |i|
      atr[i] = (atr[i - 1] * (period - 1) + tr[i]) / period
    end

    # Normalize by price
    atr_norm = []
    @num_samples.times do |i|
      atr_norm << atr[i] / @ohlc[:close][i]
    end

    @features[:atr_14_norm] = atr_norm
    @features[:atr_raw] = atr # Store raw ATR for labeling
  end

  def calculate_volatility(period: 20)
    close = @ohlc[:close]
    vol = [0.0] * period

    (period...@num_samples).each do |i|
      returns = (i - period + 1..i).map do |j|
        j > 0 ? (close[j] - close[j - 1]) / close[j - 1] : 0.0
      end

      mean_return = returns.sum / returns.length
      variance = returns.map { |r| (r - mean_return)**2 }.sum / returns.length
      std_dev = Math.sqrt(variance)

      # Annualize (assuming 252 trading days)
      vol[i] = std_dev * Math.sqrt(252)
    end

    @features[:volatility_20d] = vol
  end

  def calculate_bollinger_bands(period: 20, num_std: 2.0)
    close = @ohlc[:close]
    bb_width = [0.0] * period
    bb_position = [0.0] * period

    (period...@num_samples).each do |i|
      window = close[(i - period + 1)..i]
      sma = window.sum / window.length

      variance = window.map { |v| (v - sma)**2 }.sum / window.length
      std = Math.sqrt(variance)

      upper_band = sma + num_std * std
      lower_band = sma - num_std * std

      # BB width (normalized)
      bb_width[i] = (upper_band - lower_band) / sma

      # Price position within bands
      band_range = upper_band - lower_band
      if band_range > 0
        bb_position[i] = (close[i] - lower_band) / band_range
      else
        bb_position[i] = 0.5
      end
    end

    @features[:bb_width] = bb_width
    @features[:bb_position] = bb_position
  end

  def calculate_rsi(period: 14)
    close = @ohlc[:close]
    rsi = [50.0] * (period + 1) # Default to neutral

    # Calculate price changes
    gains = [0.0]
    losses = [0.0]

    (1...@num_samples).each do |i|
      change = close[i] - close[i - 1]
      gains << (change > 0 ? change : 0.0)
      losses << (change < 0 ? -change : 0.0)
    end

    # Initial average
    avg_gain = gains[1..period].sum / period
    avg_loss = losses[1..period].sum / period

    ((period + 1)...@num_samples).each do |i|
      avg_gain = (avg_gain * (period - 1) + gains[i]) / period
      avg_loss = (avg_loss * (period - 1) + losses[i]) / period

      if avg_loss == 0
        rsi[i] = 100.0
      else
        rs = avg_gain / avg_loss
        rsi[i] = 100.0 - (100.0 / (1.0 + rs))
      end
    end

    # Normalize to 0-1 range
    rsi_norm = rsi.map { |v| v / 100.0 }
    @features[:rsi_14] = rsi_norm
  end

  def calculate_ma_distance(period: 20)
    close = @ohlc[:close]
    ma_dist = [0.0] * period

    (period...@num_samples).each do |i|
      ma = close[(i - period + 1)..i].sum / period
      ma_dist[i] = (close[i] - ma) / ma
    end

    @features[:ma_distance_20] = ma_dist
  end

  def calculate_volume_ratio(period: 20)
    volume = @ohlc[:volume]
    vol_ratio = [1.0] * period

    (period...@num_samples).each do |i|
      avg_volume = volume[(i - period + 1)..i].sum / period
      vol_ratio[i] = volume[i].to_f / avg_volume
    end

    @features[:volume_ratio] = vol_ratio
  end

  def combine_features
    # Define feature order
    @feature_names = [
      :returns_1d, :returns_5d, :hl_range, :oc_diff,
      :atr_14_norm, :volatility_20d, :bb_width, :bb_position,
      :rsi_14, :ma_distance_20, :volume_ratio
    ]

    # Convert to 2D array
    feature_matrix = []
    @num_samples.times do |i|
      row = @feature_names.map { |name| @features[name][i] }
      feature_matrix << row
    end

    @feature_matrix = Torch.tensor(feature_matrix, dtype: :float32)
  end

  def shift_features
    # Shift all features by 1 to prevent lookahead bias
    shifted = [[0.0] * @feature_names.length] + @feature_matrix.to_a[0...-1]
    @feature_matrix = Torch.tensor(shifted, dtype: :float32)
  end
end
