function [ enb, info ] = lteDLPHYRX( waveform, waveformInfo , enb, userChannel)
% lteDLPHYRX
% Perform synchronization, demodulation and decoding of received LTE downlink transmission
% signal into spesific information

% Matlab code for LTE downlink physical layer receiver
% written by Andi Soekartono, MSC Telecommunication
% Date 06-May-2015

%% Initial cell wide setting
% Checking cell wide setting at UE if empty use basic cell setting to decode center 72
% sub carrier (6 RB) where PSS and SSS and PBCH lies.

if isempty(enb)
    enb.DuplexMode = 'FDD';         % Default duplex mode
    enb.CyclicPrefix = 'Normal';    % Default cyclic prefix length
    enb.NDLRB = 6;                  % Number minimium resource block to decode PSS and SSS
    enb.CellRefP = 1;               % Assume Nodeb have 1 antenna port
    
    % Matlab resample function to match signal sampling rate with
    % appropriate LTE defined sampling rate for 6 RB (1.92 MHz)
    ofdmInfo = lteOFDMInfo(enb);
    resampledWaveform = resample(waveform, 1, waveformInfo.SamplingRate/ofdmInfo.SamplingRate);
    
    % Matlab LTE Toolbox to peform cell search using PSS and SSS pattern to
    % determine  Physical Cell ID and time domain signal offset
    [enb.NCellID, offset] = lteCellSearch(enb, resampledWaveform);
    
    % Apply offset to align waveform to beginning of the LTE Frame
    resampledWaveform = resampledWaveform(1 + offset:end);
    % Pad end of signal with zeros after offset alignment
    resampledWaveform((size(resampledWaveform,1)+1):(size(resampledWaveform,1) + offset)) = zeros();
    
    % Set subframe to 0 (begining of LTE Frame)
    enb.NSubframe = 0;
    
    % Matlab LTE Toolbox to peform OFDM demodulation to received signal into resource grid
    resourceGrid = lteOFDMDemodulate(enb, resampledWaveform);
    
    % Peform channel estimation and equalization
    %[hest,noisest] = lteDLChannelEstimate(enb,resourceGrid);
    %resourceGrid = lteEqualizeMMSE(resourceGrid, hest, noisest);
    
    % Matlab LTE Toolbox to generate PBCH spesific index in resource grid
    pbchIndices = ltePBCHIndices(enb);
    % Matlab LTE Toolbox to decode Physical BCH symbols into MIB bits
    [bchBits, pbchSymbols, nfmod4, mib, enb.CellRefP] = ltePBCHDecode(enb, resourceGrid(pbchIndices));
    
    % Matlab LTE Toolbox to decode MIB bits into cell wide settings
    enb = lteMIB(mib, enb);
    % Calculating exact SFN
    enb.NFrame = enb.NFrame + nfmod4;
    
else
    % if cell wide setting is known by UE
    % increase sub frame number for every iteration
    enb.NSubframe = mod(enb.NSubframe + 1,10);
end


%% Demodulate and decode all bandwidth when cell setting is aquired


% Time domain synchronization update when beginning of the frame (subframe 0)
if enb.NSubframe == 0
    % Matlab LTE Toolbox to find the beginning of the frame
    enb.offset = lteDLFrameOffset(enb, waveform);
end

% Apply offset to align waveform to beginning of the LTE Frame
waveform = waveform(1 + enb.offset:end);
% Pad end of signal with zeros after offset alignment
waveform((size(waveform,1)+1):(size(waveform,1) + enb.offset)) = zeros();


% Matlab LTE Toolbox to peform OFDM demodulation to received signal into resource grid
resourceGrid = lteOFDMDemodulate(enb, waveform);

% Peform channel estimation and equalization
%[hest,noisest] = lteDLChannelEstimate(enb,resourceGrid);
% resourceGrid = lteEqualizeMMSE(resourceGrid, hest, noisest);


%% Decode BCH MIB in every subframe 0
% Skip if MIB already decode in initial cell wide setting procedure above
if ~exist('mib','var') && enb.NSubframe == 0
    
    % Matlab LTE Toolbox to generate PBCH spesific index in resource grid
    pbchIndices = ltePBCHIndices(enb);
    % Matlab LTE Toolbox to decode Physical BCH symbols into MIB bits
    [bchBits, pbchSymbols, nfmod4, mib, enb.CellRefP] = ltePBCHDecode(enb, resourceGrid(pbchIndices));
    
    % Matlab LTE Toolbox to decode MIB bits into cell wide settings
    enb = lteMIB(mib, enb);
    % Calculating exact SFN
    enb.NFrame = enb.NFrame + nfmod4;
    
end

%% Decode CFI

% Matlab LTE Toolbox to generate PCFICH spesific index in resource grid
pcfichIndices = ltePCFICHIndices(enb);
% Matlab LTE Toolbox to decode PCFICH symbols into CFI bits
cfiBits = ltePCFICHDecode(enb, resourceGrid(pcfichIndices));
% Matlab LTE Toolbox to decode CFI bits into CFI value
enb.CFI = lteCFIDecode(cfiBits);

%% Decode PDCCH

% Matlab LTE Toolbox to generate PDCCH spesific index in resource grid
pdcchIndices = ltePDCCHIndices(enb);
% Matlab LTE Toolbox to decode PCFICH symbols into CFI bits
[dciBitsOri, pdcchSymbols] = ltePDCCHDecode(enb, resourceGrid(pdcchIndices));

%% Decode DCI to get PPDSCH mapping in resource grid

% PDCCH blind search for System Information (SI) and DCI decoding. The
% LTE System Toolbox provides full blind search of the PDCCH to find
% any DCI messages with a specified RNTI

% input = inBits(pdcchCandidates(candidate,1):pdcchCandidates(candidate,2));
% [dciMessageBits,decRnti] = lteDCIDecode(dciConfig,input);

[dciFull,dciBitsFull] = ltePDCCHSearch(enb, userChannel.pdcch, dciBitsOri);

if ~isempty(dciFull)
    for i = 1:size(dciFull,2)
        if strcmp(dciFull{i}.DCIFormat,'Format1A')
            dci = dciFull{i};
            [~, dciBits] = lteDCI(enb, dci);
            % dciBits = dciBitsFull{1};
            break
        end
        dciBits = [];
    end
    
else
    dciBits = [];
end






%% Decode PDSCH and DSCH data
if exist('dci','var');
    
    try
        
        % convert MCS to modulation scheme
        [modulation, itbs] = hMCSConfiguration(dci.ModCoding);
        
        % Set general PDSCH parameters
        
        userChannel.pdsch.PRBSet = lteDCIResourceAllocation(enb, dci);
        userChannel.pdsch.NLayers = enb.CellRefP;
        userChannel.pdsch.RV = dci.RV;
        userChannel.pdsch.Modulation = {modulation};
        userChannel.pdsch.NTurboDecIts = 5;
        userChannel.pdsch.CSIMode = 'PUCCH 1-0';
        if (enb.CellRefP==1)
            userChannel.pdsch.TxScheme = 'Port0';
        else
            userChannel.pdsch.TxScheme = 'TxDiversity';
        end
        
        
        % Get PDSCH indices
        pdschIndices = ltePDSCHIndices(enb, userChannel.pdsch, userChannel.pdsch.PRBSet);
        
        % Decode PDSCH and calculate CQI
        dlsch = ltePDSCHDecode(enb, userChannel.pdsch,  resourceGrid(pdschIndices));
        % Calculate Transfer Block Size
        tbs = lteTBS(size(userChannel.pdsch.PRBSet,1),itbs);
        
        % Decode DLSCH
        [dlschBit, crcDLSCH] = lteDLSCHDecode(enb, userChannel.pdsch, tbs, dlsch);
        
        userChannel.data = dlschBit{1};
        userChannel.dataCRC = crcDLSCH;
    catch ME
        error =1;
    end
end

%% Return info about internal physical layer process

info = struct;
if exist('mib','var')
    info.mibBits = mib;
else
    info.mibBits = [];
end
info.cfiBits = lteCFI(enb);

info.dciBits = dciBits;
if exist('dlschBit','var')
    info.dataBits = dlschBit{1};
else
    info.dataBits = [];
end
if exist('dci','var');
    info.dci = dci;
end


