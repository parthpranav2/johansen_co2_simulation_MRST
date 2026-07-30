function [simCfg, scInfo] = scenarioManager(scenarioName, baseSimCfg)
%%--------------------------------------------------------------------------
% SCENARIOMANAGER Manage and apply scenario configuration overrides
%
% Inputs:
%   scenarioName - String specifying scenario ('base_case', 'high_rate', etc.)
%   baseSimCfg   - Base simulationConfig structure
%
% Outputs:
%   simCfg - Modified simulationConfig structure with scenario parameters applied
%   scInfo - Structure containing scenario metadata and description
%%--------------------------------------------------------------------------

    if nargin < 2 || isempty(baseSimCfg)
        baseSimCfg = simulationConfig();
    end
    if nargin < 1 || isempty(scenarioName)
        scenarioName = 'base_case';
    end

    allScenarios = defineScenarios();
    matchIdx = find(strcmpi({allScenarios.name}, scenarioName));

    if isempty(matchIdx)
        warning("Scenario '%s' not found. Defaulting to 'base_case'.", scenarioName);
        matchIdx = 1;
    end

    scInfo = allScenarios(matchIdx);
    simCfg = baseSimCfg;

    %% ---------------------------------------------------------------------
    % Apply Scenario Overrides to Simulation Config
    %% ---------------------------------------------------------------------
    simCfg.scenarioName     = scInfo.name;
    simCfg.injectionYears   = scInfo.injectionYears;
    simCfg.shutinYears      = scInfo.shutinYears;
    simCfg.totalTimeYears   = scInfo.injectionYears + scInfo.shutinYears;
    simCfg.totalTime        = simCfg.totalTimeYears * year;
    simCfg.injectionProfile = scInfo.injectionProfile;
    simCfg.rampupYears      = scInfo.rampupYears;
    simCfg.rateMultiplier   = scInfo.rateMultiplier;

    fprintf('\n=====================================\n');
    fprintf('Scenario Selected: %s\n', scInfo.name);
    fprintf('Description: %s\n', scInfo.description);
    fprintf('Rate Multiplier: %.2fx\n', scInfo.rateMultiplier);
    fprintf('=====================================\n');

end
