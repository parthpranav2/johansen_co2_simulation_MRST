function [ws, states, report] = simulateHybrid(model, state0, schedule)

fprintf('\n=====================================\n');
fprintf('Starting Hybrid-VE simulation...\n');
fprintf('=====================================\n');

[ws, states, report] = ...
    simulateScheduleAD(state0, model, schedule);

fprintf('=====================================\n');
fprintf('Simulation completed successfully.\n');
fprintf('=====================================\n');

save('simulationResults.mat', ...
    'ws', ...
    'states', ...
    'report', ...
    'model');

end