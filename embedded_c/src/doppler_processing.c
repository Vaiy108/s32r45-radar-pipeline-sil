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
    /* CFAR BLOCK: Real-time thresholding */

    int T_R = 4, T_C = 2, G_R = 2, G_C = 1;
    float alpha = 5.0f;
    int num_train = (2*T_R + 2*G_R + 1) * (2*T_C + 2*G_C + 1) - (2*G_R + 1) * (2*G_C + 1);

    for (int r = T_R + G_R; r < NUM_SAMPLES - (T_R + G_R); r++) {
        for (int c = T_C + G_C; c < NUM_CHIRPS - (T_C + G_C); c++) {
            float noise_sum = 0.0f;

            /* Slide 2D window over local SRAM cells */
            for (int wr = -T_R - G_R; wr <= T_R + G_R; wr++) {
                for (int wc = -T_C - G_C; wc <= T_C + G_C; wc++) {
                    /* To Check if inside guard cell exclusion window zone */
                    if (abs(wr) <= G_R && abs(wc) <= G_C) {
                        continue; 
                    }
                    int n_idx = (r + wr) * NUM_CHIRPS + (c + wc);
                    noise_sum += sqrtf(out_real[n_idx]*out_real[n_idx] + out_imag[n_idx]*out_imag[n_idx]);
                }
            }

            float noise_floor = noise_sum / num_train;
            int cut_idx = r * NUM_CHIRPS + c;
            float cut_mag = sqrtf(out_real[cut_idx]*out_real[cut_idx] + out_imag[cut_idx]*out_imag[cut_idx]);

            /* If cell under test crosses threshold, amplify it. If noise, suppress to zero. */
            if (cut_mag <= (alpha * noise_floor)) {
                out_real[cut_idx] = 0.0f;
                out_imag[cut_idx] = 0.0f;
            }
        }
    }
}
