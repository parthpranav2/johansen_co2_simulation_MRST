function fluid = buildFluid(cfg)
%%--------------------------------------------------------------------------
% BUILDFLUID Construct 2-phase (Water-CO2) fluid model for Johansen
%
% Inputs:
%   cfg   - (Optional) Fluid configuration structure from fluidConfig()
%
% Outputs:
%   fluid - MRST AD fluid structure initialized with PVT & relative perm
%%--------------------------------------------------------------------------

    %% ---------------------------------------------------------------------
    % Default Configuration if not provided
    %% ---------------------------------------------------------------------
    if nargin < 1 || isempty(cfg)
        cfg = fluidConfig();
    end

    %% ---------------------------------------------------------------------
    % Construct AD Fluid Object from Configuration
    %% ---------------------------------------------------------------------
    fluid = initSimpleADIFluid(...
        'phases', 'WG', ...
        'mu',     [cfg.muW, cfg.muG] * centi * poise, ...
        'rho',    [cfg.rhoW, cfg.rhoG] * kilogram / meter^3, ...
        'n',      [cfg.nW, cfg.nG], ...
        'c',      [cfg.cW, cfg.cG], ...
        'pRef',   cfg.pRef);

end
