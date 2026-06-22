#include "doppler_processing.h"
#include <math.h>

#define PI 3.14159265358979323846f

void process_doppler_frame(const float* in_real, const float* in_imag,
                           float* out_real, float* out_imag)
{
    /* Loop over every Range Bin (Rows) */
    for (int r = 0; r < NUM_SAMPLES; r++) 
    {
        /* Loop for Computing 1D DFT across the Chirps (Columns) for this specific range row */
        for (int k = 0; k < NUM_CHIRPS; k++) 
        {
            float sum_real = 0.0f;
            float sum_imag = 0.0f;

            for (int n = 0; n < NUM_CHIRPS; n++) 
            {
                /* phase rotation factor calculation for Doppler frequency index k */
                float angle = (2.0f * PI * k * n) / NUM_CHIRPS;
                float cos_val = cosf(angle);
                float sin_val = sinf(angle);

                /* Flat 1D index mapping for 2D array: [row * NUM_CHIRPS + col] */
                int idx = r * NUM_CHIRPS + n;

                /* Complex multiplication: (A + jB) * (cos - jsin) */
                sum_real += in_real[idx] * cos_val + in_imag[idx] * sin_val;
                sum_imag += -in_real[idx] * sin_val + in_imag[idx] * cos_val;
            }

            /* Store the result in the current Range-Doppler matrix coordinate */
            int out_idx = r * NUM_CHIRPS + k;
            out_real[out_idx] = sum_real;
            out_imag[out_idx] = sum_imag;
        }
    }
}
