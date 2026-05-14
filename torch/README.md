# Volatility Breakout Prediction with libTorch LSTM

A complete implementation of volatility breakout pattern prediction using stacked LSTM neural networks with libTorch (via torch-rb Ruby bindings).

## Overview

This project predicts **volatility breakouts** from OHLC (Open, High, Low, Close) financial data using deep learning. It implements a 2-layer stacked LSTM model that analyzes 50-timestep sequences of technical indicators to predict whether a volatility expansion will occur within the next 10 candles.

### Key Features

- **Synthetic OHLC Generator**: Generates realistic price data with GARCH-like volatility clustering
- **Feature Engineering**: 11 technical indicators (price, volatility, momentum, volume)
- **Stacked LSTM Architecture**: 2-layer LSTM with 128 hidden units and dropout regularization
- **Binary Classification**: Predicts breakout probability (0-1) with configurable threshold
- **CSV Export**: Easy data export for external analysis or replacement with real data
- **Proper Temporal Alignment**: No lookahead bias in features or validation splits

## Architecture

```
Input: [batch, 50 timesteps, 11 features]
  ↓
2-Layer Stacked LSTM (128 hidden units, 0.3 dropout)
  ↓
Fully Connected Layer (128 → 1)
  ↓
Sigmoid Activation
  ↓
Output: Breakout Probability [0, 1]
```

### Model Specifications

- **Sequence Length**: 50 candles lookback
- **Prediction Horizon**: 10 candles ahead
- **Breakout Definition**: Volatility (ATR) > 2.0x trailing 20-period average
- **Hidden Size**: 128 units per LSTM layer
- **Dropout**: 0.3 between LSTM layers
- **Loss Function**: BCEWithLogitsLoss with class weighting
- **Optimizer**: Adam (lr=0.001)
- **Early Stopping**: Patience of 30 epochs

## Project Structure

```
torch/
├── lib/
│   ├── synthetic_ohlc.rb          # OHLC data generation
│   ├── ohlc_features.rb           # Technical indicator calculation
│   ├── breakout_labeler.rb        # Volatility breakout labeling
│   ├── sequence_builder.rb        # LSTM sequence preparation
│   └── volatility_lstm_model.rb   # Stacked LSTM model
│
├── generate_data.rb               # Generate synthetic data → CSV
├── train_breakout_model.rb        # Train LSTM model
├── predict_breakout.rb            # Evaluate trained model
│
├── data/
│   ├── ohlc_data.csv             # Generated OHLC data
│   └── metadata.json             # Dataset metadata
│
├── models/
│   ├── best_model.pt             # Trained model weights
│   └── training_info.json        # Training configuration
│
├── Gemfile
├── flake.nix                      # Nix development environment
└── README.md
```

## Installation

### Using Nix (Recommended)

```bash
# Enter development shell (Ruby 4.0 + libTorch)
direnv allow  # or: nix develop

# Install Ruby dependencies
bundle install
```

### Manual Installation

Requirements:
- Ruby 4.0+
- libTorch 2.10.0+
- Bundler

```bash
bundle install
```

## Usage

### 1. Generate Synthetic Data

```bash
# Generate 1000 samples (fast, for testing)
bundle exec ruby generate_data.rb 1000

# Generate 10,000 samples (recommended)
bundle exec ruby generate_data.rb 10000
```

**Output**:
- `data/ohlc_data.csv` - OHLC data with breakout labels
- `data/metadata.json` - Dataset statistics

**CSV Format**:
```
index,open,high,low,close,volume,breakout_label
0,100.0,100.62,99.81,100.0,883807,0
1,99.9,102.2,99.85,101.92,1170879,0
...
```

### 2. Train LSTM Model

```bash
# Train on 1000 samples (~2-3 minutes)
bundle exec ruby train_breakout_model.rb 1000

# Train on 10,000 samples (~10-15 minutes)
bundle exec ruby train_breakout_model.rb 10000
```

**Output**:
- `models/best_model.pt` - Trained model weights
- `models/training_info.json` - Training configuration & metrics

**Training Progress**:
```
Epoch   0: train_loss=0.488 val_loss=0.4234 ✓ saved
Epoch  10: train_loss=0.3279 val_loss=0.3058 ✓ saved
...
Early stopping triggered at epoch 42
```

### 3. Evaluate Model

```bash
# Evaluate on test set
bundle exec ruby predict_breakout.rb 10000
```

**Output Example** (10,000 samples):
```
Test Set Performance (threshold=0.5)
============================================================

Confusion Matrix:
                Predicted
                Breakout  Normal
  Actual Breakout    135     164
  Actual Normal       48    1146

Classification Metrics:
  Accuracy:  85.8%
  Precision: 73.77%
  Recall:    45.15%
  F1-Score:  56.02%

Probability Analysis:
  Avg prob for actual breakouts: 54.34%
  Avg prob for actual normal:    9.84%
  Separation: 44.5%
```

### 4. Using Real Data

Replace synthetic data by modifying the training/prediction scripts to load from `data/ohlc_data.csv`:

```ruby
# Read CSV
require 'csv'
csv_data = CSV.read("data/ohlc_data.csv", headers: true)

ohlc_data = {
  open: csv_data["open"].map(&:to_f),
  high: csv_data["high"].map(&:to_f),
  low: csv_data["low"].map(&:to_f),
  close: csv_data["close"].map(&:to_f),
  volume: csv_data["volume"].map(&:to_i)
}
```

## Technical Indicators (Features)

The model uses 11 engineered features:

### Price-Based (4)
- `returns_1d`: 1-day percentage returns
- `returns_5d`: 5-day percentage returns
- `hl_range`: High-low range / close (normalized daily range)
- `oc_diff`: Open-close difference / close

### Volatility-Based (4)
- `atr_14_norm`: 14-period ATR / close (normalized)
- `volatility_20d`: 20-day rolling volatility (annualized)
- `bb_width`: Bollinger Band width (normalized)
- `bb_position`: Price position within Bollinger Bands

### Momentum-Based (2)
- `rsi_14`: 14-period RSI (normalized 0-1)
- `ma_distance_20`: Distance from 20-period MA

### Volume-Based (1)
- `volume_ratio`: Volume / 20-period average

**Critical**: All features are shifted by 1 period to prevent lookahead bias.

## Performance Benchmarks

### Small Dataset (1,000 samples)
- Training time: ~2 minutes
- Accuracy: 91.6%
- Precision: 66.7% | Recall: 28.6%
- F1-Score: 40.0%

### Large Dataset (10,000 samples)
- Training time: ~10 minutes
- Accuracy: 85.8%
- Precision: 73.8% | Recall: 45.2%
- F1-Score: 56.0%

**Interpretation**:
- High precision means few false alarms (predicted breakouts are reliable)
- Moderate recall means model is conservative (misses some actual breakouts)
- For trading: High precision is often preferred over high recall

## Customization

### Adjust Breakout Definition

In `lib/breakout_labeler.rb`:
```ruby
labeler = BreakoutLabeler.new(
  atr_raw,
  threshold: 2.0,    # Increase for stricter breakouts (fewer positives)
  lookback: 20,      # Baseline volatility window
  lookahead: 10      # Prediction horizon (candles ahead)
)
```

### Modify Model Architecture

In `train_breakout_model.rb`:
```ruby
model = VolatilityBreakoutLSTM.new(
  num_features,
  hidden_size: 128,   # Increase for more capacity
  num_layers: 2,      # Add layers for deeper architecture
  dropout: 0.3        # Increase to reduce overfitting
)
```

### Tune Training Hyperparameters

In `train_breakout_model.rb`:
```ruby
SEQUENCE_LENGTH = 50          # Lookback window
BATCH_SIZE = 32               # Mini-batch size
EPOCHS = 500                  # Maximum epochs
LEARNING_RATE = 0.001         # Adam learning rate
EARLY_STOP_PATIENCE = 30      # Early stopping patience
```

### Adjust Prediction Threshold

In `predict_breakout.rb`:
```ruby
THRESHOLD = 0.5  # Lower = more predictions (higher recall)
                 # Higher = fewer predictions (higher precision)
```

## Implementation Details

### Preventing Lookahead Bias

1. **Feature Shifting**: All features shifted by 1 period (`lib/ohlc_features.rb:289`)
2. **Temporal Split**: Train/val/test split preserves time order (`lib/sequence_builder.rb:55`)
3. **Scaler Fitting**: Normalization fit only on training data (`train_breakout_model.rb:53`)

### Class Imbalance Handling

- **Class Weighting**: BCEWithLogitsLoss weighted by class ratio (e.g., 3.6:1)
- **Alternative**: Adjust sampling or use focal loss

### GARCH-Like Volatility Clustering

Synthetic data uses GARCH(1,1) model:
```ruby
σ²(t) = ω + α*r²(t-1) + β*σ²(t-1)
```
Where ω=0.00001, α=0.1, β=0.85 (high persistence)

## Files Reference

| File | Purpose | Lines |
|------|---------|-------|
| `lib/synthetic_ohlc.rb` | Generate synthetic OHLC with volatility patterns | 186 |
| `lib/ohlc_features.rb` | Calculate 11 technical indicators | 286 |
| `lib/breakout_labeler.rb` | Label volatility breakout periods | 64 |
| `lib/sequence_builder.rb` | Create LSTM sequences with sliding windows | 93 |
| `lib/volatility_lstm_model.rb` | 2-layer stacked LSTM model | 67 |
| `generate_data.rb` | Data generation → CSV export | 78 |
| `train_breakout_model.rb` | Full training pipeline | 200 |
| `predict_breakout.rb` | Model evaluation & metrics | 173 |

## Next Steps

### Experimentation Ideas

1. **Hyperparameter Tuning**:
   - Try different sequence lengths (30, 70, 100)
   - Experiment with hidden sizes (64, 256)
   - Test 3-layer LSTM

2. **Feature Engineering**:
   - Add more indicators (MACD, Stochastic, ADX)
   - Try polynomial features
   - Add lag features

3. **Alternative Architectures**:
   - GRU instead of LSTM (faster, similar performance)
   - Bidirectional LSTM
   - Attention mechanism

4. **Advanced Techniques**:
   - Multi-task learning (predict magnitude + direction)
   - Ensemble models
   - Walk-forward validation

5. **Real Data Integration**:
   - Connect to Alpha Vantage / Yahoo Finance API
   - Test on cryptocurrency data
   - Backtest trading strategies

## Troubleshooting

### Out of Memory
- Reduce `BATCH_SIZE` in training script
- Use smaller dataset for testing

### Slow Training
- Reduce `SEQUENCE_LENGTH` or `num_samples`
- Use CPU-optimized libTorch build

### Poor Performance
- Check class distribution (aim for 10-30% breakouts)
- Verify no lookahead bias in features
- Try adjusting breakout threshold

## References

- **torch-rb**: https://github.com/ankane/torch.rb
- **PyTorch LSTM Docs**: https://pytorch.org/docs/stable/generated/torch.nn.LSTM.html
- **GARCH Models**: Bollerslev (1986) - Generalized Autoregressive Conditional Heteroskedasticity
- **Technical Analysis**: Murphy, John J. (1999) - Technical Analysis of the Financial Markets

## License

MIT License - Feel free to use for research or trading experiments.

---

**Author**: Built with libTorch/torch-rb  
**Date**: 2026-05-13  
**Model Type**: Stacked LSTM (2 layers, 128 units)  
**Task**: Binary classification of volatility breakouts
