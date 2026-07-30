function [ws, states, report] = simulateHybrid(model, state0, schedule)
%%--------------------------------------------------------------------------
% SIMULATEHYBRID Run non-linear AD simulation using MRST simulateScheduleAD
%
% Inputs:
%   model    - Upscaled Hybrid-VE AD model
%   state0   - Upscaled initial state
%   schedule - Upscaled schedule structure
%
% Outputs:
%   ws     - Well solutions across all timesteps
%   states - Reservoir states across all timesteps
%   report - Nonlinear solver report and statistics
%%--------------------------------------------------------------------------

    fprintf('\n=====================================\n');
    fprintf('Starting Hybrid-VE AD Simulation Execution\n');
    fprintf('=====================================\n');

    %% ---------------------------------------------------------------------
    % Execute Solver
    %% ---------------------------------------------------------------------
    [ws, states, report] = simulateScheduleAD(state0, model, schedule);

    fprintf('=====================================\n');
    fprintf('Hybrid-VE Simulation Completed Successfully.\n');
    fprintf('=====================================\n');

    %% ---------------------------------------------------------------------
    % Save Results to MAT File
    %% ---------------------------------------------------------------------
    save('simulationResults.mat', 'ws', 'states', 'report', 'model');
    fprintf('Results saved to simulationResults.mat\n');

end
