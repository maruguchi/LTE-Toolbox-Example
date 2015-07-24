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
ueMon.ue = ueDB;
ueMon.ackHARQNo = harqID;
enbPHY.insertUE(ueMon);
enbPHY.insertTransportBlock(transportBlock);



% downlink transmission
downlinkSignal = enbPHY.transmit();

uePHY.receive(downlinkSignal, [], []);

% uplink transmission
uplinkSignal = uePHY.transmit; %#ok<NASGU>
% 
uePHY.receive(downlinkSignal, [], []);
uplinkSignal = uePHY.transmit;
enbPHY.receive(uplinkSignal);