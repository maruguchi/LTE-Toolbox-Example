function [ sharedChannel,userChannel ] = sharedChannelBuilder(enb,channelType,varargin)
% sharedChannel = sharedChannelBuilder(enb, type, allocationType, rnti, vrbStart, vrbLength, mcs, rv)

% Matlab code for building shared channel parameterization
% currently build parameterization to carry DTCH downlink 

% written by Andi Soekartono, MSC Telecommunication
% Date 06-May-2015

sharedChannel = struct;
userChannel = struct;

switch channelType
    case 'Downlink-DTCH'
        resourceAllocationType = varargin{1};
        switch resourceAllocationType
            case 2
                rnti = varargin{2};
                vrbStart = varargin{3};
                vrbLength = varargin{4};
                mcs = varargin{5};
                rv = varargin{6};
                
                [modulation, itbs] = hMCSConfiguration(mcs);
                tbs = lteTBS(vrbLength,itbs);
                
                % PDSCH Parameterization
                pdsch.NLayers = 1;                                            % No of layers
                pdsch.TxScheme = 'Port0';                                     % Transmission scheme SISO
                pdsch.Modulation = modulation;                                % Modulation scheme
                pdsch.RNTI = rnti;                                            % 16-bit UE-specific mask
                pdsch.RV = rv;                                                % Redundancy Version
                pdsch.PRBSet = (vrbStart : vrbStart+vrbLength - 1).';         % Subframe resource allocation
                
                [~, pdschInfo] = ltePDSCHIndices(enb, pdsch, pdsch.PRBSet, {'1based'});
                
                pdsch.codeRate = double(tbs)/double(pdschInfo.G);
                
                
                % DCI Parameterization
                dci.DCIFormat = 'Format1A';                                   % DCI message format
                dci.Allocation.RIV = allocation2RIV(enb,vrbStart,vrbLength);  % Resource indication value
                dci.ModCoding = mcs;                                          % MCS data
                dci.RV = rv;                                                  % Redudancy version
                
                % PDCCH Parameterization
                pdcch.NDLRB = enb.NDLRB;                                      % Number of DL-RB in total BW
                pdcch.RNTI = rnti;                                            % 16-bit value number
                pdcch.PDCCHFormat = 2;                                        % 2-CCE of aggregation level 2
                
                % Data Generation
                data = randi([0 1], tbs, 1);                                  % random bit generation
                
                
                % Output mapping
                sharedChannel.pdsch = pdsch;
                sharedChannel.dci = dci;
                sharedChannel.pdcch = pdcch;
                sharedChannel.data = data;
                
                userChannel.enb = [];
                userChannel.pdcch.RNTI = rnti;
                userChannel.pdsch.RNTI = rnti;
                userChannel.data = [];
                userChannel.dataCRC = [];
                
        end
end

    



function RIV = allocation2RIV(enb,vrbStart,vrbLength)
% RIV calculation Resource allocation type 2 for 'Format-1A' C-RNTI DCI 
% TS 36.213 - 7.1.6.3

if (vrbLength - 1) < floor(enb.NDLRB/2)
    RIV = enb.NDLRB*(vrbLength - 1) + vrbStart;
else
    RIV = enb.NDLRB*(enb.NDLRB - vrbLength+ 1) + (enb.NDLRB - 1 - vrbStart);
end

    
    
    
    