function [ waveform, waveformInfo, resourceGrid, info ] = lteDLPHYTX(enb, sharedChannel)
% lteDLPHYTX
% Process channel and signal insertion to LTE OFDM resource grid in
% downlink transmission for one subframe or a LTE TTI (1 ms)


% Matlab code for LTE downlink physical layer transmitter
% written by Andi Soekartono, MSC Telecommunication
% Date 05-May-2015

%% Creating empty downlink resource grid

% Matlab LTE Toolbox to generate resource grid
resourceGrid = lteDLResourceGrid(enb);



%% Inserting physical signal into resource grid

% Matlab LTE Toolbox to generate PSS spesific index in resource grid
pssIndices = ltePSSIndices(enb);
% Matlab LTE Toolbox to generate PSS signal for each resource element
pssSymbols = ltePSS(enb);

% Insert PSS symbol into resource grid according to its indices
resourceGrid(pssIndices) = pssSymbols;


% Matlab LTE Toolbox to generate SSS spesific index in resource grid
sssIndices = lteSSSIndices(enb);
% Matlab LTE Toolbox to generate SSS symbol for each resource element
sssSymbols = lteSSS(enb);

% Insert SSS symbol into resource grid according to its indices
resourceGrid(sssIndices) = sssSymbols;

% Matlab LTE Toolbox to generate SSS spesific index in resource grid
crsIndices = lteCellRSIndices(enb);
% Matlab LTE Toolbox to generate SSS symbol for each resource element
crsSymbols = lteCellRS(enb);

% Insert CRS symbol into resource grid according to its indices
resourceGrid(crsIndices) = crsSymbols;


%% Inserting physical channel into resource grid


%% Inserting PBCH with MIB (Master Information Block) to grid
% scheduled every subframe 0 for FDD mode

if mod(enb.NSubframe,10) == 0
    % MIB to PBCH insertion
    % Matlab LTE Toolbox to generate 24-bit-long MIB message containing cell-wide setting specified in enb
    mib = lteMIB(enb);
    % Matlab LTE Toolbox to generate BCH transport channel coded bits containing MIB bits
    bchCoded = lteBCH(enb, mib);
    % Matlab LTE Toolbox to generate Physical BCH symbols
    pbchSymbols = ltePBCH(enb, bchCoded);
    % Matlab LTE Toolbox to generate PBCH spesific index in resource grid
    pbchIndices = ltePBCHIndices(enb);
    
    % PBCH symbols 40 ms periodicity spread
    % Each subframe 0 containing 1/4 bchCoded
    PBCHInd = mod((enb.NSubframe + 1 + enb.NFrame*10), 40);
    pbchSymStart = 1 + floor(PBCHInd / 10) * length(pbchIndices);
    pbchSymEnd = ceil(PBCHInd / 10) * length(pbchIndices);
    % map PBCH to grid
    resourceGrid(pbchIndices) = pbchSymbols(pbchSymStart:pbchSymEnd);
end

%% Inserting Control Format Indicator (CFI) and PCFICH
% Determine number of symbols used by L1/L2 control information every slot.

% Matlab LTE Toolbox to generate CFI Channel Coding
cfiBits = lteCFI(enb);

% Matlab LTE Toolbox to generate PCFICH symbol for corresponding CFI bits
pcfichSymbols = ltePCFICH(enb, cfiBits);

% Matlab LTE Toolbox to generate PCFICH spesific index in resource grid
pcfichIndices = ltePCFICHIndices(enb);

% Map PCFICH symbols to resource grid
resourceGrid(pcfichIndices) = pcfichSymbols;

%% Inserting DCCH and DTCH data
% Dedicated data for each spesific RNTI

% Channel insertion for each user

%   PDCCH space initialization
pdcchInfo = ltePDCCHInfo(enb);                                  % Get the total resources for PDCCH
selectedCandidate = [];
pdcchBits = -1 * ones(pdcchInfo.MTot, 1);                         % Initialized with -1

for  i = 1:size(sharedChannel, 2)
    if mod(enb.NSubframe,5) == 0 
        % for now skip subframe 0 and 5
        continue
    end
    
    %% DL-SCH Channel Coding
    
    [pdschIndices, pdschInfo] = ltePDSCHIndices(enb, sharedChannel(i).pdsch, sharedChannel(i).pdsch.PRBSet, {'1based'});
    
    
    % Perform Channel Coding and rate matching
    codedTrBlock = lteDLSCH(enb, sharedChannel(i).pdsch, pdschInfo.G, sharedChannel(i).data);
    
    data = sharedChannel(i).data;
    
    pdschSymbols = ltePDSCH(enb, sharedChannel(i).pdsch, codedTrBlock);
    resourceGrid(pdschIndices) = pdschSymbols;
    
    
    %% DCI message configuration
    
    [dciMessage, dciMessageBits] = lteDCI(enb, sharedChannel(i).dci);
    
    %% DCI Channel Coding
    
    % Performing DCI message bits coding to form coded DCI bits
    codedDciBits = lteDCIEncode(sharedChannel(i).pdcch, dciMessageBits);
    
    %% PDCCH Bits Generation

    % Performing search space for UE-specific control channel candidates
    candidates = ltePDCCHSpace(enb, sharedChannel(i).pdcch, {'bits','1based'});
    % find free candidates
    for j = 1 : size(candidates,1)
        match = find(selectedCandidate == candidates(j,1),1);
        if isempty(match)
            selectedCandidate(i) = candidates(j,1); %#ok<AGROW>
            break
        end
    end
    % Mapping PDCCH payload on available UE-specific candidate. 
    pdcchBits( candidates(j, 1) : candidates(j, 2) ) = codedDciBits;
    
end


%% PDCCH Complex Symbol Generation

pdcchSymbols = ltePDCCH(enb, pdcchBits);

%% PDCCH Mapping Indices Generation and Resource Grid Mapping

pdcchIndices = ltePDCCHIndices(enb, {'1based'});

% The complex PDCCH symbols are easily mapped to each of the resource grids
% for each antenna port
resourceGrid(pdcchIndices) = pdcchSymbols;








%% Signal generation by performing OFDM Modulation into transmit resource grid

% Matlab LTE Toolbox to perform OFDM Modulation
[waveform, waveformInfo] = lteOFDMModulate(enb,resourceGrid);


%% Return info about internal physical layer process

info = struct;
if exist('mib','var')
    info.mibBits = mib;
else
    info.mibBits = [];
end

info.cfiBits = cfiBits;

if exist('dciMessageBits','var')
    info.dciBits = dciMessageBits;
    info.dataBits = data;
else
    info.dciBits = [];
    info.dataBits = [];
end

if exist('dciMessage','var')
    info.dciMessage = dciMessage;
end


