function model = buildModel(G, rock, fluid)

    model = TwoPhaseWaterGasModel(G, rock, fluid);

    model.useCNVConvergence = true;
    model.extraStateOutput = true;

    fprintf('\n=====================================\n');
    fprintf('AD Reservoir Model Created\n');
    fprintf('=====================================\n');
    fprintf('Model Class : %s\n', class(model));
    fprintf('Cells       : %d\n', model.G.cells.num);
    fprintf('=====================================\n');

end