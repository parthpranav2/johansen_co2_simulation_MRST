function fluid = buildFluid()
%%--------------------------------------------------------------------------
% BUILDFLUID Construct 2-phase (Water-CO2) fluid model for Johansen
%
% Description:
%   Initializes an Automatic Differentiation (AD) fluid structure for a
%   two-phase Water-Gas system (brine and supercritical CO2).
%
% Outputs:
%   fluid - MRST AD fluid structure initialized with PVT & relative perm
%%--------------------------------------------------------------------------

    %% ---------------------------------------------------------------------
    % Physical Constants & PVT Properties
    %% ---------------------------------------------------------------------
    rhoW = 1000;          % Brine density (kg/m^3)
    rhoG = 700;           % Supercritical CO2 density (kg/m^3)

    muW = 0.5;            % Brine viscosity (cP)
    muG = 0.05;           % Supercritical CO2 viscosity (cP)

    cW = 4.35e-5 / barsa; % Brine compressibility (1/Pa)
    cG = 1.0e-3  / barsa; % CO2 compressibility (1/Pa)

    pRef = 300 * barsa;   % Reference pressure (Pa)

    %% ---------------------------------------------------------------------
    % Relative Permeability Exponents (Corey model)
    %% ---------------------------------------------------------------------
    nW = 2.0;             % Water relative permeability exponent
    nG = 2.0;             % Gas relative permeability exponent

    %% ---------------------------------------------------------------------
    % Construct AD Fluid Object
    %% ---------------------------------------------------------------------
    fluid = initSimpleADIFluid(...
        'phases', 'WG', ...
        'mu',     [muW, muG] * centi * poise, ...
        'rho',    [rhoW, rhoG] * kilogram / meter^3, ...
        'n',      [nW, nG], ...
        'c',      [cW, cG], ...
        'pRef',   pRef);

end
