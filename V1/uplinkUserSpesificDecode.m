function [ user ] = uplinkUserSpesificDecode(user, waveform, waveformInfo)
%[ user ] = uplinkUserSpesificDecode(user, waveform, waveformInfo) Summary of this function goes here
%   Detailed explanation goes here

% SISO

nRxAnts = 1;
%% calculate transpot block size using uplink resource allocation type 0
% PRB set and modulation


[modulation, itbs] = hMCSConfiguration(user.MCS);

user.pusch.PRBSet = (user.RBstart : user.RBlength - 1).';
user.pusch.Modulation = modulation;

tbs = lteTBS(size(user.pusch.PRBSet,1),itbs);


%% Frame Offset detection and correction

offset = lteULFrameOffset(user.ue,user.pusch,waveform); % no resample because enodeb aware of ue sampling rate
waveform = waveform(1+offset:end);

%% SC FDMA demodulation
rxGrid = lteSCFDMADemodulate(user.ue,waveform);




%% Peform channel estimation 
cec = struct('FreqWindow',7,'TimeWindow',1,'InterpType','cubic');
[hest nest] = lteULChannelEstimate(user.ue,user.pusch,cec,rxGrid);

%% PUSCH Decode
puschIndices = ltePUSCHIndices(user.ue,user.pusch);
[rxInd, chInd] = hSIB1RecoveryReceiverIndices(user.ue, puschIndices, nRxAnts);

[codeWord,symbols] = ltePUSCHDecode(user.ue,user.pusch,rxGrid(rxInd),hest(rxInd),nest);

%% Recover ULSCH Data

[user.data,blkcrc,stateout]= lteULSCHDecode(user.ue,user.pusch,tbs,codeWord); 



end

