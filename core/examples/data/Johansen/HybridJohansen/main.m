%% =========================================================================
%  HybridJohansen Main Driver
%  Official Johansen Formation - Hybrid Vertical Equilibrium (Hybrid-VE) CO2 Storage Simulator
%  
%  Description:
%    Main entry point for the Hybrid-VE CO2 storage simulation framework.
%    Initializes path structure, loads MRST modules, builds the reservoir
%    grid and fluid model, sets up initial state, reads well configurations,
%    constructs simulation schedule, converts to Hybrid-VE, executes
%    simulation, and triggers post-processing visualization.
%% =========================================================================

clear;
clc;
close all;

%% -------------------------------------------------------------------------
% Path Initialization
%% -------------------------------------------------------------------------

% Add project subdirectories to MATLAB search path dynamically
projectDir = fileparts(mfilename('fullpath'));
addpath(genpath(projectDir));

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
fluid     = buildFluid();
model     = buildModel(G, rock, fluid);
state0    = buildState(model);

%% -------------------------------------------------------------------------
% Well & Schedule Construction
%% -------------------------------------------------------------------------

wellTable = readWellCSV("input/well_loc.csv");
wellTable = latLonToGrid(wellTable, G);
W         = buildWells(model, rock, fluid, wellTable);
schedule  = buildSchedule(W);

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