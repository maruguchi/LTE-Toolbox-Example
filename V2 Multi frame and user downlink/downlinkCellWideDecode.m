function enb = downlinkCellWideDecode(enb, rxWaveform, rxWaveformInfo, cec)
% enb = downlinkCellWideDecode(enb, rxWaveform, cec) Summary of this function goes here
%   Detailed explanation goes here

%% Parameterization

nRxAnts = 1;                      % number of receive antennas


% Set eNodeB initial basic parameters to decode BCH
% eNodeB config structure
enb.DuplexMode = 'FDD';         % need to know how to decode duplex mode
enb.CyclicPrefix = 'Normal';    % need to know how to decode CP type
enb.NDLRB = 6;                  % Number of resource blocks minimum for PSS and SSS

ofdmInfo = lteOFDMInfo(enb);    % OFDM sampling rate


%% Downsampling receiver signal to match minimum bandwidth

downsampling = rxWaveformInfo.SamplingRate/...
    ofdmInfo.SamplingRate;      % Downsampling factor in order to demodulate OFDM signal

% Downsample loaded samples to match minimum bandwitdh
downsampled = resample(rxWaveform, 1, downsampling);



%% Cell search and synchronization

[enb.NCellID, offset] = lteCellSearch(enb, downsampled);
downsampled = downsampled(1+offset:end);
% pad with zeros after ofset
%downsampled((size(downsampled,1)+1):(size(downsampled,1)+offset)) = zeros(); 
enb.NSubframe = 0;

%% Additional Parameterization

% Assume 4 cell-specific reference signals for initial decoding attempt;
% ensures channel estimates are available for all cell-specific reference
% signals
enb.CellRefP = 4;

griddims = lteResourceGridSize(enb); % Resource grid dimensions
L = griddims(2);                     % Number of OFDM symbols in a subframe

%% Get MIB data to recover cell setting

% OFDM demodulate signal
rxgrid = lteOFDMDemodulate(enb, downsampled);

% Perform channel estimation

[hest, nest] = lteDLChannelEstimate(enb, cec, rxgrid(:,1:L,:));

    
% Decoding MIB
pbchIndices = ltePBCHIndices(enb); % Obtain PBCH grid indices
[rxInd, chInd] = hSIB1RecoveryReceiverIndices(enb, pbchIndices, nRxAnts);
% Decode PBCH
[bchBits, pbchSymbols, nfmod4, mib, enb.CellRefP] = ltePBCHDecode( ...
                                    enb, rxgrid(rxInd), hest(chInd), nest);
                  
% check enb configuration

try
    griddims = lteResourceGridSize(enb);
catch ME
    enb =[];
    return
end

% Parse MIB bits
enb = lteMIB(mib, enb);

% Incorporate the nfmod4 value output from the function ltePBCHDecode, as
% the NFrame value established from the MIB is the System Frame Number
% (SFN) modulo 4 (it is stored in the MIB as floor(SFN/4))
enb.NFrame = enb.NFrame+nfmod4;


end

