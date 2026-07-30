%% =========================================================================
%  HybridJohansen Main Driver
%  Official Johansen Formation - Hybrid Vertical Equilibrium (Hybrid-VE) CO2 Storage Simulator
%  
%  Description:
%    Main entry point for the Hybrid-VE CO2 storage simulation framework.
%    Initializes path structure, loads configuration parameters, sets up MRST
%    modules, builds reservoir model, reads wells, constructs schedule,
%    converts to Hybrid-VE, executes simulation, and visualizes results.
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
% Configuration Setup
%% -------------------------------------------------------------------------

simCfg   = simulationConfig();
flCfg    = fluidConfig();

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
% Well & Schedule Construction
%% -------------------------------------------------------------------------

wellTable = readWellCSV("input/well_loc.csv");
wellTable = latLonToGrid(wellTable, G);
W         = buildWells(model, rock, fluid, wellTable, simCfg, flCfg);
schedule  = buildSchedule(W, simCfg);

%% -------------------------------------------------------------------------
% Hybrid-VE Model Conversion
%% -------------------------------------------------------------------------

[model_hyb, state_hyb, schedule_hyb] = ...
    convertHybrid(model, state0, schedule);

%% -------------------------------------------------------------------------
% Simulation Execution & Visualization
%% -------------------------------------------------------------------------

[ws, states, report] = ...
    simulateHybrid(model_hyb, state_hyb, schedule_hyb);

plotResults(model_hyb, states);

disp(' ');
disp('=========================================================================');
disp(' HybridJohansen simulation completed successfully.');
disp('=========================================================================');