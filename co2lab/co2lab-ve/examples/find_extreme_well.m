mrstModule add co2lab-ve
[G, rock] = setupJohansenVE();

min_active_I = 100;
for I = 1:50
    J = round(51 - (I - 51)/22);
    hasActive = false;
    for k = 6:10
        wc_g = false(G.cartDims);
        wc_g(I, J, k) = true;
        wc = find(wc_g(G.cells.indexMap));
        if ~isempty(wc)
            hasActive = true;
            break;
        end
    end
    if hasActive
        fprintf('Active at I=%d, J=%d\n', I, J);
        min_active_I = min(min_active_I, I);
    end
end
best_J = round(51 - (min_active_I - 51)/22);
fprintf('Extrema is I=%d, J=%d\n', min_active_I, best_J);
