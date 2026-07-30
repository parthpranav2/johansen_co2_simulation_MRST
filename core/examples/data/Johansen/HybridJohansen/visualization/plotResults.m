function plotResults(model, states, ws, schedule)
%%--------------------------------------------------------------------------
% PLOTRESULTS Launch Master Visualization Suite for Johansen Hybrid-VE
%
% Description:
%   Executes simulation post-processing engine and opens four diagnostic
%   figure dashboards:
%     1. Pressure Buildup & Trajectory Suite (plotPressure)
%     2. Saturation Field Map (plotSaturation)
%     3. CO2 Plume & Mass Inventory Suite (plotPlume)
%     4. Well Rates & BHP Performance Suite (plotWellPerformance)
%
% Inputs:
%   model    - Reservoir model object
%   states   - Cell array of simulation states
%   ws       - (Optional) Cell array of well solution structures
%   schedule - (Optional) Simulation schedule
%%--------------------------------------------------------------------------

    fprintf('\n=====================================\n');
    fprintf('Launching Johansen Master Visualization Suite\n');
    fprintf('=====================================\n');

    if nargin < 3
        ws = {};
    end
    if nargin < 4
        schedule.step.val = ones(numel(states), 1) * year;
    end

    %% ---------------------------------------------------------------------
    % Run Post-Processing Engine
    %% ---------------------------------------------------------------------
    resStats = postProcess(model, states, ws, schedule);

    %% ---------------------------------------------------------------------
    % Launch Modular Diagnostic Dashboards
    %% ---------------------------------------------------------------------
    plotPressure(model, states, resStats);
    plotSaturation(model, states);
    plotPlume(model, states, resStats);
    
    if ~isempty(ws)
        plotWellPerformance(resStats);
    end

    %% ---------------------------------------------------------------------
    % Also Launch MRST Interactive Plot Toolbar
    %% ---------------------------------------------------------------------
    figure('Name',  'MRST Interactive Result Viewer', ...
           'Color', 'w', ...
           'Position', [100, 100, 1000, 650]);
    plotToolbar(model.G, states);

end
