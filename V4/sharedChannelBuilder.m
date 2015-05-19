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
                
                % HARQ uplink feedback parameter
                
                ue.NULRB = enb.NDLRB;                    % Number Uplink Resource Block similar to downlink one
                ue.CyclicPrefixUL = enb.CyclicPrefix;    % Uplink cyclic prefix similar to downlink
                ue.Hopping = 'Off';                      % No frequency hopping
                ue.NCellID = enb.NCellID;                % Cell id simila to downlink Physical Cell ID
                ue.Shortened = 0;                        % No SRS transmission 
                ue.NTxAnts = 1;                          % Number of UE antenna (SISO system) 
                ue.PUCCHResourceIndex = 0;               % UE spesific ResourceIdx
                
                % Set the size of resources allocated to PUCCH format 2. This affects the
                % location of PUCCH 1 transmission
                pucch.ResourceSize = 0;
                % Delta shift PUCCH parameter as specified in TS36.104 Appendix A9 [ <#8 1> ]
                pucch.DeltaShift = 2;
                % Number of cyclic shifts used for PUCCH format 1 in resource blocks with a
                % mixture of formats 1 and 2. This is the N1cs parameter as specified in
                % TS36.104 Appendix A9
                pucch.CyclicShifts = 0;

                % Data Generation
                data = randi([0 1], tbs, 1);                                  % random bit generation
                
                
                % Output mapping
                sharedChannel.pdsch = pdsch;
                sharedChannel.dci = dci;
                sharedChannel.pdcch = pdcch;
                sharedChannel.data = data;
                sharedChannel.dataACK = 0;
                sharedChannel.ue = ue;
                sharedChannel.pucch = pucch;
                
                % user state
                userChannel.enb = [];
                userChannel.pdcch.RNTI = rnti;
                userChannel.pdsch.RNTI = rnti;
                userChannel.data = [];
                userChannel.dataCRC = [];
                userChannel.state = [];
                
                userChannel.ue = struct;                           % UE parameter placeholder
                userChannel.ue.PUCCHResourceIndex = 0;             % UE spesific ResourceIdx
                userChannel.pucch = pucch;
 
                
                
                
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

    
    
    
    