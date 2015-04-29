function [user] = downlinkUserSpesificDecode(user, rxWaveform, rxWaveformInfo, cec)
% [enb, user] = downlinkUserSpesificDecode(enb, user, rxWaveform, rxWaveformInfo, cec) Summary of this function goes here
%   Detailed explanation goes here

%% Parameterization

nRxAnts = 1;                      % number of receive antennas

%% Demodulate all bandwidth

% Calculate time domain offset
if mod(user.enb.NSubframe,10) == 0                                                       % Matlab only calculate Time Domain offset using PSS 
    user.timeDomainOffset = lteDLFrameOffset(user.enb, rxWaveform,struct('CRS','On'));    % and SSS then offset only updated every 5 Subframe
end


% Data before the beginning of the frame is not useful
rxWaveform = rxWaveform(1 + user.timeDomainOffset:end);

% OFDM demodulation
rxgrid = lteOFDMDemodulate(user.enb, rxWaveform);


griddims = lteResourceGridSize(user.enb);   % Resource grid dimensions
L = griddims(2);                            % Number of OFDM symbols in a subframe

%% Perform channel estimation
% try
    [hest, nest] = lteDLChannelEstimate(user.enb, cec, rxgrid(:,1:L,:));
% catch ME
%     if (strcmp(ME.message,'Index exceeds matrix dimensions.'))
%         user.enb =[];
%     end
%     return
% end

%% Decode CFI

pcfichIndicesUE = ltePCFICHIndices(user.enb);                  % Get PCFICH indices
[rxInd, chInd] = hSIB1RecoveryReceiverIndices(user.enb, pcfichIndicesUE, nRxAnts);

% Decode PCFICH
cfiBitsUE = ltePCFICHDecode(user.enb, rxgrid(rxInd), hest(chInd), nest);

user.enb.CFI = lteCFIDecode(cfiBitsUE);                        % Get CFI

%% Decode PDCCH

pdcchIndices = ltePDCCHIndices(user.enb);                      % Get PDCCH indices
[rxInd, chInd] = hSIB1RecoveryReceiverIndices(user.enb, pdcchIndices, nRxAnts);
[dciBitsUE, pdcchSymbolsUE] = ltePDCCHDecode(user.enb, rxgrid(rxInd), hest(chInd), nest);    

%% Decode User Data

    
% PDCCH blind search for System Information (SI) and DCI decoding. The
% LTE System Toolbox provides full blind search of the PDCCH to find
% any DCI messages with a specified RNTI
pdcchUE.RNTI = user.RNTI;
dciUE = ltePDCCHSearch(user.enb, pdcchUE, dciBitsUE); % Search PDCCH for DCI

% try
    dciUE = dciUE{1};
% catch ME
%     if (strcmp(ME.message,'Index exceeds matrix dimensions.'))
%         user.data =[];
%     end
%     return
% end


% convert MCS to modulation scheme
[modulation, itbs] = hMCSConfiguration(dciUE.ModCoding);



% Set general PDSCH parameters
pdschUE.RNTI = pdcchUE.RNTI;
pdschUE.PRBSet = lteDCIResourceAllocation(user.enb, dciUE);
pdschUE.NLayers = user.enb.CellRefP;
pdschUE.RV = dciUE.RV;
pdschUE.Modulation = {modulation};
pdschUE.NTurboDecIts = 5;
pdschUE.CSIMode = 'PUCCH 1-0';
if (user.enb.CellRefP==1)
    pdschUE.TxScheme = 'Port0';
else
    pdschUE.TxScheme = 'TxDiversity';
end


% Get PDSCH indices

[pdschIndicesUE, info] = ltePDSCHIndices(user.enb, pdschUE, pdschUE.PRBSet);

% Decode PDSCH and calculate CQI
[rxInd, chInd] = hSIB1RecoveryReceiverIndices(user.enb, pdschIndicesUE, nRxAnts);
dlschUE = ltePDSCHDecode(user.enb, pdschUE,  rxgrid(rxInd), hest(chInd), nest);
%cqi = lteCQISelect(user.enb, pdschUE, hest(chInd), nest);
% Calculate Transfer Block Size
tbs = lteTBS(size(pdschUE.PRBSet,1),itbs);

% Decode DLSCH

[dlschBitUE, crcDLSCH] = lteDLSCHDecode(user.enb, pdschUE, tbs, dlschUE);

% Recover user data, add CRC and CQI info

user.data = dlschBitUE{1,1};
user.dataCRC = crcDLSCH;
%user.CQI = cqi;
end


        


