%% PUCCH2 CQI BLER Conformance Test
% This example shows how to use the LTE System Toolbox(TM) to measures the
% Channel Quality Indicator (CQI) Block Error Rate (BLER). This indicates
% the probability of incorrectly decoding the CQI information. The CQI BLER
% performance requirements are defined in TS36.104 Section 8.3.3.1 [ <#9 1>
% ].

% Copyright 2010-2014 The MathWorks, Inc.

%% Introduction
% This example uses a simulation length of 10 subframes. This value has
% been chosen to speed up the simulation. A larger value should be chosen
% to obtain more accurate results. The probability of erroneous ACK
% detection is calculated for a number of SNR points. The target defined in
% TS36.104 Section 8.3.3.1 [ <#9 1> ] for 1.4 MHz bandwidth (6RBs) and a
% single transmit antenna is a CQI BLER of 1% (i.e. probability of
% erroneous block detection P = 0.01) at an SNR of -3.9dB. The test is
% defined for 1 transmit antenna.

numSubframes = 10;                          % Number of subframes
SNRdB = [-9.9 -7.9 -5.9 -3.9 -1.9];         % SNR range
NTxAnts = 1;                                % Number of transmit antennas

%% UE Configuration
ue = struct;                                % UE config structure
ue.NULRB = 100;                               % 6 resource blocks
ue.CyclicPrefixUL = 'Normal';               % Normal cyclic prefix
ue.Hopping = 'Off';                         % No frequency hopping
ue.NCellID = 9;
ue.RNTI = 1;                                % Radio network temporary id
ue.NTxAnts = NTxAnts;

%%   PUCCH 2 Configuration                    

% Empty hybrid ACK vector is used for Physical Uplink Control Channel
% (PUCCH) 2
ACK = [];

pucch = struct; % PUCCH config structure
% Vector of PUCCH resource indices, one per transmission antenna. This is
% the n2pucch parameter
pucch.ResourceIdx = 0:ue.NTxAnts-1;
% Set the size of resources allocated to PUCCH format 2
pucch.ResourceSize = 0;
% Number of cyclic shifts used for PUCCH format 1 in resource blocks with a
% mixture of formats 1 and 2. This is the N1cs parameter
pucch.CyclicShifts = 0;   

%% Propagation Channel Configuration
% Configure the channel model with the parameters specified in the tests
% described in TS36.104 Section 8.3.3.1 [ <#9 1> ].

channel = struct;                   % Channel config structure
channel.NRxAnts = 2;                % Number of receive antennas
channel.DelayProfile = 'ETU';       % Channel delay profile
channel.DopplerFreq = 70.0;         % Doppler frequency in Hz
channel.MIMOCorrelation = 'Low';    % Low MIMO correlation
channel.NTerms = 16;                % Oscillators used in fading model
channel.ModelType = 'GMEDS';        % Rayleigh fading model type    
channel.Seed = 3;                   % Random number generator seed 
channel.InitPhase = 'Random';       % Random initial phases     
channel.NormalizePathGains = 'On';  % Normalize delay profile power   
channel.NormalizeTxAnts = 'On';     % Normalize for transmit antennas

% SC-FDMA modulation information: required to get the sampling rate
info = lteSCFDMAInfo(ue);
channel.SamplingRate = info.SamplingRate;   % Channel sampling rate

%%  Channel Estimator Configuration
% The channel estimator is configured using a structure |cec|. Here cubic
% interpolation will be used with an averaging window of 12-by-1 Resource
% Elements (REs). This configures the channel estimator to use a special
% mode which ensures the ability to despread and orthogonalize the
% different overlapping PUCCH transmissions.

cec = struct;                     % Channel estimation config structure
cec.PilotAverage = 'UserDefined'; % Type of pilot averaging
cec.FreqWindow = 12;              % Frequency averaging window in REs (special mode)
cec.TimeWindow = 1;               % Time averaging window in REs (Special mode)     
cec.InterpType = 'cubic';         % Cubic interpolation

%% Simulation Loop for Configured SNR Points
% For each SNR point the loop below calculates the probability of
% successful ACK detection using information obtained from |NSubframes|
% consecutive subframes. The following operations are performed for each
% subframe and SNR values:
%
% * Create an empty resource grid
% * Generate and map PUCCH 2 and its Demodulation Reference Signal (DRS) to
% the resource grid
% * SC-FDMA modulation
% * Send the modulated signal through the channel 
% * Receiver synchronization
% * SC-FDMA demodulation
% * Channel estimation
% * Minimum Mean Squared Error (MMSE) equalization
% * PUCCH 2 demodulation/decoding
% * Record decoding failures
% * PUCCH 2 DRS decoding. This is not required as part of this test but
% is included to illustrate the steps involved

% Preallocate memory for probability of detection vector
BLER = zeros(size(SNRdB));
for nSNR = 1:length(SNRdB)

    % Detection failures counter
    failCount = 0;
    
    % Noise configuration
    SNR = 10^(SNRdB(nSNR)/20);              % Convert dB to linear
    % The noise added before SC-FDMA demodulation will be amplified by the
    % IFFT. The amplification is the square root of the size of the IFFT.
    % To achieve the desired SNR after demodulation the noise power is
    % normalized by this value. In addition, because real and imaginary
    % parts of the noise are created separately before being combined into
    % complex additive white Gaussian noise, the noise amplitude must be
    % scaled by 1/sqrt(2*ue.NTxAnts) so the generated noise power is 1.
    N = 1/(SNR*sqrt(double(info.Nfft)))/sqrt(2.0*ue.NTxAnts);
    % Set the type of random number generator and its seed to the default
    % value
    rng('default');

    % Loop for subframes    
    offsetused = 0;    
    for nsf = 1:numSubframes        

        % Create resource grid        
        ue.NSubframe = mod(nsf-1, 10);   % Subframe number       
        reGrid = lteULResourceGrid(ue);  % Resource grid

        % Create PUCCH 2 and its DRS
        CQI = randi([0 1], 4, 1);             % Generate 4 CQI bits to send
        % Encode CQI bits to produce 20 bits
        coded = lteUCIEncode(CQI);              
        pucch2Sym = ltePUCCH2(ue, pucch, coded);     % PUCCH 2 modulation
        pucch2DRSSym = ltePUCCH2DRS(ue, pucch, ACK); % PUCCH 2 DRS creation

        % Generate indices for PUCCH 2 and its DRS      
        pucch2Indices = ltePUCCH2Indices(ue, pucch);
        pucch2DRSIndices = ltePUCCH2DRSIndices(ue, pucch);

        % Map PUCCH 2 and its DRS to the resource grid
        reGrid(pucch2Indices) = pucch2Sym;
        reGrid(pucch2DRSIndices) = pucch2DRSSym;

        % SC-FDMA modulation
        txwave = lteSCFDMAModulate(ue, reGrid);
        
        % Channel state information: set the init time to the correct value
        % to guarantee continuity of the fading waveform
        channel.InitTime = (nsf-1)/1000;

        % Channel modeling 
        % The additional 25 samples added to the end of the waveform are to
        % cover the range of delays expected from the channel modeling (a
        % combination of implementation delay and channel delay spread)
        rxwave = lteFadingChannel(channel, [txwave;zeros(25, ue.NTxAnts)]);

        % Add noise at receiver
        noise = N*complex(randn(size(rxwave)), randn(size(rxwave)));
        rxwave = rxwave + noise;

        % Receiver 

        % Synchronization
        % An offset within the range of delays expected from the channel 
        % modeling (a combination of implementation delay and channel 
        % delay spread) indicates success
        [offset, rxACK] = lteULFrameOffsetPUCCH2( ...
            ue, pucch, rxwave, length(ACK));
        if (offset<25)
            offsetused = offset;
        end

        % SC-FDMA demodulation
        rxgrid = lteSCFDMADemodulate(ue, rxwave(1+offsetused:end, :));

        % Channel estimation            
        [H, n0] = lteULChannelEstimatePUCCH2(ue, pucch, cec, rxgrid, rxACK);

        % Extract REs corresponding to the PUCCH 2 from the given subframe
        % across all receive antennas and channel estimates
        [pucch2Rx, pucch2H] = lteExtractResources(pucch2Indices, rxgrid, H);

        % MMSE Equalization
        eqgrid = lteULResourceGrid(ue);    
        eqgrid(pucch2Indices) = lteEqualizeMMSE(pucch2Rx, pucch2H, n0);      
        
        % PUCCH 2 demodulation
        rxBits = ltePUCCH2Decode(ue, pucch, eqgrid(pucch2Indices));

        % PUCCH 2 decoding
        decoded = lteUCIDecode(rxBits, length(CQI));                       

        % Record any decoding failures
        if (sum(decoded~=CQI)~=0)          
            failCount = failCount + 1;
        end

        % Perform PUCCH 2 DRS decoding. This is not required as part of
        % this test, but illustrates the steps involved.

        % Extract REs corresponding to the PUCCH 2 DRS from the given
        % subframe across all receive antennas and channel estimates
        [drsRx, drsH] = lteExtractResources(pucch2DRSIndices, rxgrid, H);

        % PUCCH 2 DRS Equalization
        eqgrid(pucch2DRSIndices) = lteEqualizeMMSE(drsRx, drsH, n0); 

        % PUCCH 2 DRS decoding
        rxACK = ltePUCCH2DRSDecode( ...
            ue, pucch, length(ACK), eqgrid(pucch2DRSIndices));

    end
    
    % Probability of erroneous block detection
    BLER(nSNR) = (failCount/numSubframes);

end

%% Results

plot(SNRdB, BLER, 'b-o', 'LineWidth', 2, 'MarkerSize', 7); 
hold on;    
plot(-3.9, 0.01, 'rx', 'LineWidth', 2, 'MarkerSize', 7);
xlabel('SNR (dB)');
ylabel('CQI BLER');
title('CQI missed detection test (TS36.104 Section 8.3.3.1)');   
axis([SNRdB(1)-0.1 SNRdB(end)+0.1 -0.05 0.4]);
legend('simulated performance', 'target');

%% Selected Bibliography
% # 3GPP TS36.104.

displayEndOfDemoMessage(mfilename)
