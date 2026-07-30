mrstModule add co2lab-ve
run('example3DJohansen.m');
for i=1:length(schedule.control)
    disp(['Control ' num2str(i) ': W.status = ' num2str([schedule.control(i).W.status])]);
end
