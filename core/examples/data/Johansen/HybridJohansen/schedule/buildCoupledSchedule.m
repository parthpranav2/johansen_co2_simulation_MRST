function schedule = buildCoupledSchedule(W, simCfg, flCfg)
%%--------------------------------------------------------------------------
% BUILDCOUPLEDSCHEDULE Build coupled injection-extraction control schedule
%
% Description:
%   Generates a multi-step simulation schedule coupling CO2 injection with
%   down-flank brine production for active pressure management.
%
% Inputs:
%   W      - MRST well structure array containing injectors and producers
%   simCfg - Simulation configuration structure
%   flCfg  - Fluid configuration structure
%
% Outputs:
%   schedule - MRST simulation schedule structure
%%--------------------------------------------------------------------------

    fprintf('\n=====================================\n');
    fprintf('Building Coupled Injection-Extraction Schedule\n');
    fprintf('=====================================\n');

    nInjSteps   = round(simCfg.injectionYears * 12); % Monthly timesteps
    nShutSteps  = round(simCfg.shutinYears * 4);     % Quarterly timesteps

    dtInj  = repmat(year / 12, nInjSteps, 1);
    dtShut = repmat(year / 4, nShutSteps, 1);

    dtVec = [dtInj; dtShut];

    %% ---------------------------------------------------------------------
    % Construct Control 1: Active Injection + Active Brine Relief
    %% ---------------------------------------------------------------------
    W_active = W;
    for w = 1:numel(W_active)
        if W_active(w).sign > 0
            W_active(w).status = true;
        else
            W_active(w).status = true;
        end
    end

    %% ---------------------------------------------------------------------
    % Construct Control 2: Post-Injection Shut-in Phase
    %% ---------------------------------------------------------------------
    W_shutin = W;
    for w = 1:numel(W_shutin)
        if W_shutin(w).sign > 0
            W_shutin(w).val    = 0;
            W_shutin(w).status = false;
        else
            W_shutin(w).status = true;
        end
    end

    %% ---------------------------------------------------------------------
    % Assemble Schedule Structure
    %% ---------------------------------------------------------------------
    schedule.control(1).W = W_active;
    schedule.control(2).W = W_shutin;

    stepControl = [ones(nInjSteps, 1); repmat(2, nShutSteps, 1)];

    schedule.step.val     = dtVec;
    schedule.step.control = stepControl;

    fprintf('Coupled Schedule Created:\n');
    fprintf('  Active Injection Steps  : %d timesteps (%.1f Years)\n', nInjSteps, simCfg.injectionYears);
    fprintf('  Post-Injection Shut-in  : %d timesteps (%.1f Years)\n', nShutSteps, simCfg.shutinYears);
    fprintf('=====================================\n');

end
