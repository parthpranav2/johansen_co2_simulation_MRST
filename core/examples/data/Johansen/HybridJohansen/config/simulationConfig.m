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
    cfg.totalTimeYears = 10;            % Simulation duration (years)
    cfg.numSteps       = 100;           % Number of timesteps
    cfg.totalTime      = cfg.totalTimeYears * year; % Duration in seconds

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
