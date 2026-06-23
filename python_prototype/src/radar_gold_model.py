# simulate a FMCW (Frequency Modulated Continuous Wave) radar receiver frame
#This script generates synthetic radar data representing a single target moving at a specific velocity.
#applies a Hanning window, computes the 2D FFT (Range-Doppler map), and exports the files.
import os
import numpy as np
import scipy.io as sio

def generate_radar_cube():
    # 1. Define Radar System & Scene Constraints
    num_samples = 128  # Range bins (Fast-time samples per chirp)
    num_chirps = 64    # Doppler bins (Slow-time chirps per frame)
    
    # Target Ground Truth
    target_range_bin = 42    # Simulated beat frequency index (Distance)
    target_doppler_bin = 18  # Simulated phase shift index (Velocity)
    
    print(f"[Python] Simulating target at Range Bin {target_range_bin}, Doppler Bin {target_doppler_bin}...")

    # 2. Generate Synthetic FMCW ADC Beat Signals
    # Initialize an empty array for our 2D Radar Frame Data Cube
    raw_cube_raw = np.zeros((num_chirps, num_samples), dtype=np.complex64)
    
    for chirp_idx in range(num_chirps):
        # Fast-time time vector for a single chirp
        t_fast = np.arange(num_samples)
        
        # Range component: frequency of the sine wave
        # Doppler component: phase shift added frame-to-frame from chirp to chirp
        phase_shift = 2 * np.pi * target_doppler_bin * chirp_idx / num_chirps
        signal = np.exp(1j * (2 * np.pi * target_range_bin * t_fast / num_samples + phase_shift))
        
        # Inject white Gaussian noise to make it realistic for signal processing
        noise = (np.random.normal(0, 0.2, num_samples) + 1j * np.random.normal(0, 0.2, num_samples))
        raw_cube_raw[chirp_idx, :] = signal + noise
    # Transpose the raw cube here so Python dimensions match your C layout [128 samples x 64 chirps]
    raw_cube = raw_cube_raw.T

    # 3. Process 2D FFT Gold Model (The Mathematical Reference)
    # Range Processing (Fast-Time Windowing + 1D FFT along rows)
    # Hanning window -> reduces spectral leakage from high-power targets
    window = np.hanning(num_samples)[:, np.newaxis]
    windowed_data = raw_cube * window
    # range_fft = np.fft.fft(windowed_data, axis=0)
    # Too match scaling behavior of the hardware - divide by number of samples
    range_fft = np.fft.fft(windowed_data, axis=0) / num_samples  # Added 1/128 scaling 
    
    # Doppler Processing (Slow-Time 1D FFT along columns)
    range_doppler_raw = np.fft.fft(range_fft, axis=1)
    
    # Transpose the final matrix to align Python's memory layout with your C logic
    range_doppler = range_doppler_raw.T

    # 4. Prepare Export Directories
    data_dir = os.path.join(os.path.dirname(__file__), '..', 'data')
    os.makedirs(data_dir, exist_ok=True)

    # 5. Export Data Matrices -> for Simulink Injection & Verification
    # Conversion to real and imaginary splits -> since Simulink/C handles fixed-point arrays cleanly this way
    sio.savemat(os.path.join(data_dir, 'radar_input.mat'), {
        'raw_cube_real': np.real(raw_cube).astype(np.float32),
        'raw_cube_imag': np.imag(raw_cube).astype(np.float32)
    })
    
    sio.savemat(os.path.join(data_dir, 'python_gold.mat'), {
        'range_doppler_real': np.real(range_doppler).astype(np.float32),
        'range_doppler_imag': np.imag(range_doppler).astype(np.float32)
    })
    
    print("[Python] Gold Model generation complete. Matrices exported to 'python_prototype/data/'.")

if __name__ == "__main__":
    generate_radar_cube()
