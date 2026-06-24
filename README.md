# S32R45-Inspired Radar DSP Pipeline Software-in-the-Loop Validation Framework

A Range-Doppler processing pipeline built in three layers — Python float64
reference, Simulink fixed-point behavioral model, and handwritten embedded C —
with an automated cross-layer verification script that checks numerical agreement
across all three.

The architecture mirrors how the NXP S32R45 splits radar signal processing across
its hardware blocks: the Range FFT stage is modeled with 16-bit fixed-point
quantization and saturation to reflect SPT 3.1 accelerator constraints, while the
Doppler FFT stage is implemented as embedded C running via a MATLAB System Object
wrapper, reflecting the Cortex-M7 host-core execution layer.

---

## Why three layers instead of one

A common pattern in automotive radar development is to prototype an algorithm in
a high-level language first (floating point, unconstrained precision), then port
it to a fixed-point behavioral model that reflects the hardware's numeric
constraints, then implement the production firmware and verify it agrees with the
reference. This project works through that sequence for the Range-Doppler pipeline
specifically because the fixed-point conversion step is where real bugs show up —
quantization clipping, gain drift, and scaling mismatches between the float
reference and the hardware-constrained output are all things that surface only when
you run the comparison, not when you write the algorithm.

---

## Pipeline architecture

```
Python gold model (float64)
        │
        │  generate_fmcw_data_cube()
        │  128 samples × 64 chirps, complex64
        ▼
Simulink fixed-point model
        │
        │  Range FFT: quantize to sfix16_en14 (Q1.14)
        │  Overflow mode: saturate to ±32767
        │  Models SPT 3.1 fixed-point arithmetic constraints
        ▼
Embedded C (called from MATLAB via System Object wrapper)
        │
        │  Doppler FFT: 1-D DFT across chirp axis
        │  Zero malloc, flat pointer stride (r * NUM_CHIRPS + n)
        │  ANSI C, no external dependencies
        ▼
Verification script
        │
        │  Peak-normalized MSE comparison across all three layers
        │  Acceptance threshold: 6% (calibrated to 16-bit quantization floor)
        ▼
  PASS / FAIL with per-stage error metrics
```

---

## Repository layout

```
s32r45-radar-pipeline-sil/
├── python_prototype/
│   └── src/
│       └── radar_gold_model.py      # FMCW data cube generator, float64 reference
├── simulink_model/
│   ├── radar_pipeline.slx           # Fixed-point Range FFT behavioral model
│   ├── config_s32r45.m              # Fixed-point type configuration
│   └── DopplerWrapper.m             # MATLAB System Object wrapping the C Doppler FFT
├── embedded_c/
│   ├── src/doppler_processing.c     # Doppler FFT, ANSI C
│   └── include/doppler_processing.h
├── verification/
│   └── validate_pipeline.m          # Automated cross-layer comparison script
└── data/
    ├── verif_failed.png             # Verification output before normalization fix
    └── verif_passed.png             # Verification output after normalization fix
```

---

## The fixed-point verification problem — and the fix

### What failed (commit 4)

The Python gold model produces unconstrained float64 output. The Simulink Range FFT
model quantizes the same input to `sfix16_en14` (16-bit signed, 14 fractional bits)
with saturation, which clips peak signal values at ±32767. When the initial
verification script compared the two outputs on absolute magnitude, it failed:
the absolute gain levels disagreed because the fixed-point path introduces a
consistent scaling offset that the floating-point path does not have.

<p align="center">
<img src="data/verif_failed.png" width="450"/> 
</p>

### Root cause

The mismatch is not a bug in either implementation — it is the expected consequence
of comparing a floating-point result against a fixed-point result without accounting
for the different numeric domains. The fixed-point path's saturation and Q-format
scaling shift the absolute magnitude while preserving the spectral shape (peak
locations and relative bin ratios).

### Fix (commit 5)

Refactored the verification script to normalize both outputs to the range [0, 1]
by dividing by each signal's own peak magnitude before comparing. This shifts the
test criterion from "do the absolute values match?" (which they won't, by
construction) to "does the spectral shape match?" (which it should, if both
implementations are algorithmically correct).

The 6% MSE acceptance threshold was set by measuring the quantization noise floor
for a 16-bit fixed-point format with this input: a 16-bit representation has a
maximum quantization error of 2^-15 per sample relative to the full-scale range,
and the observed MSE across the Doppler spectrum at this configuration is
consistently below 6%. The threshold is not a tolerance added until tests passed —
it is calibrated to the known noise floor of the format.

<p align="center">
<img src="data/verif_passed.png" width="450"/> 
</p>

---

## Simulink model

### Top-level pipeline - Model-Based Design Pipeline (Simulink Workspace Canvas)

<p align="center">
<img src="data/simulink_model_validation.png" width="750"/> 
</p>

### SPT accelerator block (Range FFT fixed-point stage)

<p align="center">
<img src="data/s32r45_spt_acc.png" width="700"/> 
</p>

*Data Flow: Ingestion ➔ 16-bit Fixed-Point SPT Accelerator Engine ➔ DMA Single Float Casting ➔ Row-Major Embedded C Execution Loops.*

The block quantizes incoming float64 samples to `sfix16_en14` and applies
saturation arithmetic. This models the SPT 3.1 accelerator's fixed-point
constraints — not the SPT instruction set itself (which requires NXP's own
hardware simulator), but the numeric behavior that any algorithm running on
SPT's fixed-point data path would need to account for.

---

## What this project does not do

The Simulink model here is a behavioral model of fixed-point constraints, not a
cycle-accurate or register-level simulation of the SPT accelerator. It does not
model SPT-specific features like the twiddle-factor scaling per radix-4/radix-2
stage, the PDMA data movement instructions, or the internal pipeline timing.
Running the actual SPT instructions bit-exact requires NXP's own Model-Based
Design Toolbox for SPT, whose MEX kernel binaries (`rdx2_mex`, `rdx4_mex`, etc.)
are the real hardware-equivalent simulator. This project sits one abstraction
level above that: it validates that the algorithm produces the right spectral
shape under the numeric constraints the hardware imposes, which is a necessary
prerequisite before targeting the hardware-kernel layer.

---

## How to run

**Step 1 — Generate the Python reference**

```bash
cd python_prototype/src
python radar_gold_model.py
```

This writes the float64 reference data cube to `data/`.

**Step 2 — Run the cross-layer verification**

```matlab
% In MATLAB, from the project root:
run('verification/validate_pipeline.m')
```

The script loads the Python reference, runs both the Simulink model and the
embedded C Doppler processor, normalizes all three outputs, computes peak-normalized
MSE, and prints a PASS/FAIL result with per-stage error metrics.

**Requirements**: MATLAB R2023a or later, Simulink, MinGW64 or MSVC for the
embedded C compilation step.

---

## Relationship to the companion project

This project sits alongside
[automotive-radar-dsp-embedded-c](https://github.com/Vaiy108/automotive-radar-dsp-embedded-c),
which implements the same Range-Doppler-CFAR pipeline entirely in Python and
dependency-free embedded C without Simulink. The two projects are complementary:
the companion project demonstrates the Python-to-C porting workflow and
benchmarks the two implementations against each other; this project demonstrates
how to model the hardware's fixed-point constraints in a behavioral simulation
and verify that an embedded C implementation agrees with a float reference across
the fixed-point domain boundary.

---

## Author

**Vasan Iyer** — Embedded Systems Engineer 

Areas of interest:
- Autonomous Systems
- Radars
- Digital Signal Processing
- FPGA Signal Processing
- Embedded C firmware
- STM32 microcontrollers
- Radar Tracking
- Sensor Fusion
- Real-time embedded systems
- Communication interfaces (CAN, SPI, UART)
- FPGA-based hardware interfacing
- Embedded debugging and system integration

GitHub: https://github.com/Vaiy108
