import numpy as np
import matplotlib.pyplot as plt

# Parameters
f = 10  # Higher frequency to show multiple cycles
bit_duration = 1.0  # Duration of each symbol
sample_rate = 1000  # More samples for smoother curves

# 8-ASK amplitude levels (8 different amplitudes for 3-bit combinations)
# Each amplitude represents 3 bits
amplitudes = np.linspace(1/8, 1, 8)  # Equally spaced from 1/8 to 1

# Bit combinations (3 bits each)
bit_combinations = [
    '000', '001', '010', '011', 
    '100', '101', '110', '111'
]

# Generate side-by-side waveforms (like in the slide example)
total_duration = 8 * bit_duration  # Total time for all 8 symbols
t_total = np.linspace(0, total_duration, int(total_duration * sample_rate))

# Create combined waveform with all 8 symbols side by side
combined_waveform = np.zeros_like(t_total)

# Colors for each waveform
colors = ["red", "orange", "yellow", "green", "blue", "indigo", "purple", "brown"]

for i, (amp, bits) in enumerate(zip(amplitudes, bit_combinations)):
    # Time segment for this symbol
    start_idx = int(i * bit_duration * sample_rate)
    end_idx = int((i + 1) * bit_duration * sample_rate)
    
    # Generate waveform for this time segment
    t_segment = t_total[start_idx:end_idx]
    waveform = amp * np.cos(2 * np.pi * f * t_segment)
    combined_waveform[start_idx:end_idx] = waveform

# Create the plot (similar to slide style)
plt.figure(figsize=(12, 8))

# Plot the combined waveform with different colors for each segment
for i, (amp, bits, color) in enumerate(zip(amplitudes, bit_combinations, colors)):
    start_idx = int(i * bit_duration * sample_rate)
    end_idx = int((i + 1) * bit_duration * sample_rate)
    
    plt.plot(t_total[start_idx:end_idx], combined_waveform[start_idx:end_idx], 
             color=color, linewidth=2, label=f'"{bits}"')

# Add vertical lines to separate symbols
for i in range(1, 8):
    plt.axvline(x=i, color='black', linestyle='-', alpha=0.5)

plt.xlabel('Time', fontsize=14)
plt.ylabel('Amplitude', fontsize=14)
plt.ylim(-1.1, 1.1)
plt.xlim(0, 8)
plt.legend(loc='upper left', ncol=4, fontsize=10)
plt.grid(True, alpha=0.3)

# Add x-axis labels (0-8)
plt.xticks(range(9))

plt.tight_layout()
plt.savefig('/home/joe/code/2025-NASA/Lab/Lab11/b11901164.png', dpi=300, bbox_inches='tight')
plt.show()
