enbPHY = lteENBPhysical;

ueDB= model.lteUE(enbPHY.enb, 100, 1);
% generate physical UE

uePHY = lteUEPhysical(enbPHY.enb, ueDB.ue);

mcs = 10;
resourceBlock = [0 5];
data = calculator.macMux( 776, {randi([0 1],752,1)});
transportBlock = model.lteDownlinkTransportBlock(ueDB);
transportBlock.build(enbPHY.enb,  mcs, resourceBlock, data);

harqID = ueDB.getHARQno;
transportBlock.setHARQNo(ueDB.getHARQno);
ueDB.addHARQProcess(transportBlock);

% insert scheduled ue monitoring and transport block
ueMon.ue = ueDB; % what is the difference between ueMon and ueDB?
ueMon.ackHARQNo = harqID;
enbPHY.insertUE(ueMon);
enbPHY.insertTransportBlock(transportBlock);



% downlink transmission
downlinkSignal = enbPHY.transmit(); 

uePHY.receive(downlinkSignal, [], []); % why [] and []?

% uplink transmission
uplinkSignal = uePHY.transmit; %#ok<NASGU>
% 
uePHY.receive(downlinkSignal, [], []); % why transmit twice
uplinkSignal = uePHY.transmit;
enbPHY.receive(uplinkSignal);