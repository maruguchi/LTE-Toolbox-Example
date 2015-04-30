%% User parameterization (all allocated by RAN (enodeb))

% User UE setting
user(1).ue.NULRB = 15;                  % Number of resource blocks
user(1).ue.NCellID = 10;                % Physical layer cell identity
user(1).ue.Hopping = 'Off';             % Disable frequency hopping
user(1).ue.CyclicPrefixUL = 'Normal';   % Normal cyclic prefix
user(1).ue.DuplexMode = 'FDD';          % Frequency Division Duplex (FDD)
user(1).ue.NTxAnts = 1;                 % Number of transmit antennas
user(1).ue.NSubframe = 0;               % Subframe number
user(1).ue.NFrame = 0;                  % Frame number
user(1).ue.RNTI = 1;
user(1).ue.SeqGroup = 0;
user(1).ue.CyclicShift = 0;
user(1).ue.Shortened = 0;
user(1).ue.CellRefP = 1;

% user PUSCH setting
user(1).pusch.NLayers = 1;
user(1).pusch.DynCyclicShift = 0;
user(1).pusch.OrthCover = 'Off';
user(1).pusch.PMI = 0;
user(1).pusch.RV = 0;

% user resource allocation
user(1).MCS = 9;
user(1).RBstart = 0;
user(1).RBlength = 15;

% data initializaton

user(1).data = [];

%% user setting in eNodeB

userENB = user;         % enodeb fully aware user setting


%% Transmit Uplink
[txGrid, user, txWaveform, txInfo] = uplinkUserSpesific(user(1));

%% Channel

txWaveform((size(txWaveform,1)+1):(size(txWaveform,1)+20)) = zeros();


% Fading channel parameters

chcfg = struct('Seed',1,'DelayProfile','ETU','NRxAnts',1);
chcfg.DopplerFreq = 5.0;
chcfg.MIMOCorrelation = 'Low';
chcfg.SamplingRate = txInfo.SamplingRate;
chcfg.InitTime = 0;


% transmit trough channel

[rxWaveform channelInfo] = lteFadingChannel(chcfg,txWaveform);


rxWaveform = awgn(rxWaveform,1,'measured');

%% Receive Uplink

userENB = uplinkUserSpesificDecode(userENB, rxWaveform, txInfo);


%% Check recovery

recovered = isequal(user(1).data,userENB(1).data)

ber = 1 - sum((user(1).data == userENB(1).data))/ size(user(1).data,1)



