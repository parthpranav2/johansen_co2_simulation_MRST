function [T, report] = validateWellTable(T, G)
%%--------------------------------------------------------------------------
% VALIDATEWELLTABLE Validate and sanitize well specification table
%
% Description:
%   Performs comprehensive pre-simulation checks on imported well table data:
%     1. Validates presence and data types of required columns.
%     2. Checks logical consistency of perforation layers (PERF_FROM <= PERF_TO).
%     3. Validates scheduling time windows (Start_Year < End_Year).
%     4. Checks rate targets (non-negative rates for injectors).
%     5. (Optional) Validates grid bounds and active cell status if G is provided.
%
% Inputs:
%   T      - Well specification table (from readWellCSV)
%   G      - (Optional) MRST grid structure for spatial validation
%
% Outputs:
%   T      - Sanitized well specification table
%   report - Structure detailing valid count, invalid count, and warnings
%%--------------------------------------------------------------------------

    fprintf('\n=====================================\n');
    fprintf('Validating Well Configuration Table\n');
    fprintf('=====================================\n');

    report.initialCount = height(T);
    report.warnings     = {};
    report.rejected     = {};

    %% ---------------------------------------------------------------------
    % 1. Required Columns Check
    %% ---------------------------------------------------------------------
    requiredColumns = { ...
        'Well_Bore_Name', 'NS_DEC_DEG', 'EW_DEC_DEG', ...
        'PERF_FROM', 'PERF_TO', 'Nature', ...
        'Target_tonnes_per_year', 'Start_Year', 'End_Year'};

    for c = 1:numel(requiredColumns)
        colName = requiredColumns{c};
        if ~ismember(colName, T.Properties.VariableNames)
            error("Validation Error: Missing mandatory column '%s' in well table.", colName);
        end
    end

    %% ---------------------------------------------------------------------
    % 2. Type Sanitization
    %% ---------------------------------------------------------------------
    if iscell(T.Nature) || isstring(T.Nature)
        T.Nature = str2double(string(T.Nature));
    end

    %% ---------------------------------------------------------------------
    % 3. Logical Consistency Checks (Row by Row)
    %% ---------------------------------------------------------------------
    validMask = true(height(T), 1);

    for i = 1:height(T)
        wellName = string(T.Well_Bore_Name{i});

        % Check Perforation Interval Order
        if T.PERF_FROM(i) > T.PERF_TO(i)
            msg = sprintf("Well '%s': PERF_FROM (%d) > PERF_TO (%d). Swapping values.", ...
                wellName, T.PERF_FROM(i), T.PERF_TO(i));
            report.warnings{end+1} = msg;
            fprintf("WARNING: %s\n", msg);
            tmp = T.PERF_FROM(i);
            T.PERF_FROM(i) = T.PERF_TO(i);
            T.PERF_TO(i)   = tmp;
        end

        % Check Perforation Minimum Layer
        if T.PERF_FROM(i) < 1
            msg = sprintf("Well '%s': PERF_FROM (%d) < 1. Adjusting to Layer 1.", ...
                wellName, T.PERF_FROM(i));
            report.warnings{end+1} = msg;
            fprintf("WARNING: %s\n", msg);
            T.PERF_FROM(i) = 1;
        end

        % Check Schedule Start / End Years
        if T.Start_Year(i) >= T.End_Year(i)
            msg = sprintf("Well '%s': Start_Year (%.1f) >= End_Year (%.1f). Rejecting well.", ...
                wellName, T.Start_Year(i), T.End_Year(i));
            report.rejected{end+1} = msg;
            fprintf("REJECTED: %s\n", msg);
            validMask(i) = false;
            continue;
        end

        % Check Target Injection Rates
        if T.Nature(i) == 1 && T.Target_tonnes_per_year(i) < 0
            msg = sprintf("Well '%s': Negative injection target (%.2f Mt/yr). Rejecting well.", ...
                wellName, T.Target_tonnes_per_year(i) / 1e6);
            report.rejected{end+1} = msg;
            fprintf("REJECTED: %s\n", msg);
            validMask(i) = false;
            continue;
        end
    end

    % Filter rejected rows
    T = T(validMask, :);

    %% ---------------------------------------------------------------------
    % 4. Grid Spatial Bounds Validation (If Grid G Provided)
    %% ---------------------------------------------------------------------
    if nargin >= 2 && ~isempty(G)
        nz = G.cartDims(3);
        gridValidMask = true(height(T), 1);

        for i = 1:height(T)
            wellName = string(T.Well_Bore_Name{i});

            % Check vertical perforation against grid depth
            if T.PERF_TO(i) > nz
                msg = sprintf("Well '%s': PERF_TO (%d) exceeds max grid layers (%d). Truncating to layer %d.", ...
                    wellName, T.PERF_TO(i), nz, nz);
                report.warnings{end+1} = msg;
                fprintf("WARNING: %s\n", msg);
                T.PERF_TO(i) = nz;
            end

            % Check Grid_X and Grid_Y bounds if present
            if ismember('Grid_X', T.Properties.VariableNames) && ismember('Grid_Y', T.Properties.VariableNames)
                nx = G.cartDims(1);
                ny = G.cartDims(2);
                gx = T.Grid_X(i);
                gy = T.Grid_Y(i);

                if gx < 1 || gx > nx || gy < 1 || gy > ny
                    msg = sprintf("Well '%s': Grid location (%d, %d) outside grid dimensions (%d, %d).", ...
                        wellName, gx, gy, nx, ny);
                    report.rejected{end+1} = msg;
                    fprintf("REJECTED: %s\n", msg);
                    gridValidMask(i) = false;
                end
            end
        end

        T = T(gridValidMask, :);
    end

    %% ---------------------------------------------------------------------
    % Summary Diagnostics Report
    %% ---------------------------------------------------------------------
    report.finalCount = height(T);

    fprintf('-------------------------------------\n');
    fprintf('Validation Summary:\n');
    fprintf('  Initial Wells : %d\n', report.initialCount);
    fprintf('  Validated     : %d\n', report.finalCount);
    fprintf('  Warnings      : %d\n', numel(report.warnings));
    fprintf('  Rejected      : %d\n', numel(report.rejected));
    fprintf('=====================================\n');

end
