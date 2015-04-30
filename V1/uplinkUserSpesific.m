function [grid, user, waveform, info] = uplinkUserSpesific(user)
%[grid, user, waveform] = uplinkUserSpesific(user) Summary of this function goes here
%   Detailed explanation goes here

%% one TTI uplink grid


grid = lteULResourceGrid(user.ue);


%% calculate transpot block size using uplink resource allocation type 0
% PRB set and modulation


[modulation, itbs] = hMCSConfiguration(user.MCS);

user.pusch.PRBSet = (user.RBstart : user.RBlength - 1).';
user.pusch.Modulation = modulation;

tbs = lteTBS(size(user.pusch.PRBSet,1),itbs);


%% insert PUSCH demodulation reference signal
puschRSInd = ltePUSCHDRSIndices(user.ue,user.pusch);
puschRSSeq = ltePUSCHDRS(user.ue,user.pusch);

grid(puschRSInd) = puschRSSeq;

%% insert userdata to ULSCH
if isempty(user.data)
    user.data = randi([0 1], tbs, 1);
else
    user.data = user.data(1:tbs);
end

codeWord = lteULSCH(user.ue,user.pusch,user.data);

%% Insert ULSCH to PUSCH
puschSymbols = ltePUSCH(user.ue,user.pusch,codeWord);

puschIndices = ltePUSCHIndices(user.ue,user.pusch);

grid(puschIndices) = puschSymbols;


%% Modulate
[waveform,info] = lteSCFDMAModulate(user.ue,grid);


end

