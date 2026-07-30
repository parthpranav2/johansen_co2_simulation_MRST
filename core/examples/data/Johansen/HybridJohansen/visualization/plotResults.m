function plotResults(model, states)
%%--------------------------------------------------------------------------
% PLOTRESULTS Launch MRST Interactive Plot Toolbar for Simulation Results
%
% Inputs:
%   model  - Reservoir model object (containing grid definition)
%   states - Cell array or array of simulation states over time
%%--------------------------------------------------------------------------

    fprintf('\n=====================================\n');
    fprintf('Opening MRST Interactive Result Viewer\n');
    fprintf('=====================================\n');

    %% ---------------------------------------------------------------------
    % Launch Interactive Plotting Toolbar
    %% ---------------------------------------------------------------------
    figure('Name',  'Hybrid Johansen Simulation Results', ...
           'Color', 'w', ...
           'Position', [100, 100, 1200, 750]);

    plotToolbar(model.G, states);

end
