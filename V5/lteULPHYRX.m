function [ sharedChannel] = lteULPHYRX( waveform,sharedChannel )
%LTEULPHYRX Summary of this function goes here
%   Detailed explanation goes here

% subframe number same with enb


% Synchronization

sharedChannel.pucch.ResourceIdx = sharedChannel.ue.PUCCHResourceIndex; 

offset = lteULFrameOffsetPUCCH1(sharedChannel.ue, sharedChannel.pucch, waveform);
if (offset<25)
    offsetused = offset;
end

% Apply offset to align waveform to beginning of the LTE Frame
waveform = waveform(1 + offsetused:end);
% Pad end of signal with zeros after offset alignment
waveform((size(waveform,1) + 1):(size(waveform,1) + offsetused)) = zeros();

% SC-FDMA demodulation


rxgrid = lteSCFDMADemodulate(sharedChannel.ue, waveform);

% Channel estimation
[H, n0] = lteULChannelEstimatePUCCH1(sharedChannel.ue, sharedChannel.pucch,rxgrid);

% PUCCH 1 indices for UE of interest
pucch1Indices = ltePUCCH1Indices(sharedChannel.ue, sharedChannel.pucch);

% Extract resource elements (REs) corresponding to the PUCCH 1 from
% the given subframe across all receive antennas and channel
% estimates

% Minimum Mean Squared Error (MMSE) Equalization

eqgrid = lteEqualizeMMSE(rxgrid, H, n0);

% PUCCH 1 decoding
sharedChannel.dataACK = ltePUCCH1Decode(sharedChannel.ue, sharedChannel.pucch, 1, eqgrid(pucch1Indices));


end

