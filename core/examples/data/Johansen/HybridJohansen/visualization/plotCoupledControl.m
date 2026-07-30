function plotCoupledControl(controlLog, resStats)
%%--------------------------------------------------------------------------
% PLOTCOUPLEDCONTROL Plot closed-loop pressure feedback control diagnostics
%
% Inputs:
%   controlLog - Structure logged by controlPressureLoop()
%   resStats   - Post-processed metrics structure
%%--------------------------------------------------------------------------

    figure('Name', 'Johansen Closed-Loop Pressure Control Diagnostics', ...
           'Color', 'w', ...
           'Position', [150, 150, 1200, 500]);

    %% ---------------------------------------------------------------------
    % Subplot 1: Peak Field Pressure vs Safety Limit Threshold
    %% ---------------------------------------------------------------------
    subplot(1, 2, 1);
    plot(controlLog.tYears, controlLog.deltaPMax, '-b', 'LineWidth', 2.5, 'DisplayName', 'Controlled \DeltaP');
    hold on;
    yline(15.0, '--r', 'LineWidth', 2.0, 'DisplayName', 'Safety Limit (15 bar)');
    grid on;
    xlabel('Time [Years]', 'FontSize', 11);
    ylabel('Max Pressure Buildup \DeltaP [bar]', 'FontSize', 11);
    title('Closed-Loop Pressure Buildup Control', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'best');

    %% ---------------------------------------------------------------------
    % Subplot 2: Dynamic Injector Rate Throttling Factor Trajectory
    %% ---------------------------------------------------------------------
    subplot(1, 2, 2);
    plot(controlLog.tYears, controlLog.throttleFac * 100, '-g', 'LineWidth', 2.2);
    grid on;
    xlabel('Time [Years]', 'FontSize', 11);
    ylabel('Injector Capacity Allowed [%]', 'FontSize', 11);
    title('Adaptive Rate Throttling Feedback Trajectory', 'FontSize', 12, 'FontWeight', 'bold');
    ylim([0 110]);

end
