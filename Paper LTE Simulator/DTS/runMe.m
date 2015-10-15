% random seed
rng(0)
% create simulator
sim = simulator(2,0.001); % 2 second simulation time , 1 ms packet interarrival time
% run the simulator
sim.run;