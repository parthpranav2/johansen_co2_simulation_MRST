function schedule = buildSchedule(W, simCfg)
%%--------------------------------------------------------------------------
% BUILDSCHEDULE Build time-stepping schedule and active well control states
%
% Inputs:
%   W      - Array of MRST well structures with startYear and endYear fields
%   simCfg - (Optional) Simulation configuration structure from simulationConfig()
%
% Outputs:
%   schedule - MRST schedule structure containing time steps and control blocks
%%--------------------------------------------------------------------------

    %% ---------------------------------------------------------------------
    % Default Configuration if not provided
    %% ---------------------------------------------------------------------
    if nargin < 2 || isempty(simCfg)
        simCfg = simulationConfig();
    end

    %% ---------------------------------------------------------------------
    % Simulation Time Parameters from Config
    %% ---------------------------------------------------------------------
    totalTime = simCfg.totalTime;
    nSteps    = simCfg.numSteps;
    dt        = rampupTimesteps(totalTime, totalTime / nSteps);

    %% ---------------------------------------------------------------------
    % Allocate Schedule Structure
    %% ---------------------------------------------------------------------
    schedule.step.val     = dt;
    schedule.step.control = zeros(numel(dt), 1);
    schedule.control      = struct([]);

    %% ---------------------------------------------------------------------
    % Construct Control Structures per Timestep
    %% ---------------------------------------------------------------------
    currentTime = 0;

    for s = 1:numel(dt)
        currentYear = currentTime / year;
        Wstep       = W;

        for w = 1:numel(W)
            if currentYear >= W(w).startYear && currentYear < W(w).endYear
                Wstep(w).status = true;
            else
                Wstep(w).status = false;
            end
        end

        schedule.control(s).W    = Wstep;
        schedule.step.control(s) = s;

        currentTime = currentTime + dt(s);
    end

    %% ---------------------------------------------------------------------
    % Display Summary
    %% ---------------------------------------------------------------------
    fprintf("\n=====================================\n");
    fprintf("Simulation Schedule Created\n");
    fprintf("=====================================\n");
    fprintf("Total Time : %.1f years\n", totalTime / year);
    fprintf("Timesteps  : %d steps\n", numel(dt));
    fprintf("Controls   : %d control blocks\n", numel(schedule.control));
    fprintf("=====================================\n");

end
