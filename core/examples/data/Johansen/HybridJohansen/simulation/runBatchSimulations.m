function batchResults = runBatchSimulations(scenarioList)
%%--------------------------------------------------------------------------
% RUNBATCHSIMULATIONS Execute sequential batch simulation over scenario list
%
% Inputs:
%   scenarioList - Cell array of scenario names to run (optional)
%
% Outputs:
%   batchResults - Structure containing results and resStats for each scenario
%%--------------------------------------------------------------------------

    if nargin < 1 || isempty(scenarioList)
        scenarioList = {'base_case', 'high_rate', 'constant_rate', 'extended_inj'};
    end

    fprintf('\n=========================================================================\n');
    fprintf(' STARTING AUTOMATED BATCH SIMULATION PIPELINE (%d Scenarios)\n', numel(scenarioList));
    fprintf('=========================================================================\n');

    %% ---------------------------------------------------------------------
    % Ensure Path and MRST Modules Loaded
    %% ---------------------------------------------------------------------
    mrstModule add ad-core ad-blackoil ad-props co2lab-common hybrid-ve;
    gravity reset on;

    simCfgBase = simulationConfig();
    flCfg      = fluidConfig();
    [G, rock]  = loadJohansen();

    batchResults = struct();

    %% ---------------------------------------------------------------------
    % Sequential Scenario Execution Loop
    %% ---------------------------------------------------------------------
    for i = 1:numel(scenarioList)
        scName = scenarioList{i};

        fprintf('\n-------------------------------------------------------------------------\n');
        fprintf(' Executing Scenario %d/%d: [%s]\n', i, numel(scenarioList), scName);
        fprintf('-------------------------------------------------------------------------\n');

        % Setup scenario config
        [simCfg, scInfo] = scenarioManager(scName, simCfgBase);

        % Build model components
        fluid  = buildFluid(flCfg);
        model  = buildModel(G, rock, fluid);
        state0 = buildState(model, flCfg);

        % Build wells and schedule
        wellTable = readWellCSV("input/well_loc.csv");
        wellTable = validateWellTable(wellTable);
        wellTable = latLonToGrid(wellTable, G);
        wellTable = validateWellTable(wellTable, G);
        W         = buildWells(model, rock, fluid, wellTable, simCfg, flCfg);

        if isfield(simCfg, 'rateMultiplier') && simCfg.rateMultiplier ~= 1.0
            for w = 1:numel(W)
                if W(w).sign > 0
                    W(w).val = W(w).val * simCfg.rateMultiplier;
                end
            end
        end

        schedule = buildSchedule(W, simCfg, flCfg);

        % Convert to Hybrid-VE
        [model_hyb, state_hyb, schedule_hyb] = convertHybrid(model, state0, schedule);

        % Run Simulation
        tStart = tic;
        [ws, states, report] = simulateHybrid(model_hyb, state_hyb, schedule_hyb);
        runTime = toc(tStart);

        % Post-process metrics
        resStats = postProcess(model_hyb, states, ws, schedule_hyb);
        resStats.runTimeSeconds = runTime;
        resStats.scInfo         = scInfo;

        % Store in batch output structure
        cleanName = strrep(scName, '-', '_');
        batchResults.(cleanName).scName     = scName;
        batchResults.(cleanName).scInfo     = scInfo;
        batchResults.(cleanName).model_hyb  = model_hyb;
        batchResults.(cleanName).states     = states;
        batchResults.(cleanName).ws         = ws;
        batchResults.(cleanName).schedule   = schedule_hyb;
        batchResults.(cleanName).resStats   = resStats;
    end

    %% ---------------------------------------------------------------------
    % Save Batch Output File
    %% ---------------------------------------------------------------------
    if ~exist('output', 'dir')
        mkdir('output');
    end
    save('output/batchResults.mat', 'batchResults', 'scenarioList');

    fprintf('\n=========================================================================\n');
    fprintf(' BATCH SIMULATION PIPELINE COMPLETED SUCCESSFULLY\n');
    fprintf(' Results saved to output/batchResults.mat\n');
    fprintf('=========================================================================\n');

end
