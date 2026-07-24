%% Johansen Multi-Well Simulation - Utility Functions
% Helper functions for coordinate transformation calibration, validation,
% and visualization of well locations

% =========================================================================
% FUNCTION 1: Transform Coordinates with Adaptive Calibration
% =========================================================================
function [gridX, gridY] = transformWellCoordinates(lat, lon, ...
    refLat, refLon, refGridX, refGridY, varargin)
%TRANSFORMWELLCOORDINATES Convert lat/lon to grid coordinates
%
% SYNTAX:
%   [X, Y] = transformWellCoordinates(lat, lon, refLat, refLon, refX, refY)
%   [X, Y] = transformWellCoordinates(..., 'CellSize', [dx, dy])
%   [X, Y] = transformWellCoordinates(..., 'Method', 'mercator')
%
% INPUT:
%   lat, lon         - Well coordinates (scalar or array)
%   refLat, refLon   - Reference point lat/lon
%   refGridX, refGridY - Reference point grid coordinates
%   'CellSize'       - [dlat, dlon] in degrees (optional)
%   'Method'         - 'linear' (default) or 'mercator'
%
% OUTPUT:
%   gridX, gridY     - Transformed grid coordinates

    % Parse input arguments
    p = inputParser;
    addParameter(p, 'CellSize', [0.05, 0.05/cos(deg2rad(refLat))], @isvector);
    addParameter(p, 'Method', 'linear', @ischar);
    parse(p, varargin{:});
    
    cellSize = p.Results.CellSize;
    method = p.Results.Method;
    
    % Delta coordinates
    dlat = lat - refLat;
    dlon = lon - refLon;
    
    switch method
        case 'linear'
            % Simple linear transformation
            gridY = refGridY + dlat / cellSize(1);
            gridX = refGridX + dlon / cellSize(2);
            
        case 'mercator'
            % Mercator projection (more accurate for large areas)
            earthRadius = 6371000; % meters
            cosLat = cos(deg2rad((lat + refLat)/2));
            
            dlatM = dlat * pi/180 * earthRadius;
            dlonM = dlon * pi/180 * earthRadius * cosLat;
            
            % Assume ~5 km per grid cell
            cellSizeM = 5000;
            gridY = refGridY + dlatM / cellSizeM;
            gridX = refGridX + dlonM / cellSizeM;
            
        otherwise
            error('Unknown transformation method: %s', method);
    end
end

% =========================================================================
% FUNCTION 2: Calibrate Transformation from Multiple Reference Wells
% =========================================================================
function [cellSize, residual] = calibrateCoordinateTransform(refWells, G, varargin)
%CALIBRATECOORDINATETRANSFORM Fit coordinate transformation from known wells
%
% INPUT:
%   refWells         - struct array with fields:
%                      .name (well name string)
%                      .lat, .lon (coordinates)
%                      .gridX, .gridY (known grid positions)
%   G                - MRST grid structure
%   'Latitude'       - Reference latitude for scaling (optional)
%
% OUTPUT:
%   cellSize         - [dlat, dlon] per grid cell
%   residual         - RMS error of fit

    p = inputParser;
    addParameter(p, 'Latitude', 60.5, @isscalar);
    parse(p, varargin{:});
    
    refLat = p.Results.Latitude;
    
    % Extract data
    nRef = length(refWells);
    
    % Use first well as reference anchor
    refLat0 = refWells(1).lat;
    refLon0 = refWells(1).lon;
    refX0 = refWells(1).gridX;
    refY0 = refWells(1).gridY;
    
    % Build least-squares system: X = A*dlon + B*lat + C
    % We solve for scaling factors
    
    A_matrix = zeros(nRef-1, 2);
    b_vector = zeros(nRef-1, 1);
    
    for i = 2:nRef
        % Delta coordinates relative to reference
        dlon = refWells(i).lon - refLon0;
        dlat = refWells(i).lat - refLat0;
        
        % Grid difference
        dX = refWells(i).gridX - refX0;
        dY = refWells(i).gridY - refY0;
        
        A_matrix(i-1, :) = [dlon, dlat];
        b_vector(i-1, 1) = dX;
    end
    
    % Solve for dlon scaling and dlat scaling
    x_fit = A_matrix \ b_vector;
    
    % Estimate cell size
    dlon_per_cell_X = 1 / x_fit(1);
    
    % For Y direction, use similar approach
    A_matrix_y = zeros(nRef-1, 2);
    b_vector_y = zeros(nRef-1, 1);
    
    for i = 2:nRef
        dlon = refWells(i).lon - refLon0;
        dlat = refWells(i).lat - refLat0;
        dY = refWells(i).gridY - refY0;
        
        A_matrix_y(i-1, :) = [dlon, dlat];
        b_vector_y(i-1, 1) = dY;
    end
    
    y_fit = A_matrix_y \ b_vector_y;
    dlat_per_cell_Y = 1 / y_fit(2);
    
    cellSize = [dlat_per_cell_Y, dlon_per_cell_X];
    
    % Calculate residual
    X_pred = refX0 + x_fit(1) * (refWells(2:end).lon - refLon0)' + ...
             x_fit(2) * (refWells(2:end).lat - refLat0)';
    X_actual = [refWells(2:nRef).gridX]';
    residual = sqrt(mean((X_pred - X_actual).^2));
    
    fprintf('Calibrated cell size: [%.6f, %.6f] degrees\n', cellSize(1), cellSize(2));
    fprintf('Fit residual: %.2f grid cells\n', residual);
end

% =========================================================================
% FUNCTION 3: Visualize Well Locations on Grid
% =========================================================================
function visualizeWellLocations(wellLats, wellLons, wellNames, ...
    wellGridX, wellGridY, G, Gt, validWellIdx, varargin)
%VISUALIZEWELLLOCATIONS Plot well locations on model grid
%
% INPUT:
%   wellLats, wellLons - Array of well coordinates
%   wellNames          - Cell array of well names
%   wellGridX, wellGridY - Transformed grid coordinates
%   G, Gt              - MRST grids (3D and VE)
%   validWellIdx       - Indices of valid wells
%   'ShowAll'          - Show all wells (true/false, default true)
%   'FigureNum'        - Figure number (default 100)

    p = inputParser;
    addParameter(p, 'ShowAll', true, @islogical);
    addParameter(p, 'FigureNum', 100, @isscalar);
    parse(p, varargin{:});
    
    figure(p.Results.FigureNum);
    clf;
    
    % Plot grid outline
    hold on;
    plotGrid(Gt, 'FaceColor', 'none', 'EdgeColor', [0.8 0.8 0.8]);
    
    % Plot all wells
    if p.Results.ShowAll
        % Out-of-bounds wells in red
        outOfBounds = setdiff(1:length(wellLats), validWellIdx);
        scatter(wellGridX(outOfBounds), wellGridY(outOfBounds), 50, 'r', 'x', ...
            'LineWidth', 2, 'DisplayName', 'Out of bounds');
    end
    
    % Valid wells in blue
    scatter(wellGridX(validWellIdx), wellGridY(validWellIdx), 80, 'b', 'o', ...
        'filled', 'DisplayName', 'Valid wells');
    
    % Label valid wells
    for i = 1:length(validWellIdx)
        idx = validWellIdx(i);
        text(wellGridX(idx) + 1, wellGridY(idx) + 1, sprintf('W%d', i), ...
            'FontSize', 8, 'FontWeight', 'bold');
    end
    
    % Reference well in green
    refIdx = find(strcmpi(cellstr(wellNames), '31/05/07'), 1);
    if ~isempty(refIdx)
        scatter(wellGridX(refIdx), wellGridY(refIdx), 200, 'g', '*', ...
            'LineWidth', 2, 'DisplayName', 'Reference well');
    end
    
    axis equal;
    xlabel('X (grid index)');
    ylabel('Y (grid index)');
    title('Well Locations on Johansen Model Grid');
    legend('Location', 'best');
    grid on;
    hold off;
end

% =========================================================================
% FUNCTION 4: Check Well-Well Distances
% =========================================================================
function distances = computeWellDistances(wellGridX, wellGridY, validWellIdx)
%COMPUTEWELLDISTANCES Calculate distances between all pairs of wells
%
% OUTPUT:
%   distances - struct with fields:
%               .pairwise - Matrix of distances between all valid wells
%               .minDist - Minimum distance
%               .minPair - Indices of closest pair
%               .clustering - Number of well pairs within 3 cells

    nWells = length(validWellIdx);
    pairwise = zeros(nWells, nWells);
    
    for i = 1:nWells
        for j = i+1:nWells
            idx_i = validWellIdx(i);
            idx_j = validWellIdx(j);
            
            dx = wellGridX(idx_i) - wellGridX(idx_j);
            dy = wellGridY(idx_i) - wellGridY(idx_j);
            
            dist = sqrt(dx^2 + dy^2);
            pairwise(i, j) = dist;
            pairwise(j, i) = dist;
        end
    end
    
    distances.pairwise = pairwise;
    
    % Minimum distance (excluding diagonal)
    pairwise(logical(eye(nWells))) = Inf;
    [minDistVal, minIdx] = min(pairwise(:));
    
    [row, col] = ind2sub([nWells, nWells], minIdx);
    distances.minDist = minDistVal;
    distances.minPair = [validWellIdx(row), validWellIdx(col)];
    
    % Count clusters (wells within 3 cells)
    distances.clustering = sum(pairwise(:) < 3 & pairwise(:) > 0) / 2;
    
    fprintf('\n========== WELL SPACING ANALYSIS ==========\n');
    fprintf('Number of valid wells: %d\n', nWells);
    fprintf('Minimum distance between wells: %.2f grid cells\n', distances.minDist);
    fprintf('Well pairs within 3 cells: %d\n', distances.clustering);
    fprintf('\n');
    
    if distances.clustering > 0
        fprintf('WARNING: %d closely-spaced well pairs detected.\n', distances.clustering);
        fprintf('Consider combining into single wells for stability.\n\n');
    end
end

% =========================================================================
% FUNCTION 5: Export Well Positions for External Validation
% =========================================================================
function exportWellPositions(wellLats, wellLons, wellNames, ...
    wellGridX, wellGridY, validWellIdx, outputFile)
%EXPORTWELLPOSITIONS Save well positions to file for validation
%
% OUTPUT:
%   Comma-separated file with columns:
%   wellName, lat, lon, gridX, gridY, isValid

    fid = fopen(outputFile, 'w');
    
    fprintf(fid, 'Well_Name,Latitude,Longitude,Grid_X,Grid_Y,Is_Valid\n');
    
    isValidArray = ismember(1:length(wellLats), validWellIdx);
    
    for i = 1:length(wellLats)
        wellName = char(wellNames(i));
        isValid = isValidArray(i);
        fprintf(fid, '%s,%.6f,%.6f,%.2f,%.2f,%d\n', ...
            wellName, wellLats(i), wellLons(i), wellGridX(i), wellGridY(i), isValid);
    end
    
    fclose(fid);
    fprintf('Well positions exported to: %s\n', outputFile);
end

% =========================================================================
% FUNCTION 6: Validate Transformation with Known Grid
% =========================================================================
function [gridDims, scale] = estimateGridScale(G, Gt)
%ESTIMATEGRIDSCALE Estimate grid dimensions and cell size from MRST grid
%
% OUTPUT:
%   gridDims - [nX, nY, nZ] number of cells in each direction
%   scale - [dx, dy, dz] average cell size in each direction

    % Get grid dimensions
    nCells = G.cells.num;
    nCellsVE = Gt.cells.num;
    
    % Estimate from coordinates
    xCoords = G.nodes.coords(:, 1);
    yCoords = G.nodes.coords(:, 2);
    zCoords = G.nodes.coords(:, 3);
    
    xRange = max(xCoords) - min(xCoords);
    yRange = max(yCoords) - min(yCoords);
    zRange = max(zCoords) - min(zCoords);
    
    % Rough estimate of cells per direction
    % Assuming roughly cubic cells
    cellsPerDir = nCells^(1/3);
    
    scale = [xRange, yRange, zRange] / cellsPerDir;
    
    fprintf('\n========== GRID SCALE ANALYSIS ==========\n');
    fprintf('Total 3D cells: %d\n', nCells);
    fprintf('Total VE cells: %d\n', nCellsVE);
    fprintf('Estimated cells per direction: %.0f\n', cellsPerDir);
    fprintf('Domain size: [%.1f, %.1f, %.1f] units\n', xRange, yRange, zRange);
    fprintf('Approx. cell size: [%.2f, %.2f, %.2f] units\n', scale(1), scale(2), scale(3));
    fprintf('\n');
    
    gridDims = round([sqrt(nCellsVE), sqrt(nCellsVE), 11]); % Johansen has 11 layers
end

% =========================================================================
% FUNCTION 7: Generate Synthetic Reference Data
% =========================================================================
function syntheticWells = generateSyntheticWells(refLat, refLon, nWells, radius)
%GENERATESYNTHETICWELLS Create synthetic wells for testing
%
% INPUT:
%   refLat, refLon - Center coordinates
%   nWells - Number of wells to generate
%   radius - Radius around reference point (in degrees)
%
% OUTPUT:
%   syntheticWells - struct array with .lat, .lon fields

    theta = linspace(0, 2*pi, nWells+1);
    theta = theta(1:end-1);
    
    syntheticWells = struct('name', {}, 'lat', {}, 'lon', {});
    
    for i = 1:nWells
        r = (i / nWells) * radius; % Radial spacing
        syntheticWells(i).name = sprintf('Synthetic_%d', i);
        syntheticWells(i).lat = refLat + r * cos(theta(i));
        syntheticWells(i).lon = refLon + r * sin(theta(i));
    end
end

% =========================================================================
% MAIN TEST SCRIPT
% =========================================================================
% Uncomment to run validation tests

% % Load grid
% mrstModule add co2lab-common co2lab-legacy mimetic
% [G, rock, ~, Gt, rock2D, bcIxVE] = makeJohansenVEgrid();
% 
% % Read well data
% wellData = readtable('well_loc.csv');
% wellLats = table2array(wellData(:, 'NS_DEC_DEG'));
% wellLons = table2array(wellData(:, 'EW_DEC_DEG'));
% wellNames = table2array(wellData(:, 'Well_Bore_Name'));
% 
% % Transform coordinates
% refLat = 60.576425;
% refLon = 3.443367;
% refGridX = 51;
% refGridY = 51;
% 
% [wellGridX, wellGridY] = transformWellCoordinates(wellLats, wellLons, ...
%     refLat, refLon, refGridX, refGridY);
% 
% % Identify valid wells
% gridXmin = min(G.nodes.coords(:, 1));
% gridXmax = max(G.nodes.coords(:, 1));
% gridYmin = min(G.nodes.coords(:, 2));
% gridYmax = max(G.nodes.coords(:, 2));
% 
% margin = 2;
% validWellIdx = find((wellGridX >= gridXmin + margin) & ...
%                     (wellGridX <= gridXmax - margin) & ...
%                     (wellGridY >= gridYmin + margin) & ...
%                     (wellGridY <= gridYmax - margin));
% 
% % Visualize
% visualizeWellLocations(wellLats, wellLons, wellNames, ...
%     wellGridX, wellGridY, G, Gt, validWellIdx);
% 
% % Check spacing
% distances = computeWellDistances(wellGridX, wellGridY, validWellIdx);
% 
% % Export for validation
% exportWellPositions(wellLats, wellLons, wellNames, ...
%     wellGridX, wellGridY, validWellIdx, 'well_validation_output.csv');