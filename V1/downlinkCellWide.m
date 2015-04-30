function grid = downlinkCellWide(enb,grid)
% grid = downlinkCellWide(enb,grid)
% insert cell wide signals and channels
% only support SISO system (to be expanded to support MIMO)

% SISO parameter

antenna = 0;

%% PSS insertion
pss = ltePSS(enb);
pssIndices = ltePSSIndices(enb, antenna);
grid(pssIndices) = pss;

%% SSS insertion
sss = lteSSS(enb);
sssIndices = lteSSSIndices(enb, antenna);
grid(sssIndices) = sss;



%% CRS insertion
cellRsInd = lteCellRSIndices(enb,antenna);
cellRsSym = lteCellRS(enb,antenna);
grid(cellRsInd) = cellRsSym;

%% insert PBCH containing MIB (Master Information Block) to grid which scheduled every subframe 0
if mod(enb.NSubframe,10) == 0
    % MIB to PBCH insertion
    mib = lteMIB(enb);
    bchCoded = lteBCH(enb,mib);
    pbchSymbols = ltePBCH(enb,bchCoded);
    pbchInd = ltePBCHIndices(enb,{'1based'});
    pbchSize = length(pbchInd);
    % PBCH symbols 40 ms periodicity spread
    PBCHInd = mod(enb.NSubframe + 1, 40);
    pbchSymStart = 1 + floor(PBCHInd / 10) * pbchSize;
    pbchSymEnd = ceil(PBCHInd / 10) * pbchSize;
    % map PBCH to grid
    grid(pbchInd) = pbchSymbols(pbchSymStart:pbchSymEnd);
end

%% CFI and PCFICH insertion

% CFI Channel Coding

cfiBits = lteCFI(enb);

% PCFICH Complex Symbol Generation

pcfichSymbols = ltePCFICH(enb, cfiBits);

% PCFICH Indices Generation and Resource Grid Mapping

pcfichIndices = ltePCFICHIndices(enb);

% Map PCFICH symbols to resource grid
grid(pcfichIndices) = pcfichSymbols;


