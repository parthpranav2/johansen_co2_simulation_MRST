%% =========================================================================
%  HybridJohansen Main Optimization Driver
%  Sensitivity Analysis & Injection Strategy Optimization Engine
%
%  Description:
%    Executes parameter sensitivity sweeps and injection rate optimization.
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
% Run Sensitivity Analysis
%% -------------------------------------------------------------------------

sensResults = runSensitivityAnalysis();

%% -------------------------------------------------------------------------
% Run Rate Optimization Engine
%% -------------------------------------------------------------------------

pSafetyLimitBar = 15.0;
optResults = optimizeInjectionStrategy(pSafetyLimitBar);

%% -------------------------------------------------------------------------
% Visualization
%% -------------------------------------------------------------------------

plotSensitivity(sensResults, optResults);

disp(' ');
disp('=========================================================================');
disp(' HybridJohansen Optimization Pipeline completed successfully.');
disp('=========================================================================');
