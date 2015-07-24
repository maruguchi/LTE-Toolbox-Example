% clear and reset random seed
clear
rng(1);

% create simulator
% 6 user 1 ms arrival rate and 2 seconds of simualtion time
enbPHY = lteENBPhysical;
scheduler = lteRRscheduler;

sim = simulator(enbPHY, 6, scheduler, struct('lamda',1500), 5);

% running simulator
sim.run