function plotScenarioComparison(batchResults)
%%--------------------------------------------------------------------------
% PLOTSCENARIOCOMPARISON Generate comparative dashboard across batch scenarios
%
% Inputs:
%   batchResults - Structure containing batch run outputs
%%--------------------------------------------------------------------------

    scFields = fieldnames(batchResults);
    nSc      = numel(scFields);
    colors   = lines(nSc);

    figure('Name', 'Johansen Batch Scenario Comparison Suite', ...
           'Color', 'w', ...
           'Position', [100, 100, 1300, 750]);

    %% ---------------------------------------------------------------------
    % Subplot 1: Peak Pressure Buildup Comparison (Delta P max)
    %% ---------------------------------------------------------------------
    subplot(2, 2, 1);
    hold on;
    for i = 1:nSc
        scData   = batchResults.(scFields{i});
        resStats = scData.resStats;
        plot(resStats.tYears, resStats.deltaPMax, 'LineWidth', 2.2, ...
            'Color', colors(i, :), 'DisplayName', scData.scName);
    end
    grid on;
    xlabel('Time [Years]', 'FontSize', 11);
    ylabel('Max \DeltaP [bar]', 'FontSize', 11);
    title('Peak Reservoir Pressure Buildup Comparison', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'best');

    %% ---------------------------------------------------------------------
    % Subplot 2: Cumulative Stored CO2 Mass Comparison (Mt)
    %% ---------------------------------------------------------------------
    subplot(2, 2, 2);
    hold on;
    for i = 1:nSc
        scData   = batchResults.(scFields{i});
        resStats = scData.resStats;
        plot(resStats.tYears, resStats.co2MassMt, 'LineWidth', 2.2, ...
            'Color', colors(i, :), 'DisplayName', scData.scName);
    end
    grid on;
    xlabel('Time [Years]', 'FontSize', 11);
    ylabel('Stored CO_2 Mass [Mt]', 'FontSize', 11);
    title('Cumulative Stored CO_2 Mass Trajectory', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'best');

    %% ---------------------------------------------------------------------
    % Subplot 3: Maximum Free Plume Height Comparison (m)
    %% ---------------------------------------------------------------------
    subplot(2, 2, 3);
    hold on;
    for i = 1:nSc
        scData   = batchResults.(scFields{i});
        resStats = scData.resStats;
        plot(resStats.tYears, resStats.plumeMaxH, 'LineWidth', 2.2, ...
            'Color', colors(i, :), 'DisplayName', scData.scName);
    end
    grid on;
    xlabel('Time [Years]', 'FontSize', 11);
    ylabel('Max Plume Height h [m]', 'FontSize', 11);
    title('Free CO_2 Plume Height Evolution', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'best');

    %% ---------------------------------------------------------------------
    % Subplot 4: Total Stored CO2 Mass Bar Chart Comparison
    %% ---------------------------------------------------------------------
    subplot(2, 2, 4);
    finalMasses = zeros(nSc, 1);
    scNames     = cell(nSc, 1);
    for i = 1:nSc
        scData         = batchResults.(scFields{i});
        finalMasses(i) = scData.resStats.co2MassMt(end);
        scNames{i}     = scData.scName;
    end
    b = bar(finalMasses, 'FaceColor', 'flat');
    b.CData = colors;
    grid on;
    set(gca, 'XTickLabel', scNames, 'XTick', 1:nSc);
    ylabel('Total Stored Mass [Mt]', 'FontSize', 11);
    title('Total Stored CO_2 Capacity Comparison', 'FontSize', 12, 'FontWeight', 'bold');

end
