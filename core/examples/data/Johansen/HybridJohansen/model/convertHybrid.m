function [model_hyb, state_hyb, schedule_hyb] = convertHybrid(model, state0, schedule)
%%--------------------------------------------------------------------------
% CONVERTHYBRID Upscale standard 3D model, state, and schedule to Hybrid-VE
%
% Inputs:
%   model    - Standard 3D AD reservoir model
%   state0   - Initial 3D reservoir state
%   schedule - Initial 3D simulation schedule
%
% Outputs:
%   model_hyb    - Upscaled Hybrid-VE model
%   state_hyb    - Upscaled initial state for Hybrid-VE
%   schedule_hyb - Upscaled schedule for Hybrid-VE
%%--------------------------------------------------------------------------

    fprintf('\n=====================================\n');
    fprintf('Converting Model to Hybrid-VE Format\n');
    fprintf('=====================================\n');

    %% ---------------------------------------------------------------------
    % 1. Model Upscaling
    %% ---------------------------------------------------------------------
    fprintf('1/3  Converting 3D model to MultiVE Model...\n');
    model_hyb = convertToMultiVEModel(model);

    %% ---------------------------------------------------------------------
    % 2. State Upscaling
    %% ---------------------------------------------------------------------
    fprintf('2/3  Upscaling initial state...\n');
    state_hyb = upscaleState(model_hyb, model, state0);

    %% ---------------------------------------------------------------------
    % 3. Schedule Upscaling
    %% ---------------------------------------------------------------------
    fprintf('3/3  Upscaling simulation schedule...\n');
    schedule_hyb = upscaleSchedule(model_hyb, schedule);

    fprintf('=====================================\n');
    fprintf('Hybrid-VE conversion completed successfully.\n');
    fprintf('=====================================\n');

end
