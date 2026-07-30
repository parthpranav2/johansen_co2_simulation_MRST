function cfg = fluidConfig()
%%--------------------------------------------------------------------------
% FLUIDCONFIG Centralized fluid PVT and relative permeability parameters
%
% Description:
%   Defines phase properties, reference densities, viscosities,
%   compressibilities, and relative permeability parameters for Brine and CO2.
%
% Outputs:
%   cfg - Structure containing fluid physics configuration parameters
%%--------------------------------------------------------------------------

    %% ---------------------------------------------------------------------
    % Phase Densities & Viscosities
    %% ---------------------------------------------------------------------
    cfg.rhoW = 1000;          % Brine density (kg/m^3)
    cfg.rhoG = 700;           % Supercritical CO2 density (kg/m^3)

    cfg.muW  = 0.5;           % Brine viscosity (cP)
    cfg.muG  = 0.05;          % Supercritical CO2 viscosity (cP)

    %% ---------------------------------------------------------------------
    % Compressibility & Reference Conditions
    %% ---------------------------------------------------------------------
    cfg.cW   = 4.35e-5 / barsa; % Brine compressibility (1/Pa)
    cfg.cG   = 1.0e-3  / barsa; % Supercritical CO2 compressibility (1/Pa)

    cfg.pRef = 300 * barsa;     % Reference pressure (Pa)

    %% ---------------------------------------------------------------------
    % Relative Permeability Parameters (Corey Model)
    %% ---------------------------------------------------------------------
    cfg.nW   = 2.0;           % Water relative permeability exponent
    cfg.nG   = 2.0;           % Gas relative permeability exponent
    
    cfg.srW  = 0.0;           % Residual water saturation
    cfg.srG  = 0.0;           % Residual gas saturation

end
