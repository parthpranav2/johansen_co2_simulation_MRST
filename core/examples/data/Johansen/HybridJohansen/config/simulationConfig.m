function cfg = simulationConfig()
%%--------------------------------------------------------------------------
% SIMULATIONCONFIG Centralized simulation time, solver, and grid parameters
%
% Description:
%   Defines simulation time controls, time-stepping parameters, solver
%   convergence options, and default reference values.
%
% Outputs:
%   cfg - Structure containing simulation configuration parameters
%%--------------------------------------------------------------------------

    %% ---------------------------------------------------------------------
    % Simulation Time Controls
    %% ---------------------------------------------------------------------
    cfg.injectionYears     = 10;           % Active CO2 injection duration (years)
    cfg.shutinYears        = 20;           % Post-injection monitoring/shut-in duration (years)
    cfg.totalTimeYears     = cfg.injectionYears + cfg.shutinYears; % Total time (years)
    cfg.numSteps           = 120;          % Total number of timesteps
    cfg.totalTime          = cfg.totalTimeYears * year; % Duration in seconds

    %% ---------------------------------------------------------------------
    % Synthetic Injection Profile Controls
    %% ---------------------------------------------------------------------
    % Options: 'constant', 'rampup', 'stepwise', 'seasonal'
    cfg.injectionProfile   = 'rampup';     % Injection profile type
    cfg.rampupYears        = 3;            % Duration of ramp-up phase (years)

    %% ---------------------------------------------------------------------
    % Well Defaults & Target Parameters
    %% ---------------------------------------------------------------------
    cfg.defaultProducerBHP = 300 * barsa; % Default producer bottom-hole pressure (Pa)
    cfg.wellRadius         = 0.15;        % Wellbore radius (m)

    %% ---------------------------------------------------------------------
    % Solver & Convergence Controls
    %% ---------------------------------------------------------------------
    cfg.useCNVConvergence  = true;        % Use CNV convergence criteria
    cfg.extraStateOutput    = true;        % Store extra state outputs

    %% ---------------------------------------------------------------------
    % Save & Output Options
    %% ---------------------------------------------------------------------
    cfg.outputFile         = 'simulationResults.mat';

end
