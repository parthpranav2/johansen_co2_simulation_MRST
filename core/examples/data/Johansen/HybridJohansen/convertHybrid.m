function [model_hyb, state_hyb, schedule_hyb] = convertHybrid(model, state0, schedule)

    fprintf('\n=====================================\n');
    fprintf('Converting to Hybrid-VE\n');
    fprintf('=====================================\n');

    fprintf('1/3  Converting model...\n');
    model_hyb = convertToMultiVEModel(model);

    fprintf('2/3  Upscaling state...\n');
    state_hyb = upscaleState(model_hyb, model, state0);

    fprintf('3/3  Upscaling schedule...\n');
    schedule_hyb = upscaleSchedule(model_hyb, schedule);

    fprintf('=====================================\n');
    fprintf('Hybrid-VE conversion successful.\n');
    fprintf('=====================================\n');

end