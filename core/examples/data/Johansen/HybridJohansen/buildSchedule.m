function schedule = buildSchedule(W)

    %% Simulation time

    totalTime = 10*year;

    nSteps = 100;

    dt = rampupTimesteps(totalTime, totalTime/nSteps);

    %% Create schedule

    schedule = simpleSchedule(dt, 'W', W);

    fprintf("\n=====================================\n");
    fprintf("Simulation Schedule Created\n");
    fprintf("=====================================\n");
    fprintf("Total time : %.1f years\n", totalTime/year);
    fprintf("Timesteps  : %d\n", numel(dt));
    fprintf("=====================================\n");

end