% clear and reset random seed
clear
rng(1);

% create simulator
% 6 user 1 ms arrival rate and 2 seconds of simualtion time
sim = simulator(lteENBPhysical, 6, lteRRscheduler, struct('lamda',5000), 2);

% running simulator
sim.run