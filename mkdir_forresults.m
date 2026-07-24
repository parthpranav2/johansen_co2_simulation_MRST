runName = datestr(now,'dd_mm_yyyy__HH_MM');
outputDir = fullfile('/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/','outputs',runName);
mkdir(outputDir);
fig = 'figures';
mkdir(fullfile(outputDir,fig));