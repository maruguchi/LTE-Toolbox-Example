ue = struct;                  % UE config structure
ue.NULRB = 6;                 % 6 resource blocks (1.4 MHz)
ue.CyclicPrefixUL = 'Normal'; % Normal cyclic prefix
ue.Hopping = 'Off';         % No frequency hopping
ue.NCellID = 150;           % Cell id as specified in TS36.104 Appendix A9
ue.Shortened = 0;           % No SRS transmission
ue.NTxAnts = 1;

% Hybrid Automatic Repeat Request (HARQ)  indicator bit set to one. Only
% one bit is required for PUCCH 1a
ACK = 1;
pucch = struct;  % PUCCH config structure
% Set the size of resources allocated to PUCCH format 2. This affects the
% location of PUCCH 1 transmission
pucch.ResourceSize = 0;
% Delta shift PUCCH parameter as specified in TS36.104 Appendix A9 [ <#8 1> ]
pucch.DeltaShift = 2;
% Number of cyclic shifts used for PUCCH format 1 in resource blocks with a
% mixture of formats 1 and 2. This is the N1cs parameter as specified in
% TS36.104 Appendix A9
pucch.CyclicShifts = 0;
% Vector of PUCCH resource indices for all UEs as specified in TS36.104
% Appendix A9
usersPUCCHindices = [2 1 7 14];
% PUCCH power for all UEs as specified in TS36.104 Appendix A9
usersPUCCHpower = [0 0 -3 3];


ue.NSubframe = 0;
txgrid = lteULResourceGrid(ue);
user = 1;
% Configure resource index for this user
pucch.ResourceIdx = usersPUCCHindices(user);

% ACK bit to transmit for the 1st (target) user, the PUCCH
% Format 1 carries the Hybrid ARQ (HARQ) indicator ACK and for
% other users it carries a random HARQ indicator. As there is a
% single indicator, the transmissions will be of Format 1a. The
% PUCCH Format 1 DRS carries no data.
if (user==1)
    txACK = ACK
else
    txACK = randi([0 1],1,1);
end

% Generate PUCCH 1 and its DRS
% Different users have different relative powers
pucch1Sym = ltePUCCH1(ue,pucch,txACK)* ...
    10^(usersPUCCHpower(user)/20);
pucch1DRSSym = ltePUCCH1DRS(ue,pucch)* ...
    10^(usersPUCCHpower(user)/20);

% Generate indices for PUCCH 1 and its DRS
pucch1Indices = ltePUCCH1Indices(ue,pucch);
pucch1DRSIndices = ltePUCCH1DRSIndices(ue,pucch);

% Map PUCCH 1 and PUCCH 1 DRS to the resource grid
if (~isempty(txACK))
    txgrid(pucch1Indices) = pucch1Sym;
    txgrid(pucch1DRSIndices) = pucch1DRSSym;
end

% SC-FDMA modulation
txwave = lteSCFDMAModulate(ue,txgrid);
rxwave = txwave;

% Receiver

% Use the resource indices for the user of interest
pucch.ResourceIdx = usersPUCCHindices(1);

% Synchronization
% The uplink frame timing estimate for UE1 is calculated using
% the PUCCH 1 DRS signals and then used to demodulate the
% SC-FDMA signal.
% An offset within the range of delays expected from the channel
% modeling (a combination of implementation delay and channel
% delay spread) indicates success.
offset = lteULFrameOffsetPUCCH1(ue,pucch,rxwave);
if (offset<25)
    offsetused = offset;
end

% SC-FDMA demodulation
% The resulting grid (rxgrid) is a 3-dimensional matrix. The number
% of rows represents the number of subcarriers. The number of
% columns equals the number of SC-FDMA symbols in a subframe. The
% number of subcarriers and symbols is the same for the returned
% grid from lteSCFDMADemodulate as the grid passed into
% lteSCFDMAModulate. The number of planes (3rd dimension) in the
% grid corresponds to the number of receive antenna.
rxgrid = lteSCFDMADemodulate(ue,rxwave(1+offsetused:end,:));

cec = struct;        % Channel estimation config structure
cec.TimeWindow = 9;  % Time averaging window size in resource elements
cec.FreqWindow = 9;  % Frequency averaging window size in resource elements
cec.InterpType = 'cubic';         % Cubic interpolation
cec.PilotAverage = 'UserDefined'; % Type of pilot averaging

% Channel estimation
[H,n0] = lteULChannelEstimatePUCCH1(ue,pucch,cec,rxgrid);

% PUCCH 1 indices for UE of interest
pucch1Indices = ltePUCCH1Indices(ue,pucch);

% Extract resource elements (REs) corresponding to the PUCCH 1 from
% the given subframe across all receive antennas and channel
% estimates
[pucch1Rx,pucch1H] = lteExtractResources(pucch1Indices,rxgrid,H);

% Minimum Mean Squared Error (MMSE) Equalization
eqgrid = lteULResourceGrid(ue);
eqgrid(pucch1Indices) = lteEqualizeMMSE(pucch1Rx,pucch1H,n0);

% PUCCH 1 decoding
rxACK = ltePUCCH1Decode(ue,pucch,1,eqgrid(pucch1Indices))


