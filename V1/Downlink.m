%% Parameterization
clear

% Cell-wide Settings
% eNodeB settings are configured with a structure.

enb.NDLRB = 15;               % No of Downlink Resource Blocks(DL-RB)
enb.CyclicPrefix = 'Normal';  % CP length
enb.PHICHDuration = 'Normal'; % Normal PHICH duration
enb.DuplexMode = 'FDD';       % FDD duplex mode
enb.CFI = 3;                  % 4 PDCCH symbols
enb.Ng = 'Sixth';             % HICH groups
enb.CellRefP = 1;             % 1-antenna ports
enb.NCellID = 10;             % Cell id
enb.NSubframe = 0;            % Subframe number
enb.NFrame = 0;               % Frame number

% User Settings
% User Spesific settings are configured with a structure.
user(1).RNTI = 1;             % C-RNTI for spesific user
user(1).RBstart = 0;          % Start Allocation
user(1).RBlength = 15;        % Allocation Size
user(1).MCS = 5;              % Modulation and Coding sheme
user(1).data = [];            % If empty generate random

% Cell-wide Settings at UE
% eNodeB settings are configured with a structure.
enbUE = [];                    % Place holder for enb configuration decoded at UE


% User Settings at UE
% User Spesific settings are configured with a structure.
userUE(1).RNTI = 1;           % C-RNTI for spesific user allocated after connection establishment


% Channel estimator configuration at UE
% currently taken from Matlab examplecc
cec.PilotAverage = 'UserDefined';     % Type of pilot averaging
cec.FreqWindow = 9;                   % Frequency window size
cec.TimeWindow = 9;                   % Time window size
cec.InterpType = 'cubic';             % 2D interpolation type
cec.InterpWindow = 'Centered';        % Interpolation window type
cec.InterpWinSize = 1;                % Interpolation window size




%% Downlink transmit for each TTI subframe (0.1 ms)

% Compose downlink LTE subframe with cell wide signal and channel

txGrid = downlinkCellWide(enb,lteDLResourceGrid(enb));
[txGrid, user] = downlinkUserSpesific(enb, user, txGrid);

% transmit signal
[txDLWaveform, txDLWaveformInfo] = lteOFDMModulate(enb, txGrid);

txDLWaveform((size(txDLWaveform,1)+1):(size(txDLWaveform,1)+20)) = zeros();


%% Channel in SISO mode

% Fading channel parameters

chcfg = struct('Seed',1,'DelayProfile','ETU','NRxAnts',1);
chcfg.DopplerFreq = 5.0;
chcfg.MIMOCorrelation = 'Low';
chcfg.SamplingRate = txDLWaveformInfo.SamplingRate;
chcfg.InitTime = 0;


% transmit trough channel

[rxDLWaveform channelInfo] = lteFadingChannel(chcfg,txDLWaveform);


rxDLWaveform = awgn(txDLWaveform,8,'measured');

%% Downlink receiver for each TTI subframe (0.1 ms)

enbUE = downlinkCellWideDecode(enbUE, rxDLWaveform, txDLWaveformInfo, cec);

[enbUE, userUE] = downlinkUserSpesificDecode(enbUE, userUE, rxDLWaveform, txDLWaveformInfo, cec);


%% Check recovery

recovered = isequal(user(1).data,userUE(1).data)

ber = 1 - sum((user(1).data == userUE(1).data))/ size(user(1).data,1)




