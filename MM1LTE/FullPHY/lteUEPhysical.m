classdef lteUEPhysical < handle
    % lteUEPhysical class to simulate lte UE
    %
    % Provide function of receiving PDSCH and PDCCH, transmitting PUCCH and
    % demultiplexing MAC PDU into MAC SDU
    %
    % Matlab code written by Andi Soekartono, MSC Telecommunication
    % Date 15-June-2015
    
    properties
        enb = struct ;                                            % eNodeB setting in UE
        cec = struct ;                                            % channel estimation settings
        ue = struct ;                                             % UE spesific settings
        transportBlock = model.lteDownlinkTransportBlock.empty ;  % transport block buffer (HARQ and soft combining buffer)
        sduBuffer = model.lteMACsdu.empty;                        % MAC SDU sink
        acKN ;                                                    % Acknowledgement register for Nth TTI
        acKN_1 ;                                                  % Acknowledgement register for (N - 1)th TTI
        channelSNR ;                                              % UE downlink channel SNR
    end
    
    methods
        %%
        function obj = lteUEPhysical(enb, ue)
            % Physical UE constructor
            %   obj = lteUEPhysical(enb, ue)
            %     enb : eNodeB parameters
            %     ue  : UE parameters
            
            % Channel estimator default settings
            obj.cec.PilotAverage = 'UserDefined';                 % Pilot averaging methods
            obj.cec.FreqWindow = 9;                               % Averaging windows in frequency domain in RE
            obj.cec.TimeWindow = 13;                              % Averaging windows in time domain in RE
            obj.cec.InterpType = 'cubic';                         % Pilot interpolation methods
            obj.cec.InterpWindow = 'Centered';                    % Interpolation window type
            obj.cec.InterpWinSize = 1;                            % Interpolation caculation size in subframe
            
            % Parameter storing and initialization
            obj.enb = enb;
            obj.ue = ue;
            obj.ue.cqi = [];
            obj.ue.cqiAge = 0;
            obj.ue.tti = 0;
        end
        
        %%
        function [] = receive(obj, waveform, varargin)
            % method to perform signal reception from eNodeB
            %   obj.receive(waveform, sduDatabase, decodingFlag)
            %       waveform : downlink transmission in time domain
            %       sduDatabase : simulation MAC SDU data base (optional to update transmission status)
            %       decodingFlag : '0' no decoding '1' perform decoding
            %           (for performance skip decoding is possible if no scheduled
            %           transmission for current user)
            
            % Time domain synchronization update when beginning of the frame (subframe 0)
            if obj.enb.NSubframe == 0
                % Matlab LTE Toolbox to find the beginning of the frame
                obj.enb.offset = lteDLFrameOffset(obj.enb, waveform.signal);
            end
            
                        
            % Apply offset to align waveform to beginning of the LTE Frame
            waveform.signal = waveform.signal(1 + obj.enb.offset:end);
            % Pad end of signal with zeros after offset alignment
            waveform.signal((size(waveform.signal, 1)+ 1) : (size(waveform.signal, 1) + obj.enb.offset)) = zeros();
            
            % Matlab LTE Toolbox to peform OFDM demodulation to received signal into resource grid
            resourceGrid = lteOFDMDemodulate(obj.enb, waveform.signal);
            
            % Peform channel estimation and equalization
            [hest, noisest] = lteDLChannelEstimate(obj.enb, obj.cec, resourceGrid);
            resourceGrid = lteEqualizeMMSE(resourceGrid, hest, noisest);
            
            %% Decode BCH MIB in every subframe 0
            if obj.enb.NSubframe == 0
                
                % Matlab LTE Toolbox to generate PBCH spesific index in resource grid
                pbchIndices = ltePBCHIndices(obj.enb);
                % Matlab LTE Toolbox to decode Physical BCH symbols into MIB bits
                [ ~, ~, nfmod4, mib, cellRefP] = ltePBCHDecode(obj.enb, resourceGrid(pbchIndices));
                
                % Update cell wide setting if correctly decoded
                
                if cellRefP ~= 0
                    obj.enb.CellRefP = cellRefP;
                    % Matlab LTE Toolbox to decode MIB bits into cell wide settings
                    obj.enb = lteMIB(mib, obj.enb);
                    % Calculating exact SFN
                    obj.enb.NFrame = obj.enb.NFrame + nfmod4;
                end
            end
            
            %% Decode CFI
            
            % Matlab LTE Toolbox to generate PCFICH spesific index in resource grid
            pcfichIndices = ltePCFICHIndices(obj.enb);
            % Matlab LTE Toolbox to decode PCFICH symbols into CFI bits
            cfiBits = ltePCFICHDecode(obj.enb, resourceGrid(pcfichIndices));
            % Matlab LTE Toolbox to decode CFI bits into CFI value
            obj.enb.CFI = lteCFIDecode(cfiBits);
            
            %% Decode PDCCH
            
            % Matlab LTE Toolbox to generate PDCCH spesific index in resource grid
            pdcchIndices = ltePDCCHIndices(obj.enb);
            % Matlab LTE Toolbox to decode PCFICH symbols into CFI bits
            [dciBitsOri, ~] = ltePDCCHDecode(obj.enb, resourceGrid(pdcchIndices));
            
            %% Decode DCI to get PPDSCH mapping in resource grid
            
            % Matlab LTE Toolbox to perform PDCCH blind search for DCI decoding. The
            % LTE System Toolbox provides full blind search of the PDCCH to find
            % any DCI messages with a specified RNTI
            
            [dciFull, ~] = ltePDCCHSearch(obj.enb, obj.ue, dciBitsOri);
            
            % Find appropriate DCI information
            if ~isempty(dciFull)
                for i = 1:size(dciFull, 2)
                    if strcmp(dciFull{i}.DCIFormat, 'Format1A')
                        dci = dciFull{i};
                        break
                    end
                end
            else
                obj.ue.RNTI;
            end
            
            %% Decode PDSCH and DSCH data
            if exist('dci', 'var');
                
                
                % Convert Modulation and Coding Scheme (MCS) value into
                % modulation type and transport block index
                [modulation, itbs] = calculator.mcs2configuration(dci.ModCoding);
                
                % Set general PDSCH parameters
                pdsch.RNTI = obj.ue.RNTI;                                   % Radio network temporary identifier (RNTI) value (16 bits)
                pdsch.PRBSet = lteDCIResourceAllocation(obj.enb, dci);      % Physical resource block allocations: decoded from DCI information
                pdsch.NLayers = obj.enb.CellRefP;                           % Number transmission layer
                pdsch.RV = dci.RV;                                          % Redundancy version indicators used for HARQ soft combining
                pdsch.Modulation = {modulation};                            % Modulation type used by PDSCH
                pdsch.NTurboDecIts = 5;                                     % Number of turbo decoder iteration cycles
                pdsch.CSIMode = 'PUCCH 1-0';                                % CSI reporting mode: '1-0' wideband CQI measurement is used
                pdsch.Rho = 0;                                              % PDSCH resource element power allocation, in dB
                if (obj.enb.CellRefP == 1)                                  % LTE transmission scheme
                    pdsch.TxScheme = 'Port0';                               % SISO
                else
                    pdsch.TxScheme = 'TxDiversity';                         % Transmit diversity MIMO
                end
                
                
                % Matlab LTE Toolbox to generate PDSCH indices
                [pdschIndices, ~] = ltePDSCHIndices(obj.enb, pdsch, pdsch.PRBSet);
                
                % Matlab LTE Toolbox to decode PDSCH
                dlsch = ltePDSCHDecode(obj.enb, pdsch,  resourceGrid(pdschIndices));
                
                % Matlab LTE Toolbox to calculate transport block size from
                % transport block index
                tbs = lteTBS(size(pdsch.PRBSet, 1), itbs);
                
                
                % Decode DLSCH
                if pdsch.RV == 0                        % If new HARQ process do the following
                    % create and store new HARQ buffer
                    tbIdx = length(obj.transportBlock) + 1;
                    obj.transportBlock(tbIdx) = model.lteDownlinkTransportBlock(obj);
                    obj.transportBlock(tbIdx).build(obj.enb, dci.ModCoding, [int32(pdsch.PRBSet(1)) int32(length(pdsch.PRBSet))], []);
                    
                    % set the new HARQ buffer as current transport block
                    tb = obj.transportBlock(tbIdx);
                    tb.setHARQNo(dci.HARQNo);
                    tb.tbs = tbs;
                    
                    % Matlab LTE Toolbox to decode DL-SCH transport channel
                    % into data bit, crc and soft state
                    [dlschBit, crcDLSCH, state] = lteDLSCHDecode(obj.enb, pdsch, tbs, dlsch);
                else                                    % If HARQ retransmission do the following
                    % find and load corresponding HARQ process in buffer to current transport block
                    tb = findobj(obj.transportBlock, 'HARQNo', dci.HARQNo);
                    
                    if isempty(tb)
                        % if not found (it is possible because PUCCH
                        % transmission can be error, an ACK can be decoded as NACK by eNodeB)
                        % discard received transport block by setting crc = 0
                        crcDLSCH = 0;
                    else
                        % if previous HARQ state found on buffer
                        if length(tb) > 1
                            % if duplicate process id found on buffer (it is possible because PUCCH
                            % transmission can be error, a NACK can be decoded as ACK by eNodeB)
                            % drop older HARQ process, the correspond MAC SDU is consireded as dropped or transmission failure
                            obj.transportBlock( obj.transportBlock == tb(1)) = [];
                            tb = tb(2);
                        end
                        % Matlab LTE Toolbox to decode DL-SCH transport channel
                        % combined with stored state into data bit, crc and soft state
                        [dlschBit, crcDLSCH, state] = lteDLSCHDecode(obj.enb, pdsch, tb.tbs, dlsch, tb.state);
                    end
                end
                
                if ~isempty(tb)
                    if crcDLSCH == 0        % if decoding successful
                        
                        % delete HARQ process from buffer
                        obj.transportBlock( obj.transportBlock == tb) = [];
                        % update MAC SDU status
                                                
                    elseif ~isempty(tb)     % if decoding unsuccessful store state
                        tb.state = state;
                    end
                    % store crc value
                    tb.crc = crcDLSCH;
                end
                
                % Matlab LTE Toolbox to calculate CQI value for current downlink tranmsission
                [obj.ue.cqi, ~] = calculator.lteCQISelect(obj.enb, pdsch, hest, noisest);
                % update acknowledgement register
                obj.acKN_1 = obj.acKN;
                obj.acKN = (crcDLSCH > 0);
            else
                % update acknowledgement register
                obj.acKN_1 = obj.acKN;
                obj.acKN = [];
            end
            
        end
        
        %%
        function waveform = transmit(obj)
            % method to perform signal transmission from UE
            %   waveform = obj.transmit
            %       waveform : uplink transmission in time domain
            
            % update UE subframe number
            obj.ue.NSubframe = obj.enb.NSubframe;
            
            if obj.ue.cqiAge == 4
                obj.acKN_1 = 0;
            end
            
            if ~isempty(obj.acKN_1) && ~isempty(obj.ue.cqi)
                % if there are acknowledgement need to be sent do the following
                
                % Matlab LTE Toolbox to generate uplink transmit grid
                resourceGrid = lteULResourceGrid(obj.ue);
                
                % !!!!!!!!!! offset Matlab CQI calculation by two
                cqi = obj.ue.cqi - 2;
                if cqi < 1
                    cqi = 1;
                end
                
                % Matlab LTE Toolbox to encode 4bit CQI value into 20 bit code word
                codedcqi = lteUCIEncode(de2bi(cqi, 4));
                
                % Matlab LTE Toolbox to generate PUCCH 2 and its DRS 
                % format 2 supports CQI and 1 or 2 bit of ACK at once
                pucch2Sym = ltePUCCH2(obj.ue, obj.ue.pucch, codedcqi);
                pucch2DRSSym = ltePUCCH2DRS(obj.ue, obj.ue.pucch, obj.acKN_1);
                
                % Matlab LTE Toolbox to generate indices for PUCCH 2 and its DRS
                pucch2Indices = ltePUCCH2Indices(obj.ue, obj.ue.pucch);
                pucch2DRSIndices = ltePUCCH2DRSIndices(obj.ue, obj.ue.pucch);
                
                % Map PUCCH 2 and PUCCH 2 DRS to the resource grid
                resourceGrid(pucch2Indices) = pucch2Sym;
                resourceGrid(pucch2DRSIndices) = pucch2DRSSym;
                
                % Matlab LTE Toolbox to peform SC-FDMA modulation (uplink)
                [waveform.signal, waveform.info] = lteSCFDMAModulate(obj.ue, resourceGrid);
                
                % reset CQI feedback age
                obj.ue.cqiAge = 0;
            else
                % if no acknoledgement, mute transmission
                
                % Matlab LTE Toolbox to generate uplink transmission
                % information
                waveform.info = lteSCFDMAInfo(obj.ue);
                % Send empty signal
                waveform.signal = zeros(waveform.info.SamplingRate / 1000,1);
            end
            
        end
        
        %%
        function [] = tick(obj)
            % method to  update eNodeB SFN and Subframe number
            %   obj.tick
            %
            
            % update CQI feedback age and subframe - frame number
            obj.ue.cqiAge = obj.ue.cqiAge + 1;
            obj.ue.tti = obj.ue.tti + 1;
            obj.enb.NSubframe = obj.enb.NSubframe + 1;
            if obj.enb.NSubframe == 10
                obj.enb.NSubframe = 0;
                obj.enb.NFrame = obj.enb.NFrame + 1;
            end
        end
    end
    
end

