function [enb, user] = downlinkUserSpesificDecode(enb, user, rxWaveform, rxWaveformInfo, cec)
% [enb, user] = downlinkUserSpesificDecode(enb, user, rxWaveform, rxWaveformInfo, cec) Summary of this function goes here
%   Detailed explanation goes here

%% Parameterization

nRxAnts = 1;                      % number of receive antennas




%% Demodulate all bandwidth

% Find beginning of frame
offset = lteDLFrameOffset(enb, rxWaveform);
% Data before the beginning of the frame is not useful
rxWaveform = rxWaveform(1+offset:end);
%rxWaveform = rxWaveform(1:(end-(10-offset)));
% pad with zeros after ofset
% if offset > 0
%     rxWaveform((size(rxWaveform,1)+1):(size(rxWaveform,1)+offset)) = zeros(); 
% end

% OFDM demodulation
rxgrid = lteOFDMDemodulate(enb, rxWaveform);


griddims = lteResourceGridSize(enb); % Resource grid dimensions
L = griddims(2);                     % Number of OFDM symbols in a subframe

%% Perform channel estimation
try
    [hest, nest] = lteDLChannelEstimate(enb, cec, rxgrid(:,1:L,:));
catch ME
    if (strcmp(ME.message,'Index exceeds matrix dimensions.'))
        enb =[];
    end
    return
end

%% Decode CFI

pcfichIndicesUE = ltePCFICHIndices(enb);                  % Get PCFICH indices
[rxInd, chInd] = hSIB1RecoveryReceiverIndices(enb, pcfichIndicesUE, nRxAnts);

% Decode PCFICH
cfiBitsUE = ltePCFICHDecode(enb, rxgrid(rxInd), hest(chInd), nest);

enb.CFI = lteCFIDecode(cfiBitsUE);                        % Get CFI

%% Decode PDCCH

pdcchIndices = ltePDCCHIndices(enb);                      % Get PDCCH indices
[rxInd, chInd] = hSIB1RecoveryReceiverIndices(enb, pdcchIndices, nRxAnts);
[dciBitsUE, pdcchSymbolsUE] = ltePDCCHDecode(enb, rxgrid(rxInd), hest(chInd), nest);    

%% Decode User Data
for  i = 1:size(user,2)
    
    % PDCCH blind search for System Information (SI) and DCI decoding. The
    % LTE System Toolbox provides full blind search of the PDCCH to find
    % any DCI messages with a specified RNTI
    pdcchUE.RNTI = user(i).RNTI;
    dciUE = ltePDCCHSearch(enb, pdcchUE, dciBitsUE); % Search PDCCH for DCI
    
    try
        dciUE = dciUE{1};
    catch ME
        if (strcmp(ME.message,'Index exceeds matrix dimensions.'))
            enb =[];
        end
        return
    end
    
    
    % convert MCS to modulation scheme 
    [modulation, itbs] = hMCSConfiguration(dciUE.ModCoding);
    
    
    
    % Set general PDSCH parameters
    pdschUE.RNTI = pdcchUE.RNTI;
    pdschUE.PRBSet = lteDCIResourceAllocation(enb, dciUE);
    pdschUE.NLayers = enb.CellRefP; 
    pdschUE.RV = dciUE.RV;
    pdschUE.Modulation = {modulation}; 
    if (enb.CellRefP==1)
        pdschUE.TxScheme = 'Port0';
    else
        pdschUE.TxScheme = 'TxDiversity';
    end   
    
    
    % Get PDSCH indices
    
    [pdschIndicesUE, info] = ltePDSCHIndices(enb, pdschUE, pdschUE.PRBSet);
    
    % Decode PDSCH
    [rxInd, chInd] = hSIB1RecoveryReceiverIndices(enb, pdschIndicesUE, nRxAnts);
    dlschUE = ltePDSCHDecode(enb, pdschUE,  rxgrid(rxInd), hest(chInd), nest);
    
    % Calculate Transfer Block Size    
    tbs = lteTBS(size(pdschUE.PRBSet,1),itbs);
    
    % Decode DLSCH
    
    [dlschBitUE, crc] = lteDLSCHDecode(enb, pdschUE, tbs, dlschUE);
    
    % Recover user data
    
    user(i).data = dlschBitUE{1,1};
    
end
        


