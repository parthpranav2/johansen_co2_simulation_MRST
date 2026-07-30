function plotSensitivity(sensResults, optResults)
%%--------------------------------------------------------------------------
% PLOTSENSITIVITY Generate sensitivity tornado and optimization surface plots
%
% Inputs:
%   sensResults - Output structure from runSensitivityAnalysis()
%   optResults  - (Optional) Output structure from optimizeInjectionStrategy()
%%--------------------------------------------------------------------------

    figure('Name', 'Johansen Sensitivity & Optimization Diagnostics', ...
           'Color', 'w', ...
           'Position', [100, 100, 1200, 500]);

    %% ---------------------------------------------------------------------
    % Subplot 1: Sensitivity Response Surface (Max Delta P)
    %% ---------------------------------------------------------------------
    subplot(1, 2, 1);
    scatter(sensResults.runMatrix(:, 1), sensResults.maxDeltaP, 80, sensResults.runMatrix(:, 2), 'filled');
    colorbar;
    grid on;
    xlabel('Permeability Scale Factor', 'FontSize', 11);
    ylabel('Max Pressure Buildup \DeltaP [bar]', 'FontSize', 11);
    title('Permeability vs Pressure Buildup Sensitivity', 'FontSize', 12, 'FontWeight', 'bold');

    %% ---------------------------------------------------------------------
    % Subplot 2: Optimization Constraint Curve
    %% ---------------------------------------------------------------------
    subplot(1, 2, 2);
    if nargin >= 2 && ~isempty(optResults)
        plot(optResults.rateMultipliers, optResults.massVec, '-o', 'LineWidth', 2.2, 'MarkerFaceColor', 'b');
        hold on;
        yline(optResults.optimalMassMt, '--g', 'LineWidth', 2.0, 'DisplayName', 'Optimum Storage');
        grid on;
        xlabel('Injection Rate Multiplier', 'FontSize', 11);
        ylabel('Total Stored CO_2 Mass [Mt]', 'FontSize', 11);
        title('Storage Capacity Optimization Curve', 'FontSize', 12, 'FontWeight', 'bold');
    end

end
