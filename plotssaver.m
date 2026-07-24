figs = findall(groot,'Type','figure');
for k = 1:numel(figs)
    exportgraphics(figs(k), fullfile(outputDir,'figures',sprintf('Figure_%02d.png',k)), ...
        'Resolution',300);
end