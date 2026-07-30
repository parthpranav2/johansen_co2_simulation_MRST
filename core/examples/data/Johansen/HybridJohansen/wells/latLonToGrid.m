function T = latLonToGrid(T, G)
%%--------------------------------------------------------------------------
% LATLONTOGRID Convert Latitude/Longitude coordinates to grid indices
%
% Inputs:
%   T - Table of well specifications with NS_DEC_DEG and EW_DEC_DEG
%   G - MRST grid structure
%
% Outputs:
%   T - Table updated with Grid_X and Grid_Y columns and out-of-grid wells filtered
%%--------------------------------------------------------------------------

    fprintf('\n=====================================\n');
    fprintf('Converting Lat/Lon Coordinates -> Grid Indices\n');
    fprintf('=====================================\n');

    %% ---------------------------------------------------------------------
    % Geographic Reference Parameters (Johansen Field)
    %% ---------------------------------------------------------------------
    refLat   = 60.576425;  % Reference Latitude
    refLon   = 3.443367;   % Reference Longitude
    refX     = 51;         % Grid cell X coordinate of reference point
    refY     = 51;         % Grid cell Y coordinate of reference point

    cellSize = 100;        % Grid cell width (m)
    R        = 6378137;    % Mean Earth radius (m)

    %% ---------------------------------------------------------------------
    % Coordinate Conversion Calculation
    %% ---------------------------------------------------------------------
    n = height(T);
    Grid_X = zeros(n, 1);
    Grid_Y = zeros(n, 1);

    for k = 1:n
        lat = T.NS_DEC_DEG(k);
        lon = T.EW_DEC_DEG(k);

        dNorth = deg2rad(lat - refLat) * R;
        dEast  = deg2rad(lon - refLon) * R * cos(deg2rad(refLat));

        Grid_X(k) = round(refX + dEast  / cellSize);
        Grid_Y(k) = round(refY + dNorth / cellSize);
    end

    T.Grid_X = Grid_X;
    T.Grid_Y = Grid_Y;

    %% ---------------------------------------------------------------------
    % Filter Boundary & Out-of-Grid Wells
    %% ---------------------------------------------------------------------
    nx = G.cartDims(1);
    ny = G.cartDims(2);

    inside = Grid_X >= 1 & Grid_X <= nx & ...
             Grid_Y >= 1 & Grid_Y <= ny;

    nRemoved = sum(~inside);
    if nRemoved > 0
        fprintf('Filtered out %d wells located outside simulation grid boundaries.\n', nRemoved);
    end

    T = T(inside, :);

    %% ---------------------------------------------------------------------
    % Display Summary
    %% ---------------------------------------------------------------------
    fprintf('Converted %d active wells successfully.\n', height(T));
    if ~isempty(T)
        fprintf('Grid X Range : %d -> %d\n', min(T.Grid_X), max(T.Grid_X));
        fprintf('Grid Y Range : %d -> %d\n', min(T.Grid_Y), max(T.Grid_Y));
    end
    fprintf('=====================================\n');

end
