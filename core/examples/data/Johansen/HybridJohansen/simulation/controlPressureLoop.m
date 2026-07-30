function [ws, states, controlLog] = controlPressureLoop(model, state0, schedule, pLimitBar)
%%--------------------------------------------------------------------------
% CONTROLPRESSURELOOP Adaptive closed-loop pressure feedback controller
%
% Description:
%   Executes MRST AD simulation with step-by-step pressure monitoring.
%   If maximum field pressure buildup exceeds pLimitBar (default 15 bar),
%   the controller dynamically scales down injector target rates to prevent
%   exceeding caprock geomechanical limits.
%
% Inputs:
%   model     - Upscaled Hybrid-VE reservoir model
%   state0    - Initial reservoir state
%   schedule  - Coupled simulation schedule
%   pLimitBar - Maximum allowable pressure buildup threshold [bar]
%
% Outputs:
%   ws         - Cell array of well solution structures
%   states     - Cell array of simulation states
%   controlLog - Structure logging dynamic rate throttling events
%%--------------------------------------------------------------------------

    if nargin < 4 || isempty(pLimitBar)
        pLimitBar = 15.0; % Default 15 bar pressure buildup safety threshold
    end

    fprintf('\n=========================================================================\n');
    fprintf(' STARTING ADAPTIVE CLOSED-LOOP PRESSURE CONTROL SIMULATION\n');
    fprintf(' Pressure Buildup Safety Limit: %.1f bar\n', pLimitBar);
    fprintf('=========================================================================\n');

    nSteps = numel(schedule.step.val);
    states = cell(nSteps, 1);
    ws     = cell(nSteps, 1);

    currentState = state0;
    
    if isfield(state0, 'pressure')
        pInitBarsa = mean(state0.pressure) / barsa;
    elseif isfield(state0, 'p')
        pInitBarsa = mean(state0.p) / barsa;
    else
        pInitBarsa = 300.0;
    end

    controlLog.tYears      = zeros(nSteps, 1);
    controlLog.deltaPMax   = zeros(nSteps, 1);
    controlLog.throttleFac = ones(nSteps, 1);

    cumTimeSec = 0;

    %% ---------------------------------------------------------------------
    % Step-by-Step Adaptive Control Loop
    %% ---------------------------------------------------------------------
    for s = 1:nSteps
        dt = schedule.step.val(s);
        cumTimeSec = cumTimeSec + dt;
        tYears = cumTimeSec / year;

        ctlIdx = schedule.step.control(s);
        currentControl = schedule.control(ctlIdx);

        % Evaluate pressure at start of step
        if s > 1
            if isfield(currentState, 'pressure')
                pCur = currentState.pressure;
            elseif isfield(currentState, 'p')
                pCur = currentState.p;
            else
                pCur = pInitBarsa * barsa;
            end
            currentDeltaP = max(pCur / barsa - pInitBarsa);
        else
            currentDeltaP = 0;
        end

        % Check if pressure buildup exceeds safety limit
        throttleFactor = 1.0;
        if currentDeltaP > pLimitBar
            throttleFactor = pLimitBar / currentDeltaP;
            fprintf('  [Step %d | Year %.2f] WARNING: DeltaP (%.2f bar) > Limit (%.1f bar). Scaling rates by %.2f%%\n', ...
                s, tYears, currentDeltaP, pLimitBar, throttleFactor * 100);

            % Throttle active injectors
            for w = 1:numel(currentControl.W)
                if currentControl.W(w).sign > 0 && currentControl.W(w).status
                    currentControl.W(w).val = currentControl.W(w).val * throttleFactor;
                end
            end
        end

        % Construct single-step mini schedule
        stepSchedule.control      = currentControl;
        stepSchedule.step.val     = dt;
        stepSchedule.step.control = 1;

        % Run single timestep solver
        [wSolStep, stateStep] = simulateScheduleAD(currentState, model, stepSchedule);

        currentState = stateStep{end};
        states{s}    = stateStep{end};
        ws{s}        = wSolStep{end};

        if isfield(currentState, 'pressure')
            pEnd = currentState.pressure;
        elseif isfield(currentState, 'p')
            pEnd = currentState.p;
        else
            pEnd = pInitBarsa * barsa;
        end

        controlLog.tYears(s)      = tYears;
        controlLog.deltaPMax(s)   = max(pEnd / barsa - pInitBarsa);
        controlLog.throttleFac(s) = throttleFactor;
    end

    fprintf('=========================================================================\n');
    fprintf(' CLOSED-LOOP PRESSURE CONTROL SIMULATION COMPLETED\n');
    fprintf('=========================================================================\n');

end
