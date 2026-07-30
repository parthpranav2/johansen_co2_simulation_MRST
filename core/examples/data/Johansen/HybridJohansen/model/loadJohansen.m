function [G, rock] = loadJohansen()
%%--------------------------------------------------------------------------
% LOADJOHANSEN Load official Johansen formation grid and petrophysics
%
% Description:
%   Loads the standard 3D grid and rock properties for the Johansen
%   formation using MRST's built-in co2lab dataset loader.
%
% Outputs:
%   G    - MRST grid structure
%   rock - Structure containing porosity (pora) and permeability (perm)
%%--------------------------------------------------------------------------

    %% ---------------------------------------------------------------------
    % Ensure MRST dependencies and gravity
    %% ---------------------------------------------------------------------
    mrstModule add ...
        ad-core ...
        ad-blackoil ...
        ad-props ...
        co2lab-common ...
        hybrid-ve;

    gravity reset on;

    %% ---------------------------------------------------------------------
    % Load Grid and Rock Data
    %% ---------------------------------------------------------------------
    [G, rock] = makeJohansenVEgrid();

    %% ---------------------------------------------------------------------
    % Display Summary
    %% ---------------------------------------------------------------------
    fprintf('\n=====================================\n');
    fprintf('Johansen Model Loaded Successfully\n');
    fprintf('=====================================\n');
    fprintf('Active Cells : %d\n', G.cells.num);
    fprintf('Cartesian    : %d x %d x %d\n', G.cartDims(1), G.cartDims(2), G.cartDims(3));
    fprintf('=====================================\n');

end
