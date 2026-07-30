function [G, rock] = loadJohansen()

    %% Required modules
    mrstModule add ...
        ad-core ...
        ad-blackoil ...
        ad-props ...
        co2lab-common ...
        hybrid-ve;

    gravity reset on;

    %% Load official Johansen model
    [G, rock] = makeJohansenVEgrid();

    fprintf('\n=====================================\n');
    fprintf('Johansen model loaded successfully\n');
    fprintf('=====================================\n');
    fprintf('Cells : %d\n', G.cells.num);
    fprintf('Grid  : %d x %d x %d\n', G.cartDims);
    fprintf('=====================================\n');

end