function W = buildWell(model, rock)

%BUILDWELL Create a single CO2 injection well

    G = model.G;

    %---------------------------------------------------------
    % Injector location
    %---------------------------------------------------------

    i = 51;
    j = 51;

    % Perforate the entire reservoir
    k = 1:G.cartDims(3);

    %---------------------------------------------------------
    % Injection rate
    %---------------------------------------------------------

    pv = poreVolume(G, rock);

    totalTime = 10*year;

    injRate = 0.05*sum(pv)/totalTime;

    %---------------------------------------------------------
    % Create injector
    %---------------------------------------------------------

    W = [];

    W = verticalWell( ...
            W, ...
            G, ...
            rock, ...
            i, ...
            j, ...
            k, ...
            'Type', 'rate', ...
            'Val', injRate, ...
            'Radius', 0.15, ...
            'Comp_i', [0 1], ...
            'Name', 'Injector');

    fprintf("\n=====================================\n");
    fprintf("Injection Well Created\n");
    fprintf("=====================================\n");
    fprintf("Grid location : (%d,%d)\n",i,j);
    fprintf("Layers        : %d\n",numel(k));
    fprintf("Rate          : %.2f m^3/day\n", ...
        convertTo(injRate, meter^3/day));
    fprintf("=====================================\n");

end