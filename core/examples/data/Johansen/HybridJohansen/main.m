%% =========================================================================
%  HybridJohansen Main Driver
%  Official Johansen Formation - Hybrid Vertical Equilibrium (Hybrid-VE) CO2 Storage Simulator
%  
%  Description:
%    Main entry point for the Hybrid-VE CO2 storage simulation framework.
%    Initializes path structure, loads configuration & scenario parameters,
%    sets up MRST modules, builds reservoir model, reads & validates well table,
%    constructs schedule, converts to Hybrid-VE, executes simulation,
%    evaluates economics, generates automated reports, and visualizes results.
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

selectedScenario = 'base_case';

simCfgBase = simulationConfig();
[simCfg, scInfo] = scenarioManager(selectedScenario, simCfgBase);
flCfg      = fluidConfig();
econCfg    = economicConfig();

%% -------------------------------------------------------------------------
% MRST Module Initialization
%% -------------------------------------------------------------------------

mrstModule add ...
    ad-core ...
    ad-blackoil ...
    ad-props ...
    co2lab-common ...
    hybrid-ve ...
    co2lab-spillpoint;

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
% Simulation Execution & Post-Processing
%% -------------------------------------------------------------------------

[ws, states, report] = ...
    simulateHybrid(model_hyb, state_hyb, schedule_hyb);

resStats = postProcess(model_hyb, states, ws, schedule_hyb);

%% -------------------------------------------------------------------------
% Economic Assessment & Report Generation
%% -------------------------------------------------------------------------

econResults = evaluateEconomics(resStats, W, econCfg);
reportPath  = generateReport(model_hyb, simCfg, flCfg, resStats, econResults);

%% -------------------------------------------------------------------------
% Visualization Suite
%% -------------------------------------------------------------------------

plotResults(model_hyb, states, ws, schedule_hyb);
plotEconomics(econResults);

disp(' ');
disp('=========================================================================');
fprintf(' HybridJohansen scenario [%s] completed successfully.\n', simCfg.scenarioName);
fprintf(' Summary report saved to: %s\n', reportPath);
disp('=========================================================================');