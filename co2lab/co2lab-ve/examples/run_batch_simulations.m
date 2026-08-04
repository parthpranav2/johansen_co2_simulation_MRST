% run_batch_simulations.m
% Runs example3DJohansen.m N times consecutively, synchronising with the Python BO script.

N = 45 ; % Number of simulations to run

PYTHON_DIR = fullfile('/Users/apple/Desktop/study/programming/Matlab/Plugins/', ...
    'MRST-2026a/core/examples/data/Johansen/python');
boSignalPath = fullfile(PYTHON_DIR, 'bo_signal.json');
boPendingPath = fullfile(PYTHON_DIR, 'bo_pending.json');

fprintf('\n=======================================================\n');
fprintf(' Starting BO Batch Runner for %d simulations...\n', N);
fprintf('=======================================================\n\n');

for i = 1:N
    fprintf('>>> Batch Run %d of %d <<<\n', i, N);
    fprintf('Waiting for Python optimizer to propose next parameters...\n');
    
    % Polling loop: Wait for Python to signal readiness.
    % Python writes the new plan, writes bo_pending.json, and deletes bo_signal.json.
    % MATLAB knows Python is ready when bo_pending exists and bo_signal is gone.
    while true
        if ~isfile(boSignalPath) && isfile(boPendingPath)
            break;
        end
        pause(10);
    end
    
    % Give Python an extra second to ensure well_plan.csv is fully flushed to disk
    pause(1);
    
    fprintf('Parameters received from Python! Starting simulation %d...\n', i);
    
    % Run the simulation script
    try
        % The simulation clears figures and saves them silently if DISPLAY_FIGURES = false
        example3DJohansen;
    catch e
        fprintf(2, '\nERROR during simulation %d:\n%s\n', i, e.message);
        fprintf(2, 'Aborting batch runner.\n');
        break;
    end
    
    % The example script drops bo_signal.json at the end.
    fprintf('Simulation %d complete! Handshake signal sent to Python.\n\n', i);
    
    % Small pause to prevent MATLAB from looping too fast before Python catches the signal
    pause(2);
end

fprintf('=======================================================\n');
fprintf(' Batch runner finished.\n');
fprintf('=======================================================\n');
% Alert the user that the simulation is complete
beep; pause(0.5); beep;