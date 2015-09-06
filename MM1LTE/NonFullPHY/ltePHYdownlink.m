classdef ltePHYdownlink < handle
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
        ueMonitored;                                            % uplink feedback transmission register
        transportBlock = model.lteDownlinkTransportBlock.empty; % downlink transport block register
        cqiModel = calculator.lteCQIemu.empty;
        ackModel = calculator.lteACKemu.empty;
        snr ;
    end
    
    
    methods
        
        %%
        function obj = ltePHYdownlink(snr)
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
            
            obj.snr = snr;
            obj.cqiModel = calculator.lteCQIemu(snr);
            obj.ackModel = calculator.lteACKemu;
        end
        
        
        %%
        function [] = insertData(obj, UE, transportBlock)
            % method to add UE list need to be monitored
            %   obj.insertUE(UE)
            %       UE : array of lteUE object
            %       
            
            % store monitored UE list
            %       transportBlock : array of lteDownlinkTransportBlock object
            %       
            
            % store transportBlock list
            obj.transportBlock = transportBlock;
            obj.ueMonitored = UE;
            
        end
        
        %%
        function [packetStat] = performTransmission(obj, packetStat)
            
            % Display information if no transport block transmission
            if isempty (obj.transportBlock)
                disp('no schedulled downlink transmission');
            end
            
            for  i = 1 : length(obj.transportBlock)
                
                %% PDSCH Generation
                
                % Display information for transport block transmission
                disp(['sending process ID ', num2str(obj.transportBlock(i).dci.HARQNo), ' with ', num2str(length(obj.transportBlock(i).data)), ...
                    ' bits to UE RNTI ', num2str(obj.transportBlock(i).pdsch.RNTI)]);
                
            end
                        
            disp(' ');
            
            % Perform signal reception from each scheduled UE reporting
            for i = 1: length (obj.ueMonitored)
                
                % CQI bit decoding (4 bits) updated to UE database
                try
                    tb = findobj(obj.ueMonitored(i).ue.harqBuffer,'HARQNo',obj.ueMonitored(i).ackHARQNo);
                    if ~isempty(tb)
                        tb.crc = obj.ackModel.getACK(tb.dci.ModCoding,obj.snr) ;
                    end
                    cqi = obj.cqiModel.getCQI;
                    obj.ueMonitored(i).ue.cqi = cqi;
                    
                    % If positive HARQ ACK reported update and release HARQ
                    % process register for this UE
                    % Display information for monitored UE status
                    if tb.crc  == 0
                        disp(['receive positive acknowledgement from process ID ', num2str(obj.ueMonitored(i).ackHARQNo), ' RNTI ',...
                            num2str(obj.ueMonitored(i).ue.rnti),' and CQI value of ',num2str(cqi)]);
                        if ~isempty(tb)
                            for j = 1:length(tb.sdu)
                                tb.sdu(j).delayENB_time = double(obj.enb.tti + 1) - tb.sdu(j).arrival_time;
                                packetStat(size(packetStat,1) + 1,:) = [tb.sdu(j).arrival_time tb.sdu(j).sent_time tb.sdu(j).delayENB_time];
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

