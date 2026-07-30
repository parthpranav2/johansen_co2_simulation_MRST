function plotResults(model, states)
%PLOTRESULTS Interactive visualization of Hybrid-VE simulation

    fprintf('\n=====================================\n');
    fprintf('Opening MRST Result Viewer...\n');
    fprintf('=====================================\n');

    figure('Name','Hybrid Johansen Results', ...
           'Color','w', ...
           'Position',[100 100 1400 800]);

    plotToolbar(model.G, states);

end