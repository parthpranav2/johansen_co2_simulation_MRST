function optResults = optimizeInjectionStrategy(pMaxLimitBar)
%%--------------------------------------------------------------------------
% OPTIMIZEINJECTIONSTRATEGY Find optimal field injection rate multiplier
%
% Description:
%   Maximizes total stored CO2 mass subject to caprock pressure limit:
%     Maximize   M_stored(R)
%     Subject to DeltaP_max(R) <= pMaxLimitBar
%
% Inputs:
%   pMaxLimitBar - Maximum allowable pressure buildup threshold [bar]
%
% Outputs:
%   optResults - Structure containing optimal rate multiplier and stats
%%--------------------------------------------------------------------------

    if nargin < 1 || isempty(pMaxLimitBar)
        pMaxLimitBar = 15.0;
    end

    fprintf('\n=========================================================================\n');
    fprintf(' STARTING FIELD INJECTION RATE OPTIMIZATION ENGINE\n');
    fprintf(' Pressure Constraint: DeltaP_max <= %.1f bar\n', pMaxLimitBar);
    fprintf('=========================================================================\n');

    rateMultipliers = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    nCandidates = numel(rateMultipliers);

    deltaPVec   = zeros(nCandidates, 1);
    massVec     = zeros(nCandidates, 1);

    simCfgBase = simulationConfig();
    flCfg      = fluidConfig();
    [G, rock]  = loadJohansen();

    for i = 1:nCandidates
        rm = rateMultipliers(i);
        fprintf('Evaluating Injection Rate Multiplier: %.2fx...\n', rm);

        fluid  = buildFluid(flCfg);
        model  = buildModel(G, rock, fluid);
        state0 = buildState(model, flCfg);

        wellTable = readWellCSV("input/well_loc.csv");
        wellTable = validateWellTable(wellTable);
        wellTable = latLonToGrid(wellTable, G);
        wellTable = validateWellTable(wellTable, G);
        W         = buildWells(model, rock, fluid, wellTable, simCfgBase, flCfg);

        for w = 1:numel(W)
            if W(w).sign > 0
                W(w).val = W(w).val * rm;
            end
        end

        schedule = buildSchedule(W, simCfgBase, flCfg);
        [model_hyb, state_hyb, schedule_hyb] = convertHybrid(model, state0, schedule);
        [ws, states, report] = simulateHybrid(model_hyb, state_hyb, schedule_hyb);

        resStats = postProcess(model_hyb, states, ws, schedule_hyb);

        deltaPVec(i) = max(resStats.deltaPMax);
        massVec(i)   = resStats.co2MassMt(end);
    end

    % Find feasible candidates satisfying pressure constraint
    feasibleMask = deltaPVec <= pMaxLimitBar;

    if any(feasibleMask)
        feasibleIdx = find(feasibleMask);
        [maxMass, bestLocalIdx] = max(massVec(feasibleIdx));
        optIdx = feasibleIdx(bestLocalIdx);
    else
        % If none strictly feasible, pick minimum pressure violation
        [~, optIdx] = min(deltaPVec);
        warning('No candidate strictly satisfied DeltaP <= %.1f bar limit. Picking lowest pressure buildup candidate.', pMaxLimitBar);
    end

    optResults.rateMultipliers = rateMultipliers;
    optResults.deltaPVec       = deltaPVec;
    optResults.massVec         = massVec;
    optResults.optimalRM       = rateMultipliers(optIdx);
    optResults.optimalMassMt   = massVec(optIdx);
    optResults.optimalDeltaP   = deltaPVec(optIdx);
    optResults.pMaxLimitBar    = pMaxLimitBar;

    fprintf('\n=========================================================================\n');
    fprintf(' OPTIMIZATION COMPLETED:\n');
    fprintf('  Optimal Rate Multiplier : %.2fx\n', optResults.optimalRM);
    fprintf('  Optimal Stored Mass     : %.2f Mt\n', optResults.optimalMassMt);
    fprintf('  Peak Pressure Buildup   : %.2f bar (Limit: %.1f bar)\n', optResults.optimalDeltaP, pMaxLimitBar);
    fprintf('=========================================================================\n');

end
