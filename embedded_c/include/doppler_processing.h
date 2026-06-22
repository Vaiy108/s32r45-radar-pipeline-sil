#ifndef DOPPLER_PROCESSING_H
#define DOPPLER_PROCESSING_H

#define NUM_SAMPLES 128   /* Fast-time range bins */
#define NUM_CHIRPS  64    /* Slow-time Doppler bins */

/**
 * @brief Computes a 1D DFT across the chirp dimension (slow-time) for a given range bin.
 *        Emulates execution on an ARM Cortex-A53 real-time core.
 * 
 * @param in_real   Pointer to the 2D input matrix real components [128 x 64]
 * @param in_imag   Pointer to the 2D input matrix imaginary components [128 x 64]
 * @param out_real  Pointer to the output matrix real components [128 x 64]
 * @param out_imag  Pointer to the output matrix imaginary components [128 x 64]
 */
void process_doppler_frame(const float* in_real, const float* in_imag,
                           float* out_real, float* out_imag);

#endif /* DOPPLER_PROCESSING_H */
