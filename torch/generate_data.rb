# frozen_string_literal: true

require "torch"
require "csv"
require "json"
require_relative "lib/synthetic_ohlc"
require_relative "lib/ohlc_features"
require_relative "lib/breakout_labeler"

#
# Generate Synthetic OHLC Data and Export to CSV
#
# Usage: ruby generate_data.rb [num_samples]
# Example: ruby generate_data.rb 1000
#

num_samples = (ARGV[0] || 1000).to_i

puts "=" * 60
puts "Generating Synthetic OHLC Data"
puts "=" * 60
puts "Samples: #{num_samples}"
puts

# Step 1: Generate synthetic OHLC data
puts "[1/5] Generating OHLC data with volatility clustering..."
generator = SyntheticOHLC.new(num_samples: num_samples, seed: 42)
ohlc_data = generator.generate
puts "  ✓ Generated #{ohlc_data[:close].length} candles"
puts

# Step 2: Calculate features
puts "[2/5] Calculating technical indicators..."
feature_calculator = OHLCFeatures.new(ohlc_data)
feature_calculator.calculate
puts "  ✓ Calculated #{feature_calculator.feature_names.length} features"
puts "  Features: #{feature_calculator.feature_names.join(', ')}"
puts

# Step 3: Generate breakout labels
puts "[3/5] Labeling volatility breakouts (2.0x ATR threshold)..."
atr_raw = feature_calculator.features[:atr_raw]
labeler = BreakoutLabeler.new(atr_raw, threshold: 2.0, lookback: 20, lookahead: 10)
labels = labeler.label

distribution = labeler.class_distribution
puts "  ✓ Labeled #{labels.length} samples"
puts "  Breakouts: #{distribution[:breakouts]} (#{distribution[:breakout_pct]}%)"
puts "  Normal: #{distribution[:normal]} (#{100 - distribution[:breakout_pct]}%)"
puts "  Class ratio: #{distribution[:class_ratio].round(2)}:1"
puts

# Step 4: Export to CSV
puts "[4/5] Exporting to CSV..."
csv_path = "data/ohlc_data.csv"

CSV.open(csv_path, "w") do |csv|
  # Header
  headers = ["index", "open", "high", "low", "close", "volume", "breakout_label"]
  csv << headers

  # Data rows
  num_samples.times do |i|
    row = [
      i,
      ohlc_data[:open][i].round(2),
      ohlc_data[:high][i].round(2),
      ohlc_data[:low][i].round(2),
      ohlc_data[:close][i].round(2),
      ohlc_data[:volume][i],
      labels[i]
    ]
    csv << row
  end
end

puts "  ✓ Saved to #{csv_path}"
puts

# Step 5: Save metadata
puts "[5/5] Saving metadata..."
metadata = {
  num_samples: num_samples,
  num_features: feature_calculator.feature_names.length,
  feature_names: feature_calculator.feature_names,
  breakout_threshold: 2.0,
  lookback_window: 20,
  lookahead_window: 10,
  class_distribution: distribution,
  generated_at: Time.now.to_s
}

File.write("data/metadata.json", JSON.pretty_generate(metadata))
puts "  ✓ Saved to data/metadata.json"
puts

puts "=" * 60
puts "Data Generation Complete!"
puts "=" * 60
puts "Next steps:"
puts "  1. Review data/ohlc_data.csv"
puts "  2. Run: ruby train_breakout_model.rb"
puts
