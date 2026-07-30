%% =========================================================================
%  HybridJohansen Main Driver
%  Official Johansen Formation - Hybrid Vertical Equilibrium (Hybrid-VE) CO2 Storage Simulator
%  
%  Description:
%    Main entry point for the Hybrid-VE CO2 storage simulation framework.
%    Initializes path structure, loads configuration & scenario parameters,
%    sets up MRST modules, builds reservoir model, reads & validates well table,
%    constructs schedule, converts to Hybrid-VE, executes simulation,
%    and visualizes diagnostic results.
%% =========================================================================

clear;
clc;
close all;

%% -------------------------------------------------------------------------
% Path Initialization
%% -------------------------------------------------------------------------

projectDir = fileparts(mfilename('fullpath'));
addpath(genpath(projectDir));

%% -------------------------------------------------------------------------
% Scenario & Configuration Setup
%% -------------------------------------------------------------------------

% Options: 'base_case', 'high_rate', 'constant_rate', 'extended_inj'
selectedScenario = 'base_case';

simCfgBase = simulationConfig();
[simCfg, scInfo] = scenarioManager(selectedScenario, simCfgBase);
flCfg = fluidConfig();

%% -------------------------------------------------------------------------
% MRST Module Initialization
%% -------------------------------------------------------------------------

mrstModule add ...
    ad-core ...
    ad-blackoil ...
    ad-props ...
    co2lab-common ...
    hybrid-ve;

gravity reset on;

%% -------------------------------------------------------------------------
% Model Construction
%% -------------------------------------------------------------------------

[G, rock] = loadJohansen();
fluid     = buildFluid(flCfg);
model     = buildModel(G, rock, fluid);
state0    = buildState(model, flCfg);

%% -------------------------------------------------------------------------
% Well Construction & Dynamic Scheduling
%% -------------------------------------------------------------------------

wellTable = readWellCSV("input/well_loc.csv");
wellTable = validateWellTable(wellTable);          % Pre-mapping sanity checks
wellTable = latLonToGrid(wellTable, G);
wellTable = validateWellTable(wellTable, G);       % Post-mapping spatial validation
W         = buildWells(model, rock, fluid, wellTable, simCfg, flCfg);

% Apply scenario rate multiplier if set
if isfield(simCfg, 'rateMultiplier') && simCfg.rateMultiplier ~= 1.0
    for w = 1:numel(W)
        if W(w).sign > 0
            W(w).val = W(w).val * simCfg.rateMultiplier;
        end
    end
end

schedule  = buildSchedule(W, simCfg, flCfg);

%% -------------------------------------------------------------------------
% Hybrid-VE Model Conversion
%% -------------------------------------------------------------------------

[model_hyb, state_hyb, schedule_hyb] = ...
    convertHybrid(model, state0, schedule);

%% -------------------------------------------------------------------------
% Simulation Execution & Post-Processing Visualization
%% -------------------------------------------------------------------------

[ws, states, report] = ...
    simulateHybrid(model_hyb, state_hyb, schedule_hyb);

plotResults(model_hyb, states, ws, schedule_hyb);

disp(' ');
disp('=========================================================================');
fprintf(' HybridJohansen scenario [%s] completed successfully.\n', simCfg.scenarioName);
disp('=========================================================================');