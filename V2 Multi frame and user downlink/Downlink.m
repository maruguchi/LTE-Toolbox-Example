%% Parameterization
clear

% Cell-wide Settings
% eNodeB settings are configured with a structure.
% Transmission correspond to non-MBSFN (Multicast-broadcast single-frequency network) mode 
% This is Matlab LTE parameter for cell wide channels that affect all user
% Comment 1.A.i

enb.NDLRB = 6;                  % No of Downlink Resource Blocks(DL-RB): 
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
enb.NSubframe = 0;              % Subframe number within frame value: 0 - 9
enb.NFrame = 0;                 % Frame number (System Frame Number: 0 - 1023


% User Settings at eNodeB
% User Spesific settings are configured with a structure.
% This is custom structure to simulate user allocation of reource from upper layer (MAC)
% for additional user use similar structure with prefix user(i) with i = user id.
user(1).RNTI = 1000;               % Radio Network Temporary Identifier for spesific user
                                % C-RNTI type (user spesific after RACH), value: 1 - 65523
                                % http://www.sharetechnote.com/html/Handbook_LTE_RNTI.html  
user(1).RBstart = 4;            % User resource block allocation start
user(1).RBlength = 1;           % User resource block allocation length
                                % these parameter refer to Downlink Resourcce Allocation Type 2 36.213 7.1.6.3
                                % RB in step 2 for NDLRB < 50 and step 4 for NDLRB > 50
user(1).MCS = 9;                % User spesific PDSCH modulation and coding scheme (MCS)  36.213 7.1.7
                                % define modulation order and transport block size
                                % value; 0 - 28 (defined) 
user(1).data = [];              % user spesific data place holder (1 x transport block size) 
                                % that can be used by upper layer
                                % if empty downlinkUserSpesific function will generate random bits.
                                

% Cell-wide Settings at UE
% eNodeB settings are configured with a structure.
userUE(1).enb = [];             % Place holder for enb configuration that will be filled by receiver (EU)
                                % by decoding received signal.


% User Settings at UE
% User Spesific settings are configured with a structure.
% for additional user use similar structure with prefix userUE(i) with i = user id.

userUE(1).RNTI = 1000;             % C-RNTI for spesific user that UE already known after connection establishment
userUE(1).data = [];            % Decoded user data place holder.   
userUE(1).dataCRC = [];         % Decoded user data CRC place holder.
userUE(1).CQI = [];             % PDSCH CQI value
userUE(1).timeDomainOffset = 0; % UE time domain delay offset for fading channel

% Second user
user(2).RNTI = 20000;           % RNTI need to be kept separated in order PDCCH candidate not over lapped   
user(2).RBstart = 5;            
user(2).RBlength = 1;           
user(2).MCS = 9;                
user(2).data = [];                                            

userUE(2).enb = [];             
userUE(2).RNTI = 20000;             
userUE(2).data = []; 
userUE(2).dataCRC = [];
userUE(2).CQI = []; 
userUE(2).timeDomainOffset = 0; 

user(3).RNTI = 10000;           % RNTI need to be kept separated in order PDCCH candidate not over lapped   
user(3).RBstart = 0;            
user(3).RBlength = 1;           
user(3).MCS = 9;                
user(3).data = [];                                            

userUE(3).enb = [];             
userUE(3).RNTI = 10000;             
userUE(3).data = [];  
userUE(3).dataCRC = [];
userUE(3).CQI = []; 
userUE(3).timeDomainOffset = 0; 


% Channel estimator configuration at UE
% currently taken from Matlab example code
cec.PilotAverage = 'UserDefined';     % Type of pilot averaging
cec.FreqWindow = 9;                   % Frequency window size
cec.TimeWindow = 9;                   % Time window size
cec.InterpType = 'cubic';             % 2D interpolation type
cec.InterpWindow = 'Centered';        % Interpolation window type
cec.InterpWinSize = 1;                % Interpolation window size

disp(['=========================================================='])
for i = 1:20                          % send 1 frame / 10 subframes
    %% Downlink transmit for each TTI subframe (0.1 ms)
    % eNodeB subframe number and SFN
    
    enb.NSubframe = mod(i-1,10);
    enb.NFrame = floor((i-1)/10);
    disp(['Time stamp ',num2str((enb.NFrame*4+enb.NSubframe)*0.001),'s'])
    disp(['eNodeB Downlink transmission SFN ',num2str(enb.NFrame),' Subframe ',num2str(enb.NSubframe)])
    % Generate subframe transmit grid given enb and user parameters
    
    txGrid = downlinkCellWide(enb,lteDLResourceGrid(enb));
    [txGrid, user] = downlinkUserSpesific(enb, user, txGrid);
    
    % Modulate transmit grid into signals
    [txDLWaveform, txDLWaveformInfo] = lteOFDMModulate(enb, txGrid);
    
    % Zero padded for delay channel time domain shift
    txDLWaveform((size(txDLWaveform,1)+1):(size(txDLWaveform,1)+20)) = zeros();
    
    
    %% Channel in SISO mode
    
    % AWGN channel
    rxDLWaveform = awgn(txDLWaveform,20,'measured');
    %rxDLWaveform = txDLWaveform;
    disp(' ')

    %% Downlink receiver for each TTI subframe (0.1 ms)
    
    for u=1:size(userUE,2)
        % Decode cell wide configuration enbUE for each start of the frames
        if isempty(userUE(u).enb) ||  mod(userUE(u).enb.NSubframe,10) == 0
            userUE(u).enb = downlinkCellWideDecode(userUE(u).enb, rxDLWaveform, txDLWaveformInfo, cec);
        end
        % Decode user spesific data
        userUE(u) = downlinkUserSpesificDecode(userUE(u), rxDLWaveform, txDLWaveformInfo, cec);
        
        
        %% Check recovery
        
        % compare user data transmit and received
        recovered = isequal(user(u).data,userUE(u).data);
        
        % bit error rate for single subframe
        ber = 1 - sum((user(u).data == userUE(u).data))/ size(user(u).data,1);
        
        disp(['Received by user number ',num2str(u),' RNTI ',num2str(userUE(u).RNTI),...
            ' : BER ',num2str(ber),' CRC ',num2str(userUE(u).dataCRC)])
        
        
        
        % UE next received Subframe
        userUE(u).enb.NSubframe = userUE(u).enb.NSubframe + 1;
        
    end
    disp(['=========================================================='])
end



