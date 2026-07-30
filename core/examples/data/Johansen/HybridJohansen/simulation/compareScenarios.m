function compTable = compareScenarios(batchResults)
%%--------------------------------------------------------------------------
% COMPARESCENARIOS Compile summary comparison table across batch scenarios
%
% Inputs:
%   batchResults - Structure containing batch run outputs
%
% Outputs:
%   compTable - MATLAB table summarizing performance across scenarios
%%--------------------------------------------------------------------------

    scFields = fieldnames(batchResults);
    nSc = numel(scFields);

    Scenario_Name     = cell(nSc, 1);
    Injection_Years   = zeros(nSc, 1);
    Rate_Multiplier   = zeros(nSc, 1);
    Total_Stored_Mt   = zeros(nSc, 1);
    Max_DeltaP_bar    = zeros(nSc, 1);
    Max_Plume_Height_m= zeros(nSc, 1);
    Sim_Time_Sec      = zeros(nSc, 1);

    fprintf('\n=========================================================================\n');
    fprintf(' BATCH SCENARIO PERFORMANCE COMPARISON SUMMARY\n');
    fprintf('=========================================================================\n');

    for i = 1:nSc
        scData   = batchResults.(scFields{i});
        resStats = scData.resStats;
        scInfo   = scData.scInfo;

        Scenario_Name{i}      = scData.scName;
        Injection_Years(i)    = scInfo.injectionYears;
        Rate_Multiplier(i)    = scInfo.rateMultiplier;
        Total_Stored_Mt(i)    = resStats.co2MassMt(end);
        Max_DeltaP_bar(i)     = max(resStats.deltaPMax);
        Max_Plume_Height_m(i) = max(resStats.plumeMaxH);
        Sim_Time_Sec(i)       = resStats.runTimeSeconds;
    end

    compTable = table(Scenario_Name, Injection_Years, Rate_Multiplier, ...
                      Total_Stored_Mt, Max_DeltaP_bar, Max_Plume_Height_m, Sim_Time_Sec);

    disp(compTable);
    fprintf('=========================================================================\n');

end
