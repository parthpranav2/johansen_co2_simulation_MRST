function sensResults = runSensitivityAnalysis(paramList)
%%--------------------------------------------------------------------------
% RUNSENSITIVITYANALYSIS Perform parameter sweep sensitivity study
%
% Inputs:
%   paramList - Cell array of parameter names to vary (optional)
%
% Outputs:
%   sensResults - Structure containing sensitivity matrices and responses
%%--------------------------------------------------------------------------

    fprintf('\n=========================================================================\n');
    fprintf(' STARTING RESERVOIR SENSITIVITY ANALYSIS SUITE\n');
    fprintf('=========================================================================\n');

    mrstModule add ad-core ad-blackoil ad-props co2lab-common hybrid-ve;
    gravity reset on;

    simCfgBase = simulationConfig();
    flCfgBase  = fluidConfig();
    [G, rockBase] = loadJohansen();

    % Parameter Variation Ranges
    kScales = [0.5, 1.0, 2.0];
    pScales = [0.8, 1.0, 1.2];

    nRuns = numel(kScales) * numel(pScales);
    sensResults.runMatrix = zeros(nRuns, 2); % [K_scale, Poro_scale]
    sensResults.maxDeltaP = zeros(nRuns, 1);
    sensResults.storedMass= zeros(nRuns, 1);

    runIdx = 1;
    for ik = 1:numel(kScales)
        for ip = 1:numel(pScales)
            ks = kScales(ik);
            ps = pScales(ip);

            fprintf('Sensitivity Run %d/%d: PermScale = %.2f, PoroScale = %.2f\n', ...
                runIdx, nRuns, ks, ps);

            % Vary rock properties
            rock = rockBase;
            rock.perm = rockBase.perm * ks;
            rock.poro = min(max(rockBase.poro * ps, 0.01), 0.40);

            fluid  = buildFluid(flCfgBase);
            model  = buildModel(G, rock, fluid);
            state0 = buildState(model, flCfgBase);

            wellTable = readWellCSV("input/well_loc.csv");
            wellTable = validateWellTable(wellTable);
            wellTable = latLonToGrid(wellTable, G);
            wellTable = validateWellTable(wellTable, G);
            W         = buildWells(model, rock, fluid, wellTable, simCfgBase, flCfgBase);
            schedule  = buildSchedule(W, simCfgBase, flCfgBase);

            [model_hyb, state_hyb, schedule_hyb] = convertHybrid(model, state0, schedule);
            [ws, states, report] = simulateHybrid(model_hyb, state_hyb, schedule_hyb);

            resStats = postProcess(model_hyb, states, ws, schedule_hyb);

            sensResults.runMatrix(runIdx, :) = [ks, ps];
            sensResults.maxDeltaP(runIdx)    = max(resStats.deltaPMax);
            sensResults.storedMass(runIdx)   = resStats.co2MassMt(end);

            runIdx = runIdx + 1;
        end
    end

    if ~exist('output', 'dir')
        mkdir('output');
    end
    save('output/sensitivityResults.mat', 'sensResults');

    fprintf('=========================================================================\n');
    fprintf(' SENSITIVITY ANALYSIS COMPLETED SUCCESSFULLY\n');
    fprintf('=========================================================================\n');

end
