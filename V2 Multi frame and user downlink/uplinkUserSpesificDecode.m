function [ user ] = uplinkUserSpesificDecode(user, pucch, waveform, cec )
%UPLINKUSERSPESIFICDECODE Summary of this function goes here
%   Detailed explanation goes here

% Synchronization
% The uplink frame timing estimate for UE1 is calculated using
% the PUCCH 1 DRS signals and then used to demodulate the
% SC-FDMA signal.
% An offset within the range of delays expected from the channel
% modeling (a combination of implementation delay and channel
% delay spread) indicates success.
pucch.ResourceIdx = user.ue.PUCCHResourceIndex; 

offset = lteULFrameOffsetPUCCH1(user.ue, pucch, waveform);
if (offset<25)
    offsetused = offset;
end

% SC-FDMA demodulation
% The resulting grid (rxgrid) is a 3-dimensional matrix. The number
% of rows represents the number of subcarriers. The number of
% columns equals the number of SC-FDMA symbols in a subframe. The
% number of subcarriers and symbols is the same for the returned
% grid from lteSCFDMADemodulate as the grid passed into
% lteSCFDMAModulate. The number of planes (3rd dimension) in the
% grid corresponds to the number of receive antenna.

rxgrid = lteSCFDMADemodulate(user.ue,waveform(1+offsetused:end,:));


% Channel estimation
[H,n0] = lteULChannelEstimatePUCCH1(user.ue,pucch,cec,rxgrid);

% PUCCH 1 indices for UE of interest
pucch1Indices = ltePUCCH1Indices(user.ue,pucch);

% Extract resource elements (REs) corresponding to the PUCCH 1 from
% the given subframe across all receive antennas and channel
% estimates
[pucch1Rx,pucch1H] = lteExtractResources(pucch1Indices,rxgrid,H);

% Minimum Mean Squared Error (MMSE) Equalization
eqgrid = lteULResourceGrid(user.ue);
eqgrid(pucch1Indices) = lteEqualizeMMSE(pucch1Rx,pucch1H,n0);

% PUCCH 1 decoding
user.dataACK = ltePUCCH1Decode(user.ue,pucch,1,eqgrid(pucch1Indices));





end

