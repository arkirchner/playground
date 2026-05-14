# frozen_string_literal: true

require "torch"

#
# Breakout Labeler for Volatility Patterns
#
# Labels periods where volatility expansion occurs within the next N candles
# Definition: max(ATR[t+1:t+N]) > threshold * mean(ATR[t-lookback:t])
#
class BreakoutLabeler
  attr_reader :labels

  def initialize(atr_series, threshold: 2.0, lookback: 20, lookahead: 10)
    @atr = atr_series
    @threshold = threshold
    @lookback = lookback
    @lookahead = lookahead
    @num_samples = atr_series.length
    @labels = []
  end

  def label
    # Need at least lookback periods before and lookahead periods after
    valid_start = @lookback
    valid_end = @num_samples - @lookahead

    # Fill initial periods with 0 (no breakout)
    @labels = [0] * valid_start

    # Calculate labels for valid range
    (valid_start...valid_end).each do |t|
      # Baseline ATR: average of past lookback periods
      baseline_window = @atr[(t - @lookback)...t]
      baseline_atr = baseline_window.sum / baseline_window.length

      # Future ATR: maximum in next lookahead periods
      future_window = @atr[(t + 1)..(t + @lookahead)]
      future_atr_max = future_window.max

      # Label as breakout if future exceeds threshold * baseline
      breakout = future_atr_max > (@threshold * baseline_atr) ? 1 : 0
      @labels << breakout
    end

    # Fill remaining periods with 0
    remaining = @num_samples - @labels.length
    @labels.concat([0] * remaining)

    @labels
  end

  def to_tensor
    Torch.tensor(@labels, dtype: :float32)
  end

  def class_distribution
    num_breakouts = @labels.count(1)
    num_normal = @labels.count(0)
    total = @labels.length

    {
      breakouts: num_breakouts,
      normal: num_normal,
      breakout_pct: (num_breakouts.to_f / total * 100).round(2),
      class_ratio: num_normal.to_f / [num_breakouts, 1].max
    }
  end
end
