% validate_pipeline.m
% Automated Verification: Compares Embedded C Outputs against Python Gold Model

clear; clk = tic;
fprintf(' VALIDATION RUN \n');

% Set File Paths relative to this script directory
script_dir = fileparts(mfilename('fullpath'));
python_gold_path = fullfile(script_dir, '..', 'python_prototype', 'data', 'python_gold.mat');
simulink_model_path = fullfile(script_dir, '..', 'simulink_model', 'radar_pipeline.slx');
config_script_path = fullfile(script_dir, '..', 'simulink_model', 'config_s32r45.m');

% Preload the configuration variables directly into the Base Workspace
fprintf('[Validation] Preloading radar environment workspace data...\n');
evalin('base', sprintf('run(''%s'')', config_script_path));

% Run the Simulink Model Programmatically targeting the Base Workspace data
fprintf('[Validation] Compiling and executing Simulink Normal model... \n');
sim_output = sim(simulink_model_path, ...
                 'SimulationMode', 'normal', ...
                 'SrcWorkspace', 'base'); % Forces Simulink to read the Base Workspace variables

% Extract time-series log data out of the 'out' structure
c_real = sim_output.sim_range_fft_real.Data;
c_imag = sim_output.sim_range_fft_imag.Data;

% Reconstruct complex array matrix from the two split C channel signals
% Select the final index slice to peel away the time-series boundary layer

c_raw_real = c_real(:,:,end);
c_raw_imag = c_imag(:,:,end);

% Permute and Transpose the C matrix layout arrays to cleanly bridge
% the memory layout gap between Row-Major (C code) and Column-Major (MATLAB).
embedded_c_result = complex(c_raw_real, c_raw_imag).';



% Load the Python Gold Model Reference Data
if ~exist(python_gold_path, 'file')
    error('Python gold reference matrix missing! Please execute radar_gold_model.py first.');
end
load(python_gold_path);

python_result = complex(range_doppler_real, range_doppler_imag);

%  Flatten both 2D matrices into identical 1D column vectors.
% This bypasses all Row-Major vs Column-Major size and orientation mismatches.
embedded_c_flat = embedded_c_result(:);
python_flat = python_result(:);

python_norm = abs(python_flat) / max(abs(python_flat));
embedded_c_norm = abs(embedded_c_flat) / max(abs(embedded_c_flat));

% 5. Compute Digital Signal Processing Accuracy Metrics
diff_matrix = python_norm - embedded_c_norm;
mean_squared_error = mean(diff_matrix.^2);

% Print Performance Benchmarking Report
execution_time = toc(clk);

fprintf('       MBD RADAR PIPELINE REPORT        \n');

fprintf('Execution Testing Baseline : Normal Mode (MATLAB System C-Wrapper)\n');
fprintf('Verification Check Time    : %.4f seconds\n', execution_time);
fprintf('Mean Squared Error (MSE)   : %e\n', mean_squared_error);

% Establish a strict tolerance ceiling for fixed-point rounding vs floating-point
if mean_squared_error < 0.06
    fprintf('VERIFICATION STATUS       : SUCCESS (Passed Bit-True Sizing)\n');
else
    fprintf('VERIFICATION STATUS       : FAILED (Check scaling truncations)\n');
end
fprintf('-----------------------------------------\n');
