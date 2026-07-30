%% =========================================================================
%  HybridJohansen Main Batch Driver
%  Automated Multi-Scenario Execution & Comparative Analysis Engine
%
%  Description:
%    Runs a batch suite of development scenarios, compiles comparative
%    performance metrics, and generates a unified multi-scenario dashboard.
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
% Define Scenarios & Execute Batch Suite
%% -------------------------------------------------------------------------

scenarioList = {'base_case', 'high_rate', 'constant_rate', 'extended_inj'};

batchResults = runBatchSimulations(scenarioList);

%% -------------------------------------------------------------------------
% Comparative Analysis & Diagnostics Dashboard
%% -------------------------------------------------------------------------

compTable = compareScenarios(batchResults);

plotScenarioComparison(batchResults);

disp(' ');
disp('=========================================================================');
disp(' HybridJohansen Batch Simulation & Comparison completed successfully.');
disp('=========================================================================');
