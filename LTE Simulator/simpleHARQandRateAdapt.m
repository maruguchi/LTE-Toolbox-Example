enbPHY = lteENBPhysical;

ueDB= model.lteUE(enbPHY.enb, 100, 1);

% generate physical UE

uePHY = lteUEPhysical(enbPHY.enb, ueDB.ue);


% generate sdu packet

packetNo = 2;

% monitored UE

n = [];
n_1 = [];

% lte channel

channel = model.lteTransmissionChannel;

for i = 1:packetNo
    sdu = model.lteMACsdu(ueDB.rnti, randi([0 1],1000,1));
    sdu.arrival_time = 0;
    % tracing sdu
    sduList(i) = sdu;
    % put in buffer
    sduBuffer(i) = sdu;
end


while ~isempty(sduBuffer)
    n_1 = n;
    % resource block mapping
    rbAvailable = zeros(enbPHY.enb.NDLRB,1);
    % Reset SDU list to sent
    sentSDU = [];
    
    % get retransmission transport block from HARQ
    transportBlock = ueDB.getRetransmissionBlock;
    
    if ~isempty(transportBlock)
        
        % reset rv loop in this version no packet is
        % dropped
        if transportBlock(1).rv == 3
            transportBlock(1).setRV(1);
        else
            % increment RV for retransmission
            transportBlock(1).setRV(transportBlock(1).rv + 1);
        end
        % reset crc acknowledgement
        transportBlock(1).crc = [];
        % track retransmission number
        transportBlock(1).retransmissionNo = transportBlock(1).retransmissionNo + 1;
        
        % update feedback scheduler
        n.ue = ueDB;
        n.ackHARQNo = transportBlock.HARQNo;
        
    else
        sduDataLength = 0 ;                                                         % total length SDU in Bits
        % calculate PDU length
        % this iteration will try to include sdu one by
        % one that fit into available resource bloc
        for i = 1:length(sduBuffer)
            sentSDU{i} = sduBuffer(i).data;
            % add sdu
            sduDataLength = sduDataLength + length(sduBuffer(i).data) + 16;
            % check whether availabel resource block fit
            [ mcsAlloc, ~, ~, ~ ] = ...
                calculator.rateAdaptation( enbPHY.enb, rbAvailable, ueDB.cqi, (sduDataLength + 8)/8);
            if isempty(mcsAlloc)
                % if not fit return to previous
                % iteration state and stop
                sentSDU(i) = [];
                sduDataLength = sduDataLength - ( length(sduBuffer(i).data) + 16);
                break
            end
        end
        
        % construct ne transport block is there are sdu
        % can be sent
        if ~isempty(sentSDU)
            % calculate resource allocation
            [ mcsAlloc, tbsAlloc, rbAlloc, rbAvailable] = ...
                calculator.rateAdaptation( enbPHY.enb, rbAvailable, ueDB.cqi, (sduDataLength+8)/8);
            
            % PDU multiplexing
            pdu = calculator.macMux( tbsAlloc, sentSDU );
            % transport block generation
            transportBlock = model.lteDownlinkTransportBlock(ueDB);
            transportBlock.build(enbPHY.enb,  mcsAlloc, rbAlloc, pdu);
            transportBlock.createdTTI = enbPHY.enb.tti;
            % set HARQ process ID and store to UE HARQ
            % register
            transportBlock.setHARQNo(ueDB.getHARQno);
            ueDB.addHARQProcess(transportBlock);
            
            % update feedback scheduler
            n.ue = ueDB;
            n.ackHARQNo = transportBlock.HARQNo;
            % clear sent sdu from scheduler sdu buffer
            for j = 1:length(sentSDU)
                sduBuffer(j).status = 'sent'; %#ok<*SAGROW>
                sduBuffer(j).sent_time = double(enbPHY.enb.tti) * 0.001;
                
                sduBuffer(j) = [];
            end
            
        end
    end
    
    
    % insert scheduled ue monitoring and transport block
    enbPHY.insertUE(n_1);
    enbPHY.insertTransportBlock(transportBlock);
    
    % downlink transmission
    downlinkSignal = enbPHY.transmit();
    
    
    
    uePHY.receive(channel.perform(downlinkSignal, enbPHY.enb), sduList, 1);
    
    % uplink transmission
    uplinkSignal = uePHY.transmit;
    
    % update UE TTI clock
    uePHY.tick;
    
    % ENB receiver
    enbPHY.receive(channel.perform(uplinkSignal, enbPHY.enb));
    
    % update PHY enb TTI clock
    enbPHY.tick;
    
end



