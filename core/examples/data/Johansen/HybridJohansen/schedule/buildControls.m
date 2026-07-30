function [schedule, controls] = buildControls(W, simCfg, flCfg)
%%--------------------------------------------------------------------------
% BUILDCONTROLS Generate dynamic well controls and time-stepping schedule
%
% Description:
%   Constructs an MRST simulation schedule supporting:
%     1. Multi-phase temporal scheduling (Active Injection vs Shut-in/Plume Migration).
%     2. Dynamic injection rate profiling (Constant, Ramp-up, Step-wise, Seasonal).
%     3. Automatic well status switching based on start/end operational windows.
%
% Inputs:
%   W      - Array of MRST well structures
%   simCfg - Simulation configuration from simulationConfig()
%   flCfg  - Fluid configuration from fluidConfig()
%
% Outputs:
%   schedule - MRST schedule structure with steps and control blocks
%   controls - Cell array of distinct control structures
%%--------------------------------------------------------------------------

    if nargin < 2 || isempty(simCfg)
        simCfg = simulationConfig();
    end
    if nargin < 3 || isempty(flCfg)
        flCfg = fluidConfig();
    end

    %% ---------------------------------------------------------------------
    % Timestep Generation (Ramp-up during initial injection, smooth steps)
    %% ---------------------------------------------------------------------
    totalTime    = simCfg.totalTime;
    injTime      = simCfg.injectionYears * year;
    shutinTime   = totalTime - injTime;
    
    nInjSteps    = round(simCfg.numSteps * (injTime / totalTime));
    nShutinSteps = simCfg.numSteps - nInjSteps;

    % Timesteps for injection phase
    dtInj = rampupTimesteps(injTime, injTime / max(nInjSteps, 10));
    
    % Timesteps for post-injection shut-in phase (if shut-in exists)
    if shutinTime > 0
        dtShut = rampupTimesteps(shutinTime, shutinTime / max(nShutinSteps, 10));
        dt = [dtInj; dtShut];
    else
        dt = dtInj;
    end

    %% ---------------------------------------------------------------------
    % Allocate Schedule Structure
    %% ---------------------------------------------------------------------
    nSteps = numel(dt);
    schedule.step.val     = dt;
    schedule.step.control = (1:nSteps)';
    schedule.control      = struct([]);

    %% ---------------------------------------------------------------------
    % Build Dynamic Control for Each Timestep
    %% ---------------------------------------------------------------------
    currentTime = 0;

    for s = 1:nSteps
        currentYear = currentTime / year;
        Wstep       = W;

        for w = 1:numel(W)
            isInjector = (W(w).sign > 0);

            % Check well operational time window
            inWindow = (currentYear >= W(w).startYear) && ...
                       (currentYear < W(w).endYear) && ...
                       (currentYear < simCfg.injectionYears);

            if inWindow
                Wstep(w).status = true;

                if isInjector
                    % Apply synthetic injection profile
                    baseRate = W(w).val; % Base volumetric rate in m^3/s

                    switch lower(simCfg.injectionProfile)
                        case 'rampup'
                            % Linear ramp-up over first rampupYears
                            rampYears = simCfg.rampupYears;
                            if currentYear < rampYears
                                factor = max(0.1, currentYear / rampYears);
                            else
                                factor = 1.0;
                            end
                            Wstep(w).val = baseRate * factor;

                        case 'stepwise'
                            % Step increases every 3 years
                            if currentYear < 3
                                factor = 0.5;
                            elseif currentYear < 6
                                factor = 0.75;
                            else
                                factor = 1.0;
                            end
                            Wstep(w).val = baseRate * factor;

                        case 'seasonal'
                            % Annual sinusoidal variation (+/- 25%)
                            factor = 1.0 + 0.25 * sin(2 * pi * currentYear);
                            Wstep(w).val = baseRate * factor;

                        otherwise % 'constant'
                            Wstep(w).val = baseRate;
                    end
                end
            else
                % Shut-in well
                Wstep(w).status = false;
                if isInjector
                    Wstep(w).val = 0;
                end
            end
        end

        schedule.control(s).W = Wstep;
        currentTime = currentTime + dt(s);
    end

    controls = schedule.control;

    %% ---------------------------------------------------------------------
    % Display Summary
    %% ---------------------------------------------------------------------
    fprintf("\n=====================================\n");
    fprintf("Dynamic Schedule & Controls Created\n");
    fprintf("=====================================\n");
    fprintf("Total Simulation Window : %.1f years\n", totalTime / year);
    fprintf("Injection Duration      : %.1f years\n", simCfg.injectionYears);
    fprintf("Shut-in / Plume Migration: %.1f years\n", shutinTime / year);
    fprintf("Injection Profile       : %s\n", simCfg.injectionProfile);
    fprintf("Total Timesteps         : %d steps\n", nSteps);
    fprintf("=====================================\n");

end
