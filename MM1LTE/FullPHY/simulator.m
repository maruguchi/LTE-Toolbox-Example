classdef simulator < handle
    %SIMULATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        enbPHY = lteENBPhysical.empty;
        UE = model.lteUE.empty;
        uePHY = lteUEPhysical.empty;
        buffer = model.lteMACsdu.empty;
        transChannel = model.lteTransmissionChannel.empty;
        simTime = [];
        ttiTime = [];
        packetArrivalTime = [];
        currentTime = []
        tau = [];
        packetStat = [];
        feedback;
    end
    
    methods
        function obj = simulator(simulationTime,interarrivalTime)
            % simulationTime and interarrival time in seconds
            % initialize and store parameter
            obj.simTime = simulationTime * 1000; % convert to ms
            obj.ttiTime = 0;
            obj.currentTime = 0;
            obj.tau = interarrivalTime*1000; % convert to ms
            obj.packetArrivalTime = exprnd(obj.tau);
            obj.enbPHY = lteENBPhysical;
            obj.UE = model.lteUE(obj.enbPHY.enb, 100, 1);
            obj.transChannel = model.lteTransmissionChannel;
            obj.uePHY = lteUEPhysical(obj.enbPHY.enb, obj.UE.ue);
            obj.feedback{1} = [];
            obj.feedback{2} = [];
        end
        
        function [] = run(obj)
            while obj.currentTime < obj.simTime
                % calculate next packet arrival
                
                if obj.packetArrivalTime > obj.ttiTime
                    % if event is TTI, do lte PHY layer transmission
                    disp('========================================')
                    disp(['time ',num2str(double(obj.ttiTime)*0.001),' s'])
                    
                    [tb, ue] = obj.schedule;
                    
                    % insert scheduled ue monitoring and transport block
                    obj.enbPHY.insertUE(ue);
                    obj.enbPHY.insertTransportBlock(tb);
                    
                    % downlink transmission
                    downlinkSignal = obj.enbPHY.transmit();
                    
                    % UE receive
                    obj.uePHY.receive(obj.transChannel.perform(downlinkSignal, obj.enbPHY.enb));
                    
                    % uplink transmission
                    uplinkSignal = obj.uePHY.transmit;
                    
                    % ENB receiver
                    obj.packetStat = obj.enbPHY.receive(obj.transChannel.perform(uplinkSignal,obj.enbPHY.enb),obj.packetStat);
                    
                    % update PHY enb TTI clock
                    obj.enbPHY.tick;
                    
                    % update UE TTI clock
                    obj.uePHY.tick;
                    obj.currentTime = obj.ttiTime;
                    obj.ttiTime = obj.ttiTime + 1;
                else
                    sdu = model.lteMACsdu(obj.UE.rnti, randi([0 1],128,1));
                    sdu.arrival_time = obj.packetArrivalTime;
                    obj.currentTime = obj.packetArrivalTime;
                    obj.buffer(length(obj.buffer) + 1) = sdu;
                    packetTau = exprnd(obj.tau);
                    obj.packetArrivalTime = obj.packetArrivalTime  + packetTau;
                    
                end
               
                
            end
            
        end
        
        function [tb, ueMon] = schedule(obj)
            % initialization
            % create empty list of transport block
            tb = model.lteDownlinkTransportBlock.empty;
            
            % cycle feedback schedule
            % this because reporting of nth TTI is done at n+1th TTI at
            % minimum
            obj.feedback{2} = obj.feedback{1};
            obj.feedback{1} = [];
            ueMon = obj.feedback{2};
            
            % no sending data in subframe 0 and 5 because SSS and PSS will invalidate code rate
            if mod(obj.enbPHY.enb.tti,5) == 0
                return
            end
            % resource block mapping
            rbAvailable = zeros(obj.enbPHY.enb.NDLRB,1);
            
            % If CQI = 0 no transmission
            if obj.UE.cqi ~= 0
                
                % check H-ARQ cache for current UE
                tbCandidate = obj.UE.getRetransmissionBlock;
                if ~isempty(tbCandidate)
                    % reset rv loop in this version no packet is
                    % dropped
                    if tbCandidate(1).rv == 3
                        tbCandidate(1).setRV(1);
                    else
                        % increment RV for retransmission
                        tbCandidate(1).setRV(tbCandidate(1).rv + 1);
                    end
                    % reset crc acknowledgement
                    tbCandidate(1).crc = [];
                    % track retransmission number
                    tbCandidate(1).retransmissionNo = tbCandidate(1).retransmissionNo + 1;
                    % store candidate to transport block
                    tb(length(tb)+1) = tbCandidate(1);
                    % update feedback scheduler
                    obj.feedback{1}.ue = obj.UE;
                    obj.feedback{1}.ackHARQNo = tbCandidate(1).HARQNo;
                    
                else
                    if ~isempty(obj.UE.getHARQno)
                        sentSDUlength = 0 ;                                                         % total length SDU in Bits
                        sentSDUlist = {};
                        % calculate PDU length
                        % this iteration will try to include sdu one by
                        % one that fit into available resource bloc
                        for i = 1:length(obj.buffer)
                            sentSDUlist{i} = obj.buffer(i).data; %#ok<AGROW>
                            % add sdu
                            sentSDUlength = sentSDUlength + length(sentSDUlist{i}) + 16;
                            % check whether availabel resource block fit
                            [ mcsAlloc, ~, ~, ~ ] = ...
                                calculator.rateAdaptation( obj.enbPHY.enb, rbAvailable, obj.UE.cqi, (sentSDUlength + 8)/8);
                            if isempty(mcsAlloc)
                                % if not fit return to previous
                                % iteration state and stop
                                
                                sentSDUlength = sentSDUlength - (length(sentSDUlist{i}) + 16);
                                sentSDUlist(i) = []; %#ok<AGROW>
                                break
                            end
                        end
                        
                        % construct ne transport block is there are sdu
                        % can be sent
                        if ~isempty(sentSDUlist)
                            % calculate resource allocation
                            [ mcsAlloc, tbsAlloc, rbAlloc, ~] = ...
                                calculator.rateAdaptation( obj.enbPHY.enb, rbAvailable,  obj.UE.cqi, (sentSDUlength+8)/8);
                            
                            % PDU multiplexing
                            pdu = calculator.macMux( tbsAlloc, sentSDUlist );
                            % transport block generation
                            tbCandidate(1) = model.lteDownlinkTransportBlock(obj.UE);
                            tbCandidate(1).build(obj.enbPHY.enb,  mcsAlloc, rbAlloc, pdu);
                            tbCandidate(1).createdTTI = obj.enbPHY.enb.tti;
                            % set HARQ process ID and store to UE HARQ
                            % register
                            tbCandidate(1).setHARQNo(obj.UE.getHARQno);
                            obj.UE.addHARQProcess(tbCandidate(1));
                            % update to current transmission transport
                            % block
                            tb(length(tb)+1) = tbCandidate(1);
                            
                            % update feedback scheduler
                            obj.feedback{1}.ue = obj.UE;
                            obj.feedback{1}.ackHARQNo = tbCandidate(1).HARQNo;
                            
                            % clear sent sdu from scheduler sdu buffer
                            for j = length(sentSDUlist):-1:1
                                obj.buffer(j).status = 'sent';
                                obj.buffer(j).sent_time = obj.enbPHY.enb.NFrame * 10 + obj.enbPHY.enb.NSubframe * 1;
                                tbCandidate(1).sdu(length( tbCandidate(1).sdu) + 1) = obj.buffer(j);
                                %ueCandidate(1).sentSDU(length(ueCandidate(1).sentSDU) + 1) = obj.buffer(j);
                                obj.buffer(j) = [];
                            end
                        end
                        
                        
                    end
                end
                
            end
        end
        
    end
    
end

