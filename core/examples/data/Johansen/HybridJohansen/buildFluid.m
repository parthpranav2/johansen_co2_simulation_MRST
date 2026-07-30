function fluid = buildFluid()
%BUILDFLUID Create fluid model for Johansen Hybrid-VE simulation

    %--------------------------------------------------------------
    % Fluid properties
    %--------------------------------------------------------------

    rhoW = 1000;     % kg/m^3
    rhoG = 700;      % kg/m^3 (supercritical CO2)

    muW = 0.5;       % cP
    muG = 0.05;      % cP

    cW = 4.35e-5/barsa;
    cG = 1e-3/barsa;

    pRef = 300*barsa;

    %--------------------------------------------------------------
    % Corey exponents
    %--------------------------------------------------------------

    nW = 2;
    nG = 2;

    %--------------------------------------------------------------
    % Create AD fluid
    %--------------------------------------------------------------

    fluid = initSimpleADIFluid(...
        'phases', 'WG', ...
        'mu',  [muW, muG]*centi*poise, ...
        'rho', [rhoW, rhoG]*kilogram/meter^3, ...
        'n',   [nW, nG], ...
        'c',   [cW, cG], ...
        'pRef', pRef);

end