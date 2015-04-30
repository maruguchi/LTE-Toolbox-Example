function [waveform, wavefromInfo, grid, user ] = uplinkUserSpesific(user,pucch)
%UPLINKUSERSPESIFIC Summary of this function goes here
%   Detailed explanation goes here

%% ue (terminal parameterization)
%% FDD type

% according to spesification some of these parameter is carried to UE by MIB and SIB

user.ue.NULRB = user.enb.NDLRB;                    % Number Uplink Resource Block similar to downlink one
user.ue.CyclicPrefixUL = user.enb.CyclicPrefix;    % Uplink cyclic prefix similar to downlink
user.ue.Hopping = 'Off';                           % No frequency hopping
user.ue.NCellID = user.enb.NCellID;                % Cell id simila to downlink Physical Cell ID
user.ue.Shortened = 0;                             % No SRS transmission 
user.ue.NTxAnts = 1;                               % Number of UE antenna (SISO system) 
user.ue.NSubframe = user.enb.NSubframe + 1;        % Uplink Subframe number ACK send after eNodeb Subframe received

% PUCCH Format 1a to carry SISO ACK 

pucch.ResourceIdx = user.ue.PUCCHResourceIndex;    

% generate uplink transmit grid
grid = lteULResourceGrid(user.ue);

% Generate PUCCH 1 and its DRS
% Different users have different relative powers
pucch1Sym = ltePUCCH1(user.ue,pucch,user.dataCRC);
pucch1DRSSym = ltePUCCH1DRS(user.ue,pucch);

% Generate indices for PUCCH 1 and its DRS
pucch1Indices = ltePUCCH1Indices(user.ue,pucch);
pucch1DRSIndices = ltePUCCH1DRSIndices(user.ue,pucch);

% Map PUCCH 1 and PUCCH 1 DRS to the resource grid
grid(pucch1Indices) = pucch1Sym;
grid(pucch1DRSIndices) = pucch1DRSSym;


% SC-FDMA modulation
[waveform, wavefromInfo] = lteSCFDMAModulate(user.ue,grid);

end

