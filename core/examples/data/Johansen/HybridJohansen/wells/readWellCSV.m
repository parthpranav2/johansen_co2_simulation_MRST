function T = readWellCSV(filename)
%%--------------------------------------------------------------------------
% READWELLCSV Read and validate well specifications from CSV table
%
% Inputs:
%   filename - Path to CSV file containing well definitions (optional)
%
% Outputs:
%   T        - Validated MATLAB table containing well specifications
%%--------------------------------------------------------------------------

    %% ---------------------------------------------------------------------
    % Default File Handling
    %% ---------------------------------------------------------------------
    if nargin < 1 || isempty(filename)
        filename = "input/well_loc.csv";
    end

    fprintf('\n=====================================\n');
    fprintf('Reading Well Configuration CSV\n');
    fprintf('=====================================\n');
    fprintf('File: %s\n', filename);

    if ~exist(filename, 'file')
        error("Well configuration file not found: %s", filename);
    end

    %% ---------------------------------------------------------------------
    % Read & Validate Required Columns
    %% ---------------------------------------------------------------------
    T = readtable(filename);

    requiredColumns = { ...
        'Well_Bore_Name', ...
        'NS_DEC_DEG', ...
        'EW_DEC_DEG', ...
        'PERF_FROM', ...
        'PERF_TO', ...
        'Nature', ...
        'Target_tonnes_per_year', ...
        'Start_Year', ...
        'End_Year'};

    for i = 1:numel(requiredColumns)
        if ~ismember(requiredColumns{i}, T.Properties.VariableNames)
            error("Missing required column in CSV: %s", requiredColumns{i});
        end
    end

    %% ---------------------------------------------------------------------
    % Parse Nature & Count Well Types
    %% ---------------------------------------------------------------------
    if iscell(T.Nature) || isstring(T.Nature)
        natureVec = str2double(string(T.Nature));
    else
        natureVec = T.Nature;
    end

    nInjectors = sum(natureVec == 1);
    nProducers = sum(natureVec == 0);

    fprintf('Loaded Wells : %d total\n', height(T));
    fprintf('  Injectors  : %d\n', nInjectors);
    fprintf('  Producers  : %d\n', nProducers);
    fprintf('=====================================\n');

end