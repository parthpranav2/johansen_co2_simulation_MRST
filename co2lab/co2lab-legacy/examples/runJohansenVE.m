%% Vertical-Averaged Simulation of the Johansen Formation with CSV Injection Data
% The Johansen formation is a candidate site for large-scale CO2 storage
% offshore the south-west coast of Norway. This script simulates CO2 injection
% using actual injection rates from CSV data, followed by long-term migration
% tracking over 600 years total.
%
% DYNAMIC MULTI-WELL VERSION: Reads well locations from CSV and converts
% lat/lon to grid coordinates using simple plane-Earth approximation.

mrstModule add co2lab-common co2lab-legacy mimetic

%% Display header
clc;
disp('================================================================');
disp('   Vertical averaging applied to the Johansen formation');
disp('   With CSV-based injection schedule and 600-year simulation');
disp('   DYNAMIC MULTI-WELL MODE');
disp('================================================================');
disp('');

%% Read and parse CSV injection data
csvFile = '/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/data/storage_injection.csv';
if ~isfile(csvFile)
    error('CSV file not found: %s', csvFile);
end

% Read the CSV file with automatic type detection
injectionData = readtable(csvFile, 'TreatAsEmpty', '""');

% Extract relevant columns
years = table2array(injectionData(:, 'csdYear'));
months = table2array(injectionData(:, 'csdMonth'));
volumesTonnes = table2array(injectionData(:, 'csdVolumeInjectedMonth'));

% Convert to numeric if needed (handle comma-formatted numbers)
if iscell(volumesTonnes)
    volumesTonnes = cellfun(@(x) str2double(strrep(x, ',', '')), volumesTonnes);
elseif isstring(volumesTonnes)
    volumesTonnes = str2double(strrep(volumesTonnes, ',', ''));
end
volumesTonnes = double(volumesTonnes);

% Replace any NaN or negative values with 0
volumesTonnes(isnan(volumesTonnes) | volumesTonnes < 0) = 0;

% Sort by year and month (ascending order to get chronological sequence)
[~, sortIdx] = sortrows([years, months], [1, 2]);
years = years(sortIdx);
months = months(sortIdx);
volumesTonnes = volumesTonnes(sortIdx);

% Display injection schedule summary
fprintf('Injection schedule from CSV:\n');
fprintf('Period: %d/%d to %d/%d (%d months)\n', ...
    years(1), months(1), years(end), months(end), length(years));
fprintf('Total CO2: %.2e tonnes\n', sum(volumesTonnes));
fprintf('\n');

%% Convert injection volumes from tonnes to m³/day
% Supercritical CO2 density at 300 bar (from fluid parameters below)
rhoc_sc = 686.54; % kg/m³

% Convert tonnes to m³, then to m³/day (assuming 30.44 days/month on average)
daysPerMonth = 30.44;
volumesM3Day = (volumesTonnes * 1000 / rhoc_sc) / daysPerMonth;

% Total injection period in months
totalInjectionMonths = length(volumesTonnes);

%% Input data and construct grid models
% We use a sector model given in the Eclipse input format (GRDECL). The
% model has five vertical layers in the Johansen formation and five shale
% layers above and one below in the Dunhil and Amundsen formations. The
% shale layers are removed and we construct the 2D VE grid of the top
% surface, assuming that the major fault is sealing, and identify all outer
% boundaries that are open to flow.
[G, rock, ~, Gt, rock2D, bcIxVE] = makeJohansenVEgrid();

%% Get grid bounds in real coordinates
gridXmin = min(G.nodes.coords(:, 1));
gridXmax = max(G.nodes.coords(:, 1));
gridYmin = min(G.nodes.coords(:, 2));
gridYmax = max(G.nodes.coords(:, 2));

% Get actual grid cartesian dimensions
[nxCells, nyCells, ~] = deal(G.cartDims(1), G.cartDims(2), G.cartDims(3));

fprintf('========== MODEL GRID BOUNDS ==========\n');
fprintf('X range: [%.1f, %.1f] (meters, UTM)\n', gridXmin, gridXmax);
fprintf('Y range: [%.1f, %.1f] (meters, UTM)\n', gridYmin, gridYmax);
fprintf('Grid size: %d × %d cells (approximately 900 m/cell)\n', nxCells, nyCells);
fprintf('\n');

%% REFERENCE WELL SETUP
% Well 31/05/07 is used as the reference point for lat/lon to grid conversion
% Grid position: (51, 51, 6, 6)
% Lat/Lon: (60.576425, 3.443367)
refWellName = '31/05/07';
refGridX = 51;
refGridY = 51;
refLat = 60.576425;
refLon = 3.443367;

fprintf('========== REFERENCE WELL FOR LAT/LON CONVERSION ==========\n');
fprintf('Well: %s | Grid: (%d, %d) | Lat/Lon: (%.6f°, %.6f°)\n', ...
    refWellName, refGridX, refGridY, refLat, refLon);
fprintf('Using simple plane-Earth approximation at 60.5°N:\n');
fprintf('  1° latitude ≈ 111 km\n');
fprintf('  1° longitude ≈ 55.5 km (at 60°N, cos(60°) factor applied)\n');
fprintf('  Grid cell size ≈ 900 m\n');
fprintf('\n');

%% Read well locations from CSV
wellLocFile = '/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/data/well_loc.csv';
if ~isfile(wellLocFile)
    error('Well location CSV file not found: %s', wellLocFile);
end

wellData = readtable(wellLocFile, 'TreatAsEmpty', '""');
wellNames = table2array(wellData(:, 'Well_Bore_Name'));
wellLats = table2array(wellData(:, 'NS_DEC_DEG'));
wellLons = table2array(wellData(:, 'EW_DEC_DEG'));
perfFrom = table2array(wellData(:, 'PERF_FROM'));
perfTo = table2array(wellData(:, 'PERF_TO'));

wellLats = double(wellLats);
wellLons = double(wellLons);
perfFrom = double(perfFrom);
perfTo = double(perfTo);

%% Convert lat/lon to grid coordinates using simple plane-Earth approximation
% Reference: grid (51, 51) = (60.576425°N, 3.443367°E)
% Scale factors for Johansen field at ~60.5°N:
%   1° latitude  ≈ 111 km / 0.9 km/cell ≈ 123.3 cells/degree
%   1° longitude ≈ 55.5 km / 0.9 km/cell ≈ 61.7 cells/degree

scale_lat_per_degree = 111.0 / 0.9;  % cells per degree latitude
scale_lon_per_degree = 55.5 / 0.9;   % cells per degree longitude (at ~60°N)

gridX = 51 + (wellLons - refLon) * scale_lon_per_degree;
gridY = 51 + (wellLats - refLat) * scale_lat_per_degree;

%% Validate wells against grid bounds and identify valid/invalid wells
validWellIdx = [];
validWellNames = {};
validGridX = [];
validGridY = [];
validPerfFrom = [];
validPerfTo = [];
invalidWellCount = 0;

fprintf('========== WELL LOCATION ANALYSIS ==========\n');
fprintf('%-30s %12s %12s %12s %12s %15s\n', 'Well Name', 'Lat', 'Lon', 'Grid X', 'Grid Y', 'Status');
fprintf('%s\n', repmat('-', 1, 100));

% Use actual grid dimensions (no artificial margin)
% Allow cells anywhere from 1 to nxCells/nyCells
for i = 1:length(wellLats)
    wellName = char(wellNames(i));
    gx = gridX(i);
    gy = gridY(i);
    
    isInBounds = (gx >= 1 && gx <= nxCells && ...
                  gy >= 1 && gy <= nyCells);
    
    if isInBounds
        validWellIdx = [validWellIdx; i];
        validWellNames{end+1} = wellName;
        validGridX = [validGridX; gx];
        validGridY = [validGridY; gy];
        validPerfFrom = [validPerfFrom; perfFrom(i)];
        validPerfTo = [validPerfTo; perfTo(i)];
        status = '✓ VALID';
    else
        status = '✗ OUT OF BOUNDS';
        invalidWellCount = invalidWellCount + 1;
    end
    
    fprintf('%-30s %12.6f %12.6f %12.2f %12.2f  %s\n', ...
        wellName, wellLats(i), wellLons(i), gx, gy, status);
end

fprintf('%s\n', repmat('-', 1, 100));
fprintf('SUMMARY: %d valid wells out of %d total wells\n', length(validWellIdx), length(wellLats));
if invalidWellCount > 0
    fprintf('WARNING: %d wells are out of bounds but simulation will proceed with valid wells\n', invalidWellCount);
end
fprintf('\n');

if isempty(validWellIdx)
    error('ERROR: No valid wells found within model bounds! Cannot proceed.');
end

%% Set time and fluid parameters
gravity on

% Total simulation time: 600 years
T_total = 600*year();

% Injection period: from first month to last month in CSV
startYear = min(years);
startMonth = min(months(years == startYear));
endYear = max(years);
endMonth = max(months(years == endYear));

startTime = 0*year();
stopInject = totalInjectionMonths * 30.44 / 365.25 * year();

fprintf('========== SIMULATION PARAMETERS ==========\n');
fprintf('Start injection time: %.2f years\n', convertTo(startTime, year));
fprintf('Stop injection time:  %.2f years\n', convertTo(stopInject, year));
fprintf('Total simulation time: %.0f years\n', convertTo(T_total, year));
fprintf('\n');

% Fluid data at p = 300 bar
muw = 0.30860;  rhow = 975.86; sw    = 0.1;
muc = 0.056641; rhoc = rhoc_sc; srco2 = 0.2;
kwm = [0.2142 0.85];

fluidVE = initVEFluidHForm(Gt, 'mu' , [muc muw] .* centi*poise, ...
                             'rho', [rhoc rhow] .* kilogram/meter^3, ...
                             'sr', srco2, 'sw', sw, 'kwm', kwm);

%% Create wells for ALL valid well locations (proper pre-allocation)
if isempty(validWellIdx)
    error('ERROR: No valid wells found within model bounds! Cannot proceed.');
end

fprintf('========== CREATING WELL STRUCTURES ==========\n');
fprintf('Creating %d wells from valid locations in CSV...\n\n', length(validWellIdx));

% Pre-allocate well array (this avoids concatenation issues)
W = [];  % Start empty

for i = 1:length(validWellIdx)
    wellIdx = validWellIdx(i);
    wellName = validWellNames{i};
    
    % Cast to integers
    gx = int32(round(validGridX(i)));
    gy = int32(round(validGridY(i)));
    perfFromLyr = int32(max(1, round(validPerfFrom(i))));
    perfToLyr = int32(max(perfFromLyr, round(validPerfTo(i))));
    
    % Initial rate (will be overridden by injection schedule)
    initialRate = 0.1 * meter^3/day;
    
    try
        % Create well
        W_temp = verticalWell([], G, rock, gx, gy, perfFromLyr:perfToLyr, ...
            'Type', 'rate', 'Val', initialRate, 'Radius', 0.1, 'comp_i', [1, 0], ...
            'name', sprintf('Well_%s', wellName), 'InnerProduct', 'ip_simple');
        
        % Use proper MATLAB structure array syntax
        if isempty(W)
            W = W_temp;  % First well
        else
            % Append to array (should work better than comma notation)
            W = appendStruct(W, W_temp);
        end
        
        fprintf('  Well %d: %-30s at grid (%2d, %2d), layers %d-%d\n', ...
            i, wellName, gx, gy, perfFromLyr, perfToLyr);
        
    catch ME
        fprintf('  Well %d: %-30s FAILED: %s\n', i, wellName, ME.message);
        continue;
    end
end

fprintf('\nTotal wells created: %d\n\n', length(W));

if isempty(W)
    error('ERROR: No wells were successfully created.');
end

% Helper function to append structures
function S_out = appendStruct(S_in, S_new)
    % Properly append new structure to array
    n = length(S_in);
    % Copy all fields from S_new to S_in(n+1)
    fnames = fieldnames(S_new);
    for i = 1:numel(fnames)
        fname = fnames{i};
        S_in(n+1).(fname) = S_new(1).(fname);
    end
    S_out = S_in;
end

% Convert to VE well
WVE = convertwellsVE(W, G, Gt, rock2D);

% Boundary conditions
bcVE = addBC([], bcIxVE, 'pressure', Gt.faces.z(bcIxVE)*rhow*norm(gravity));
bcVE = rmfield(bcVE, 'sat');
bcVE.h = zeros(size(bcVE.face));

%% Prepare simulations
% Compute inner products and instantiate solution structure
SVE = computeMimeticIPVE(Gt, rock2D, 'Innerproduct', 'ip_simple');
preComp = initTransportVE(Gt, rock2D);
sol = initResSolVE(Gt, 0, 0);
sol.wellSol = initWellSol(W, 300*barsa());
sol.s = height2finescaleSat(sol.h, sol.h_max, Gt, fluidVE.res_water, fluidVE.res_gas);

% Select transport solver
try
   mtransportVE;
   cpp_accel = true;
catch me
   disp('mex-file for C++ acceleration not found');
   disp(['See ', fullfile(mrstPath('co2lab-legacy'), 'solvers', 'VEmex', 'README'), ...
      ' for building instructions']);
   disp('Using MATLAB VE-transport');
   cpp_accel = false;
end

%% Prepare plotting
% Use center of first valid well for plotting reference
opts = {'slice', [round(validGridX(1)) round(validGridY(1)) 6 6], ...
    'Saxis', [0 1-fluidVE.res_water], 'maxH', 100, ...
    'Wadd', 500, 'view', [-85 70], 'wireH', true, 'wireS', true};
plotPanelVE(G, Gt, W, sol, 0.0, zeros(1,4), opts{:});

%% Create injection schedule from CSV
injectionSchedule = struct();
injectionSchedule.years = years;
injectionSchedule.months = months;
injectionSchedule.rates = volumesM3Day';
injectionSchedule.times = zeros(size(years));

for i = 1:length(years)
    yearDiff = years(i) - startYear;
    monthDiff = months(i) - startMonth;
    totalMonths = yearDiff * 12 + monthDiff;
    injectionSchedule.times(i) = totalMonths * 30.44 / 365.25; % convert to years
end

%% Main simulation loop
t = 0;
totVol = 0.0;
numWells = length(W);
wellInjVol = zeros(numWells, 1);  % Track volume per well
injectionIdx = 1;
isInjecting = true;

fprintf('\n========== STARTING SIMULATION ==========\n');
fprintf('Number of active wells: %d\n', numWells);
fprintf('Injection period: %.2f years | Post-injection migration until year %.0f\n', ...
    convertTo(stopInject, year), convertTo(T_total, year));
fprintf('Time: %6.1f years', convertTo(t, year));

tic;
while t < T_total
    % Determine current injection rate based on schedule
    if t < stopInject
        % Find which injection month we are in
        for idx = 1:length(injectionSchedule.times)-1
            if t >= injectionSchedule.times(idx) && t < injectionSchedule.times(idx+1)
                injectionIdx = idx;
                break;
            elseif t >= injectionSchedule.times(end)
                injectionIdx = length(injectionSchedule.times);
                break;
            end
        end
        
        % Get total rate and distribute among all wells EQUALLY
        currentRateTotal = injectionSchedule.rates(injectionIdx) * meter^3/day;
        currentRatePerWell = currentRateTotal / numWells;
        
        % Ensure rates are finite and non-negative
        if ~isfinite(currentRatePerWell) || currentRatePerWell < 0
            currentRatePerWell = 0;
        end
        if ~isfinite(currentRateTotal) || currentRateTotal < 0
            currentRateTotal = 0;
        end
        
        % Update all well rates
        if currentRatePerWell > 0
            for iw = 1:numWells
                WVE(iw).val = currentRatePerWell;
            end
            isInjecting = true;
        else
            isInjecting = false;
        end
    else
        % After injection stops
        isInjecting = false;
        currentRatePerWell = 0;
        currentRateTotal = 0;
    end
    
    % Adaptive time stepping
    if t < stopInject
        dT = 2*year();
        dTplot = 1*dT;
    else
        dT = 5*year();
        dTplot = dT;
    end
    
    % Ensure we don't overshoot total time
    if t + dT > T_total
        dT = T_total - t;
        dTplot = dT;
    end
    
    % Solve pressure step
    if isInjecting && currentRatePerWell > 0
        sol = solveIncompFlowVE(sol, Gt, SVE, rock, fluidVE, ...
            'bc', bcVE, 'wells', WVE);
    else
        sol = solveIncompFlowVE(sol, Gt, SVE, rock, fluidVE, ...
            'bc', bcVE, 'wells', []);
    end
    
    % Solve transport step
    if isInjecting && currentRatePerWell > 0
        if cpp_accel
            [sol.h, sol.h_max] = mtransportVE(sol, Gt, dT, rock, ...
                                        fluidVE, 'bc', bcVE, 'wells', WVE, ...
                                       'gravity', norm(gravity), 'verbose', false);
        else
            sol = explicitTransportVE(sol, Gt, dT, rock, fluidVE, ...
                                      'bc', bcVE, 'wells', WVE, ...
                                      'preComp', preComp);
        end
    else
        if cpp_accel
            [sol.h, sol.h_max] = mtransportVE(sol, Gt, dT, rock, ...
                                        fluidVE, 'bc', bcVE, 'wells', [], ...
                                       'gravity', norm(gravity), 'verbose', false);
        else
            sol = explicitTransportVE(sol, Gt, dT, rock, fluidVE, ...
                                      'bc', bcVE, 'wells', [], ...
                                      'preComp', preComp);
        end
    end
    
    % Reconstruct saturation
    sol.s = height2finescaleSat(sol.h, sol.h_max, Gt, fluidVE.res_water, fluidVE.res_gas);
    assert(max(sol.s(:,1)) < 1+eps && min(sol.s(:,1)) > -eps);
    t = t + dT;
    
    % Track volumes
    if isInjecting && currentRatePerWell > 0
        totVol = totVol + currentRateTotal*dT;
        for iw = 1:numWells
            wellInjVol(iw) = wellInjVol(iw) + currentRatePerWell*dT;
        end
    end
    
    vol = volumesVE(Gt, sol, rock2D, fluidVE);
    
    % Plot at specified intervals
    fprintf('\b\b\b\b\b\b\b\b\b\b%6.1f years', convertTo(t, year));
    if mod(t, dTplot) < dT + 1e-6 || t >= T_total - 1e-6
        if isInjecting && currentRatePerWell > 0
            W_plot = WVE;
        else
            W_plot = [];
        end
        plotPanelVE(G, Gt, W_plot, sol, t, [vol totVol], opts{:});
        drawnow
    end
end

fprintf('\n\n');

% Cleanup
if cpp_accel, mtransportVE(); end
etime = toc;

%% Summary statistics
fprintf('========== SIMULATION COMPLETE ==========\n');
fprintf('Elapsed computation time: %.1f seconds (%.1f minutes)\n', etime, etime/60);
fprintf('Total CO2 injected: %.3e m³ (%.3e tonnes)\n', totVol, totVol * rhoc_sc / 1000);
fprintf('Final plume height (max): %.2f m\n', max(sol.h));
fprintf('Final trapped CO2: %.3e m³\n', vol(2));
fprintf('Final free CO2: %.3e m³\n', vol(1));
fprintf('=========================================\n');
fprintf('\n');

fprintf('========== PER-WELL INJECTION SUMMARY ==========\n');
fprintf('%-5s %-35s %15s %15s\n', 'Well', 'Name', 'Volume (m³)', 'Volume (tonnes)');
fprintf('%s\n', repmat('-', 1, 75));
for i = 1:numWells
    wellName = validWellNames{i};
    volM3 = wellInjVol(i);
    volTonnes = volM3 * rhoc_sc / 1000;
    fprintf('%5d %-35s %15.3e %15.3e\n', i, wellName, volM3, volTonnes);
end
fprintf('%s\n', repmat('-', 1, 75));
fprintf('TOTAL%40s %15.3e %15.3e\n', '', totVol, totVol * rhoc_sc / 1000);
fprintf('=========================================\n\n');

%%
% <html>
% <p><font size="-1">
% Copyright 2009-2026 SINTEF Digital, Mathematics & Cybernetics.
% </font></p>
% <p><font size="-1">
% This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).
% </font></p>
% <p><font size="-1">
% MRST is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% </font></p>
% <p><font size="-1">
% MRST is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% </font></p>
% <p><font size="-1">
% You should have received a copy of the GNU General Public License
% along with MRST.  If not, see
% <a href="http://www.gnu.org/licenses/">http://www.gnu.org/licenses</a>.
% </font></p>
% </html>