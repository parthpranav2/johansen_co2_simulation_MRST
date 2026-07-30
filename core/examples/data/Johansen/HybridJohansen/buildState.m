function state0 = buildState(model)
%BUILDSTATE Create the initial reservoir state

    G = model.G;
    fluid = model.fluid;

    %% Reference pressure
    pRef = 300*barsa;

    %% Hydrostatic initialization
    z = G.cells.centroids(:,3);

    rhoW = fluid.rhoWS;

    p = pRef + rhoW*norm(gravity())*(z - min(z));

    %% Initial saturation
    sW = ones(G.cells.num,1);
    sG = zeros(G.cells.num,1);

    state0 = initResSol(G, p);

    state0.s = [sW sG];

    fprintf("\n=====================================\n");
    fprintf("Initial Reservoir State Created\n");
    fprintf("=====================================\n");
    fprintf("Pressure range : %.2f - %.2f bar\n", ...
        min(p)/barsa, max(p)/barsa);
    fprintf("=====================================\n");

end