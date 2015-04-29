%% Parameterization
clear
for mcs=1:29                % MCS 0-28
    for isnr = 1:21         % SNR 0-20
        disp(['Testing : MCS = ',num2str(mcs-1),' with SNR = ',num2str(isnr-1)]);
        enbUE = [];
        for subframe = 1:1  % one subframe sent

            % Cell-wide Settings
            % eNodeB settings are configured with a structure.
            % Transmission correspond to non-MBSFN (Multicast-broadcast single-frequency network) mode 
            % This is Matlab LTE parameter for cell wide channels that affect all user
            % Comment 1.A.i

            enb.NDLRB = 15;                 % No of Downlink Resource Blocks(DL-RB): 
                                            % Allowed configuration TS 36.106 Table 5.6-1
                                            %       channel bandwidth (Mhz)      | 1.4 | 3  | 5  | 10 | 15 | 20
                                            %       transmission bandwidth (NRB) | 6   | 15 | 25 | 50 | 75 | 100
                                            % system bandwidth (BW) = NDLRB * 180 Khz : subcarrier (SC) = NDLRB * 12 subcarrier
            enb.CyclicPrefix = 'Normal';    % Cyclic Prefix length TS 36.211 Table 6.2.3 
                                            %       Normal      | 7 symbols/slot    | 14 symbols/subframe
                                            %       Extended    | 6 symbols/slot    | 12 symbols/subframe (for extended delay
                                            %       environment)
            enb.PHICHDuration = 'Normal';   % Physical Hybrid-ARQ Indicator CHannel, this related Cyclic Prefix length
                                            % TS 36.211 Table 6.9.1-2
                                            %       Normal      | 8 PHICH / PHICH group
                                            %       Extended    | 4 PHICH / PHICH group
            enb.DuplexMode = 'FDD';         % Transmission duplex mode, which related to frame structure TS 36.211 4
                                            %       FDD     | Frame structure type 1
                                            %       TDD     | Frame structure type 2
            enb.CFI = 3;                    % Control format indicator (CFI) value: 1, 2 or 3 related to number symbols in which control 
                                            % channel occupy each subframe, CFI to symbols  36.212 5.3.4
                                            %       for NDLRB > 10, number of symbols = CFI value
                                            %       for NDLRB <= 10, number of symbols = CFI value + 1
            enb.Ng = 'Sixth';               % HICH group multiplier 36.211 6.9, number PHICH group :
                                            %       Normal CP = ceil(Ng*NDLRB/8)
                                            %       Extended CP = ceil(2*Ng*NDLRB/8)
            enb.CellRefP = 1;               % Number of cell-specific reference signal (CRS) antenna ports: 1, 2 or 4 36.211 6.10.1
            enb.NCellID = 10;               % Physical layer cell identity: 0 - 503 36.211 6.11
            enb.NSubframe = subframe - 1;   % Subframe number within frame value: 0 - 9
            enb.NFrame = 0;                 % Frame number (System Frame Number: 0 - 1023


            % User Settings
            % User Spesific settings are configured with a structure.
            % This is custom structure to simulate user allocation of reource from upper layer (MAC)
            % for additional user use similar structure with prefix user(i) with i = user id.
            user(1).RNTI = 1;               % Radio Network Temporary Identifier for spesific user
                                            % C-RNTI type (user spesific after RACH), value: 1 - 65523
                                            % http://www.sharetechnote.com/html/Handbook_LTE_RNTI.html  
            user(1).RBstart = 0;            % User resource block allocation start
            user(1).RBlength = 15;          % User resource block allocation length
                                            % these parameter refer to Downlink Resourcce Allocation Type 2 36.213 7.1.6.3
                                            % RB in step 2 for NDLRB < 50 and step 4 for NDLRB > 50
            user(1).MCS = mcs-1;                % User spesific PDSCH modulation and coding scheme (MCS)  36.213 7.1.7
                                            % define modulation order and transport block size
                                            % value; 0 - 28 (defined)    
            user(1).data = [];              % user spesific data place holder (1 x transport block size) 
                                            % that can be used by upper layer
                                            % if empty downlinkUserSpesific function will generate random bits.


            % Cell-wide Settings at UE
            % eNodeB settings are configured with a structure.
            % enbUE = [];                    % Place holder for enb configuration that will be filled by receiver (EU)
                                           % by decoding received signal.


            % User Settings at UE
            % User Spesific settings are configured with a structure.
            % for additional user use similar structure with prefix userUE(i) with i = user id.

            userUE(1).RNTI = 1;           % C-RNTI for spesific user that UE already known after connection establishment



            % Channel estimator configuration at UE
            % currently taken from Matlab example code
            cec.PilotAverage = 'UserDefined';     % Type of pilot averaging
            cec.FreqWindow = 9;                   % Frequency window size
            cec.TimeWindow = 9;                   % Time window size
            cec.InterpType = 'cubic';             % 2D interpolation type
            cec.InterpWindow = 'Centered';        % Interpolation window type
            cec.InterpWinSize = 1;                % Interpolation window size




            %% Downlink transmit for each TTI subframe (0.1 ms)

            % Generate subframe transmit grid given enb and user parameters

            txGrid = downlinkCellWide(enb,lteDLResourceGrid(enb));
            [txGrid, user] = downlinkUserSpesific(enb, user, txGrid);

            % Modulate transmit grid into signals
            [txDLWaveform, txDLWaveformInfo] = lteOFDMModulate(enb, txGrid);

            % Zero padded for delay channel time domain shift
            txDLWaveform((size(txDLWaveform,1)+1):(size(txDLWaveform,1)+20)) = zeros();


            %% Channel in SISO mode

            % Fading channel parameters
            % currently taken from Matlab example code

            chcfg = struct('Seed',1,'DelayProfile','ETU','NRxAnts',1);
            chcfg.DopplerFreq = 5.0;
            chcfg.MIMOCorrelation = 'Low';
            chcfg.SamplingRate = txDLWaveformInfo.SamplingRate;
            chcfg.InitTime = 0;
            chcfg.InitPhase = 'Random';
            chcfg.ModelType = 'GMEDS';
            chcfg.NTerms = 16;
            chcfg.NormalizeTxAnts ='On'; 
            chcfg.NormalizePathGains = 'On';

            % Transmission

            % Fading channel

            %[rxDLWaveform channelInfo] = lteFadingChannel(chcfg,txDLWaveform);

            % AWGN channel
            rxDLWaveform = awgn(txDLWaveform,isnr-1,'measured');      % measured txDLWaveform and add appropriate noise SNR to it

            %% Downlink receiver for each TTI subframe (0.1 ms)

            % Decode cell wide configuration enbUE
            % Only in subframe 0 for each SFN
            
            if isempty(enbUE) || enbUE.NSubframe == 9
                enbUE = downlinkCellWideDecode(enbUE, rxDLWaveform, txDLWaveformInfo, cec);
            else
                enbUE.NSubframe = enbUE.NSubframe + 1
            end
            if isempty(enbUE)
                ber (subframe) = NaN;
                continue
            end
            % Decode user spesific data
            [enbUE, userUE] = downlinkUserSpesificDecode(enbUE, userUE, rxDLWaveform, txDLWaveformInfo, cec);
            if isempty(enbUE)
                ber (subframe) = NaN;
                continue
            end

            %% Check recovery

            % compare user data transmit and received
            %recovered = isequal(user(1).data,userUE(1).data)
            
            

            % bit error rate for single subframe
            try
                ber(subframe) = 1 - sum((user(1).data == userUE(1).data))/ size(user(1).data,1);
            catch ME
                ber = NaN;
            end
        end
        BER(mcs,isnr) = mean (ber)
    end
end

plotBERSNR



