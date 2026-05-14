# frozen_string_literal: true

require "torch"

#
# Synthetic OHLC Data Generator with Volatility Clustering
#
# Generates realistic OHLC (Open, High, Low, Close) data with:
# - GARCH-like volatility clustering
# - Injected volatility breakout patterns
# - Correlated volume data
#
class SyntheticOHLC
  attr_reader :data

  def initialize(num_samples: 1000, base_price: 100.0, seed: 42)
    @num_samples = num_samples
    @base_price = base_price
    @seed = seed

    # GARCH parameters for volatility clustering
    @omega = 0.00001      # Base volatility
    @alpha = 0.1          # Reaction to past returns
    @beta = 0.85          # Persistence of volatility
    @drift = 0.0001       # Price drift (slight upward bias)

    @data = {}
  end

  def generate
    Random.srand(@seed)
    Torch.manual_seed(@seed)

    close_prices = generate_price_series
    open_prices = generate_open_prices(close_prices)
    high_prices, low_prices = generate_high_low(close_prices, open_prices)
    volumes = generate_volumes(close_prices)

    @data = {
      open: open_prices,
      high: high_prices,
      low: low_prices,
      close: close_prices,
      volume: volumes
    }

    inject_breakout_patterns

    @data
  end

  private

  def generate_price_series
    prices = [@base_price]
    volatilities = [0.015] # Initial volatility (1.5%)
    returns = [0.0]

    (@num_samples - 1).times do |t|
      # GARCH(1,1) volatility model
      prev_return = returns[t]
      prev_vol = volatilities[t]

      # Update volatility: σ²(t) = ω + α*r²(t-1) + β*σ²(t-1)
      vol_squared = @omega + @alpha * (prev_return**2) + @beta * (prev_vol**2)
      current_vol = Math.sqrt(vol_squared)
      volatilities << current_vol

      # Generate return: r(t) = μ + σ(t)*ε, where ε ~ N(0,1)
      epsilon = randn
      ret = @drift + current_vol * epsilon
      returns << ret

      # Update price: S(t+1) = S(t) * exp(r(t))
      new_price = prices[t] * Math.exp(ret)
      prices << new_price
    end

    prices
  end

  def generate_open_prices(close_prices)
    opens = [close_prices[0]]

    (1...close_prices.length).each do |t|
      # Open is previous close with small gap
      gap = close_prices[t - 1] * randn * 0.002
      opens << close_prices[t - 1] + gap
    end

    opens
  end

  def generate_high_low(close_prices, open_prices)
    highs = []
    lows = []

    close_prices.each_with_index do |close, t|
      open = open_prices[t]

      # Intraday range based on volatility
      range_pct = randn.abs * 0.01 # 0-1% typical range
      range_amount = close * range_pct

      # High is max of open/close + range
      high = [open, close].max + range_amount * rand
      highs << high

      # Low is min of open/close - range
      low = [open, close].min - range_amount * rand
      lows << low
    end

    [highs, lows]
  end

  def generate_volumes(close_prices)
    base_volume = 1_000_000
    volumes = []

    close_prices.each_with_index do |price, t|
      # Volume correlated with absolute returns
      if t > 0
        abs_return = ((price - close_prices[t - 1]) / close_prices[t - 1]).abs
        volume_multiplier = 1.0 + abs_return * 10.0
      else
        volume_multiplier = 1.0
      end

      # Add noise
      noise = 0.8 + rand * 0.4 # 0.8 to 1.2
      volume = (base_volume * volume_multiplier * noise).to_i

      volumes << volume
    end

    volumes
  end

  def inject_breakout_patterns
    # Inject 10-15% breakout patterns
    num_breakouts = (@num_samples * 0.12).to_i
    breakout_positions = num_breakouts.times.map { rand(100...(@num_samples - 50)) }.uniq.sort

    breakout_positions.each do |pos|
      inject_single_breakout(pos)
    end
  end

  def inject_single_breakout(start_pos)
    # Phase 1: Compression (10-20 candles)
    compression_length = 10 + rand(10)
    compression_range = (start_pos...[start_pos + compression_length, @num_samples].min)

    compression_range.each do |i|
      # Reduce high-low range (squeeze)
      mid = (@data[:high][i] + @data[:low][i]) / 2.0
      squeeze_factor = 0.3
      @data[:high][i] = mid + (@data[:high][i] - mid) * squeeze_factor
      @data[:low][i] = mid + (@data[:low][i] - mid) * squeeze_factor
    end

    # Phase 2: Expansion (5-15 candles)
    expansion_start = start_pos + compression_length
    expansion_length = 5 + rand(10)
    expansion_range = (expansion_start...[expansion_start + expansion_length, @num_samples].min)

    expansion_range.each do |i|
      # Increase high-low range (breakout)
      mid = (@data[:high][i] + @data[:low][i]) / 2.0
      expansion_factor = 2.5 + rand * 1.5 # 2.5x to 4x expansion
      @data[:high][i] = mid + (@data[:high][i] - mid) * expansion_factor
      @data[:low][i] = mid + (@data[:low][i] - mid) * expansion_factor

      # Increase volume during breakout
      @data[:volume][i] = (@data[:volume][i] * (1.5 + rand)).to_i
    end
  end

  # Box-Muller transform for normal distribution
  def randn
    u1 = rand
    u2 = rand
    Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
  end
end
