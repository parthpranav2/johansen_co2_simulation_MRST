function plotPressureManagement(resStatsBase, resStatsRelief)
%%--------------------------------------------------------------------------
% PLOTPRESSUREMANAGEMENT Compare unmanaged vs active pressure relief
%
% Inputs:
%   resStatsBase   - resStats from Unmanaged Base Case scenario
%   resStatsRelief - resStats from Active Brine Relief scenario
%%--------------------------------------------------------------------------

    figure('Name', 'Active Pressure Management Diagnostics', ...
           'Color', 'w', ...
           'Position', [150, 150, 1200, 500]);

    %% ---------------------------------------------------------------------
    % Subplot 1: Peak Pressure Buildup Trajectory (Delta P max)
    %% ---------------------------------------------------------------------
    subplot(1, 2, 1);
    plot(resStatsBase.tYears, resStatsBase.deltaPMax, '-r', 'LineWidth', 2.5, 'DisplayName', 'Unmanaged Base Case');
    hold on;
    plot(resStatsRelief.tYears, resStatsRelief.deltaPMax, '-b', 'LineWidth', 2.5, 'DisplayName', 'Active Pressure Relief');
    grid on;
    xlabel('Time [Years]', 'FontSize', 11);
    ylabel('Max Pressure Buildup \DeltaP [bar]', 'FontSize', 11);
    title('Peak Field Pressure Buildup Comparison', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'best');

    %% ---------------------------------------------------------------------
    % Subplot 2: Average Reservoir Pressure Relaxation Trajectory
    %% ---------------------------------------------------------------------
    subplot(1, 2, 2);
    plot(resStatsBase.tYears, resStatsBase.pAvg, '--r', 'LineWidth', 2.2, 'DisplayName', 'Unmanaged Avg P');
    hold on;
    plot(resStatsRelief.tYears, resStatsRelief.pAvg, '-g', 'LineWidth', 2.2, 'DisplayName', 'Pressure Relief Avg P');
    grid on;
    xlabel('Time [Years]', 'FontSize', 11);
    ylabel('Average Reservoir Pressure [bar]', 'FontSize', 11);
    title('Reservoir Pressure Relaxation Trajectory', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'best');

end
