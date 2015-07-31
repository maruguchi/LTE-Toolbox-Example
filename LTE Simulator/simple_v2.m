% generate physical UE
enbPHY = lteENBPhysical;

ueDB= model.lteUE(enbPHY.enb, 100, 1);

% generate physical UE
uePHY = lteUEPhysical(enbPHY.enb, ueDB.ue);

% initial mcs value
mcs = 10;

% type 2 resouce allocation. 
resourceBlock = [0 5];

% translation from mcs and resource block to transport block size
[modulation, itbs] = calculator.mcs2configuration(mcs);

tbs = lteTBS(resourceBlock(2),itbs);
tbs_wo_header = tbs - 3 * 8; % 3 bytes deduction is the simplest implemenatation.


data = calculator.macMux( tbs, {randi([0 1], tbs_wo_header, 1)});
transportBlock = model.lteDownlinkTransportBlock(ueDB);
transportBlock.build(enbPHY.enb,  mcs, resourceBlock, data);

harqID = ueDB.getHARQno;
transportBlock.setHARQNo(ueDB.getHARQno);
ueDB.addHARQProcess(transportBlock);

% insert scheduled ue monitoring and transport block
ueStates.ue = ueDB; % what is the difference between ueMon and ueDB?
ueStates.ackHARQNo = harqID;
enbPHY.insertUE(ueStates);
enbPHY.insertTransportBlock(transportBlock);



% downlink transmission
downlinkSignal = enbPHY.transmit(); 

uePHY.receive(downlinkSignal, [], []); % why [] and []?

% uplink transmission
uePHY.transmit; 
% set n-1 feedback ACK
uePHY.acKN_1 = uePHY.acKN;

uplinkSignal = uePHY.transmit;
enbPHY.receive(uplinkSignal);

% translate cqi value to mcs
bytes_to_send = 80;

[ mcsAlloc, tbsAlloc, rbAlloc, rbMap ] = calculator.rateAdaptation( enbPHY.enb, rbMap, ueDB.cqi, bytes_to_send);






