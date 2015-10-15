classdef lteENBPhysical < handle
    % lteENBPhysical class to simulate lte eNodeB PHY layer
    %
    % Provide function of transmitting PDSCH and PDCCH, as well as receiving PUCCH
    %    - downlink transport block data transmission
    %    - decoding HARQ process ACK and channel condition CQI   
    %
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 15-June-2015  
    
       
    properties
        enb = struct;                                           % eNodeB parameters
        cec = struct;                                           % uplink channel estimation parameter
        ueMonitored;                                            % uplink feedback transmission register
        transportBlock = model.lteDownlinkTransportBlock.empty; % downlink transport block register
    end
    
    
    methods
        
        %%
        function obj = lteENBPhysical()
            % Physical ENB constructor
            %   obj = lteUEPhysical()
            %    
            
            
            % e-NodeB default settings
            % Resouce grid creation
            
            obj.enb.NDLRB = 6;                 % Number of downlink physical resouce block in the cell
            obj.enb.CyclicPrefix = 'normal';    % Length of downlink CyclicPrefix: 'normal' or 'extended'
            obj.enb.CellRefP = 1;               % Number of antenna port with CRS signal: 1,2 or 4
            
            % Physical signal insertion (PSS, SSS and CRS)
            obj.enb.DuplexMode = 'FDD';         % LTE Duplex mode: 'FDD' (frame type 1) or 'TDD' (frame type 2)
            obj.enb.NSubframe = 0;              % Resource grid subframe number relative in LTE frame
            obj.enb.NCellID = 0;                % Physical cell ID correspond to PSS, SSS and CRS sequence generation
            
            % Physical control channel
            
            obj.enb.Ng = 'Sixth';               % Ng  HICH group multiplier: 'Sixth' | 'Half' | 'One' | 'Two'
            obj.enb.NFrame = 0;                 % System Frame number
            obj.enb.PHICHDuration = 'Normal';   % PHICH duration (accord to CP): 'Normal' | 'Extended'
            obj.enb.CFI = 2;                    % Control format indicator (CFI) value: 1,2 or 3
            
            % TTI clock
            obj.enb.tti = 0;                    % eNodeB TTI clock counter
            
                        
            % channel estimator settings
            obj.cec.PilotAverage = 'UserDefined';     % Pilot averaging methods
            obj.cec.FreqWindow = 9;                   % Averaging windows in frequency domain in RE
            obj.cec.TimeWindow = 9;                   % Averaging windows in time domain in RE
            obj.cec.InterpType = 'cubic';             % Pilot interpolation methods
            obj.cec.InterpWinSize = 1;                % Interpolation caculation size in subframe
            obj.cec.InterpWindow = 'Centered';        % Interpolation window type
            
        end
        
        
        %%
        function [] = insertUE(obj, UE)
            % method to add UE list need to be monitored
            %   obj.insertUE(UE)
            %       UE : array of lteUE object
            %       
            
            % store monitored UE list
            obj.ueMonitored = UE;
            
        end
        
        %%
        function [] = insertTransportBlock(obj, transportBlock)
            % method to add transport block to be transmitted
            %   obj.insertTransportBlock(transportBlock)
            %       transportBlock : array of lteDownlinkTransportBlock object
            %       
            
            % store transportBlock list
            obj.transportBlock = transportBlock;
            
        end
        
        %%
        function waveform = transmit(obj)
            % method to perform signal transmission from ENB to UE
            %   waveform = obj.transmit
            %       waveform : downlink transmission signal in time domain
            %            
            
            %% Creating empty downlink resource grid
            
            % Matlab LTE Toolbox to generate resource grid
            resourceGrid = lteDLResourceGrid(obj.enb);
            
            
            
            %% Inserting physical signal into resource grid
            
            % Matlab LTE Toolbox to generate PSS spesific index in resource grid
            pssIndices = ltePSSIndices(obj.enb);
            % Matlab LTE Toolbox to generate PSS signal for each resource element
            pssSymbols = ltePSS(obj.enb);
            
            % Insert PSS symbol into resource grid according to its indices
            resourceGrid(pssIndices) = pssSymbols;
            
            
            % Matlab LTE Toolbox to generate SSS spesific index in resource grid
            sssIndices = lteSSSIndices(obj.enb);
            % Matlab LTE Toolbox to generate SSS symbol for each resource element
            sssSymbols = lteSSS(obj.enb);
            
            % Insert SSS symbol into resource grid according to its indices
            resourceGrid(sssIndices) = sssSymbols;
            
            % Matlab LTE Toolbox to generate SSS spesific index in resource grid
            crsIndices = lteCellRSIndices(obj.enb);
            % Matlab LTE Toolbox to generate SSS symbol for each resource element
            crsSymbols = lteCellRS(obj.enb);
            
            % Insert CRS symbol into resource grid according to its indices
            resourceGrid(crsIndices) = crsSymbols;
            
            
            %% Inserting physical channel into resource grid
            
            
            %% Inserting PBCH with MIB (Master Information Block) to grid
            % scheduled every subframe 0 for FDD mode
            
            if mod(obj.enb.NSubframe,10) == 0
                % MIB to PBCH insertion
                % Matlab LTE Toolbox to generate 24-bit-long MIB message
                % containing cell-wide setting specified in enb
                mib = lteMIB(obj.enb);
                % Matlab LTE Toolbox to generate BCH transport channel coded bits containing MIB bits
                bchCoded = lteBCH(obj.enb, mib);
                % Matlab LTE Toolbox to generate Physical BCH symbols
                pbchSymbols = ltePBCH(obj.enb, bchCoded);
                % Matlab LTE Toolbox to generate PBCH spesific index in resource grid
                pbchIndices = ltePBCHIndices(obj.enb);
                
                % PBCH symbols 40 ms periodicity spread
                % Each subframe 0 containing 1/4 bchCoded
                PBCHInd = mod((obj.enb.NSubframe + 1 + obj.enb.NFrame*10), 40);
                pbchSymStart = 1 + floor(PBCHInd / 10) * length(pbchIndices);
                pbchSymEnd = ceil(PBCHInd / 10) * length(pbchIndices);
                % map PBCH to grid
                resourceGrid(pbchIndices) = pbchSymbols(pbchSymStart:pbchSymEnd);
            end
            
            %% Inserting Control Format Indicator (CFI) and PCFICH
            % Determine number of symbols used by L1/L2 control information every slot.
            
            % Matlab LTE Toolbox to generate CFI Channel Coding
            cfiBits = lteCFI(obj.enb);
            
            % Matlab LTE Toolbox to generate PCFICH symbol for corresponding CFI bits
            pcfichSymbols = ltePCFICH(obj.enb, cfiBits);
            
            % Matlab LTE Toolbox to generate PCFICH spesific index in resource grid
            pcfichIndices = ltePCFICHIndices(obj.enb);
            
            % Map PCFICH symbols to resource grid
            resourceGrid(pcfichIndices) = pcfichSymbols;
            
            %% Inserting DCCH and DTCH data
            % Dedicated data for each spesific RNTI
            
            % Channel insertion for each user
            
            % PDCCH space initialization
            pdcchInfo = ltePDCCHInfo(obj.enb);                                  % Get the total resources for PDCCH
            selectedCandidate = [];                                             % track used PDCCH space
            pdcchBits = -1 * ones(pdcchInfo.MTot, 1);                           % Initialized with -1
            
            % Display information if no transport block transmission
            if isempty (obj.transportBlock)
                disp('no schedulled downlink transmission');
            end
            
            for  i = 1 : length(obj.transportBlock)
                
                %% PDSCH Generation
                
                % Display information for transport block transmission
                disp(['sending process ID ', num2str(obj.transportBlock(i).dci.HARQNo), ' with ', num2str(length(obj.transportBlock(i).data)), ...
                    ' bits to UE RNTI ', num2str(obj.transportBlock(i).pdsch.RNTI)]);
                
                % Matlab LTE Toolbox to generate PDSCH spesific index in resource grid
                [pdschIndices, pdschInfo] = ltePDSCHIndices(obj.enb, obj.transportBlock(i).pdsch, obj.transportBlock(i).pdsch.PRBSet, {'1based'});
                                
                % Matlab LTE Toolbox to generate DL-SCH transport channel coded bits containing pdu data bits
                codedTrBlock = lteDLSCH(obj.enb, obj.transportBlock(i).pdsch, pdschInfo.G, obj.transportBlock(i).data);
                
                % Matlab LTE Toolbox to generate PDSCH symbols
                pdschSymbols = ltePDSCH(obj.enb, obj.transportBlock(i).pdsch, codedTrBlock);
                
                % Map PDSCH symbols onto resource grid
                resourceGrid(pdschIndices) = pdschSymbols;
                                
                %% DCI message generation
                
                % Matlab LTE Toolbox to generate DCI message bit from DCI
                % allocation
                [~, dciMessageBits] = lteDCI(obj.enb, obj.transportBlock(i).dci);
                                
                % Matlab LTE Toolbox to generate DCI transport channel coded 
                % bits containing DCI message bits
                codedDciBits = lteDCIEncode(obj.transportBlock(i).pdcch, dciMessageBits);
                
                %% PDCCH Generation
                
                % Matlab LTE Toolbox to determine PDCCH space that can be
                % used
                candidates = ltePDCCHSpace(obj.enb, obj.transportBlock(i).pdcch, {'bits','1based'});
                
                % Find free PDCCH space candidates
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
            
            % Matlab LTE Toolbox to generate PDCCH symbols
            pdcchSymbols = ltePDCCH(obj.enb, pdcchBits);
            
            % Matlab LTE Toolbox to generate PDCCH spesific index in resource grid
            pdcchIndices = ltePDCCHIndices(obj.enb, {'1based'});
            
            % Map PDCCH symbols onto resource grid
            resourceGrid(pdcchIndices) = pdcchSymbols;
            
            % Matlab LTE Toolbox to perform OFDM Modulation (downlink)
            [waveform.signal , waveform.info] = lteOFDMModulate(obj.enb,resourceGrid);
            
        end
        
        %%
        function [packetStat] = receive(obj, waveform, packetStat)
            % method to perform signal reception from UE
            %   obj.receive(waveform)
            %       waveform : uplink transmission in time domain
            %
            
            disp(' ');
            
            % Perform signal reception from each scheduled UE reporting
            for i = 1: length (obj.ueMonitored)
                
                % sync uplink subframe number
                obj.ueMonitored(i).ue.ue.NSubframe = obj.enb.NSubframe;
                % try to decode HARQ ACK from spesific UE
                % it is possible having errorenous ACK due to channel
                % condition
                try
                    % Matlab LTE Toolbox to perform PUCCH format 2 synchronization and ACK
                    % decoding
                    [offset, rxACK] = lteULFrameOffsetPUCCH2(obj.ueMonitored(i).ue.ue, obj.ueMonitored(i).ue.ue.pucch, waveform.signal,1);
                catch
                    % if decoding failed return negative ACK 
                    offset = 0;
                    rxACK = 1;
                end
                
                % bound synchronization offset to 25 samples
                if (offset<25)
                    offsetused = offset;
                else
                    offsetused = 0;
                end
                
                % Apply offset to align waveform to beginning of the LTE Frame
                waveform.signal = waveform.signal(1 + offsetused:end);
                % Pad end of signal with zeros after offset alignment
                waveform.signal((size(waveform.signal,1) + 1):(size(waveform.signal,1) + offsetused)) = zeros();
                
                % Matlab LTE Toolbox to perform SCFDMA Demodulation
                resourceGrid = lteSCFDMADemodulate(obj.ueMonitored(i).ue.ue, waveform.signal);
                
                % Matlab LTE Toolbox to perform PUCCH2 channel estimation
                [H, n0] = lteULChannelEstimatePUCCH2(obj.ueMonitored(i).ue.ue, obj.ueMonitored(i).ue.ue.pucch, obj.cec, resourceGrid, rxACK);
                
                % Matlab LTE Toolbox to generate PUCCH2 spesific index in resource grid
                pucch2Indices = ltePUCCH2Indices(obj.ueMonitored(i).ue.ue, obj.ueMonitored(i).ue.ue.pucch);
                
                % Matlab LTE Toolbox to perform PUCCH2 MMSE equalization
                warning('off','MATLAB:singularMatrix');                 % supress warning messages
                resourceGrid = lteEqualizeMMSE(resourceGrid, H, n0);
                
                % Matlab LTE Toolbox to perform PUCCH2 decoding
                rxCQIbits = ltePUCCH2Decode(obj.ueMonitored(i).ue.ue, obj.ueMonitored(i).ue.ue.pucch, resourceGrid(pucch2Indices));
                
                % CQI bit decoding (4 bits) updated to UE database
                try
                    tb = findobj(obj.ueMonitored(i).ue.harqBuffer,'HARQNo',obj.ueMonitored(i).ackHARQNo);
                    if ~isempty(tb)
                        tb.crc = rxACK;
                    end
                    
                    % Matlab LTE Toolbox to extract CQI value from CSI
                    % codeword
                    cqi = bi2de(lteUCIDecode(rxCQIbits, 4).');
                    
                    % Update CQI value for corresponding UE
                    if length(cqi) == 1
                        cqi = round((double(cqi) + double(obj.ueMonitored(i).ue.cqi)) / 2);
                        obj.ueMonitored(i).ue.cqi = cqi;
                    end
                    
                    % If positive HARQ ACK reported update and release HARQ
                    % process register for this UE
                    % Display information for monitored UE status
                    if rxACK == 0
                        disp(['receive positive acknowledgement from process ID ', num2str(obj.ueMonitored(i).ackHARQNo), ' RNTI ',...
                            num2str(obj.ueMonitored(i).ue.rnti),' and CQI value of ',num2str(cqi)]);
                        if ~isempty(tb)
                            for j = 1:length(tb.sdu)
                                tb.sdu(j).delayENB_time = double(obj.enb.tti + 1) - tb.sdu(j).arrival_time;
                                packetStat(size(packetStat,1) + 1,:) = [tb.sdu(j).arrival_time tb.sdu(j).sent_time tb.sdu(j).delayENB_time tb.retransmissionNo];
                            end
                            obj.ueMonitored(i).ue.harqBuffer(obj.ueMonitored(i).ue.harqBuffer == tb) = [];
                        end
                    else
                        disp(['receive negative acknowledgement from process ID ', num2str(obj.ueMonitored(i).ackHARQNo), ' RNTI ',...
                            num2str(obj.ueMonitored(i).ue.rnti),' and CQI value of ',num2str(cqi)]);
                    end
                catch
                    % If there is error in decoding CQI and ACK, report
                    % error in reception                    
                    disp(['fail to receive acknowledgement from process ID ', num2str(obj.ueMonitored(i).ackHARQNo), ' RNTI ',...
                        num2str(obj.ueMonitored(i).ue.rnti)]);
                end
            end
            
            % Display information if no monitored UE
            if isempty (obj.ueMonitored)
                disp('no schedulled uplink feedback');
            end
        end
        
        %%
        function [] = tick(obj)
            % method to  update eNodeB SFN and Subframe number
            %   obj.tick
            %
            
            % update subframe - frame number
            obj.enb.NSubframe = obj.enb.NSubframe + 1;
            obj.enb.tti = obj.enb.tti + 1;
            if obj.enb.NSubframe == 10
                obj.enb.NSubframe = 0;
                obj.enb.NFrame = obj.enb.NFrame + 1;
            end
        end
    end
    
end

