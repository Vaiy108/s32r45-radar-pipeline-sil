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
embedded_c_result = complex(c_real(:,:,end), c_imag(:,:,end));

% Load the Python Gold Model Reference Data
if ~exist(python_gold_path, 'file')
    error('Python gold reference matrix missing! Please execute radar_gold_model.py first.');
end
load(python_gold_path);
python_result = complex(range_doppler_real, range_doppler_imag);

% Compute Digital Signal Processing Accuracy Metrics
% Calculate absolute magnitude variance between the two software layers
diff_matrix = abs(python_result - embedded_c_result);
mean_squared_error = mean(diff_matrix(:).^2);

% Print Performance Benchmarking Report
execution_time = toc(clk);

fprintf('       MBD RADAR PIPELINE REPORT        \n');

fprintf('Execution Testing Baseline : Normal Mode (MATLAB System C-Wrapper)\n');
fprintf('Verification Check Time    : %.4f seconds\n', execution_time);
fprintf('Mean Squared Error (MSE)   : %e\n', mean_squared_error);

% Establish a strict tolerance ceiling for fixed-point rounding vs floating-point
if mean_squared_error < 1e-2
    fprintf('VERIFICATION STATUS       : SUCCESS (Passed Bit-True Sizing)\n');
else
    fprintf('VERIFICATION STATUS       : FAILED (Check scaling truncations)\n');
end
fprintf('-----------------------------------------\n');
