% PUCCH Parameter
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

% Uplink user spesific settings 
% Node-B fully aware UE setting

user(1).ue.NULRB = enb.NDLRB;                    % Number Uplink Resource Block similar to downlink one
user(1).ue.CyclicPrefixUL = enb.CyclicPrefix;    % Uplink cyclic prefix similar to downlink
user(1).ue.Hopping = 'Off';                      % No frequency hopping
user(1).ue.NCellID = enb.NCellID;                % Cell id simila to downlink Physical Cell ID
user(1).ue.Shortened = 0;                        % No SRS transmission 
user(1).ue.NTxAnts = 1;                          % Number of UE antenna (SISO system) 
user(1).ue.PUCCHResourceIndex = 0;               % UE spesific ResourceIdx
user(1).dataACK = 1;                             % HARQ data status 1 = Negative ACK

user(2).ue.NULRB = enb.NDLRB;                    % Number Uplink Resource Block similar to downlink one
user(2).ue.CyclicPrefixUL = enb.CyclicPrefix;    % Uplink cyclic prefix similar to downlink
user(2).ue.Hopping = 'Off';                      % No frequency hopping
user(2).ue.NCellID = enb.NCellID;                % Cell id simila to downlink Physical Cell ID
user(2).ue.Shortened = 0;                        % No SRS transmission 
user(2).ue.NTxAnts = 1;                          % Number of UE antenna (SISO system) 
user(2).ue.PUCCHResourceIndex = 1;               % UE spesific ResourceIdx
user(2).dataACK = 1;                             % HARQ data status 1 = Negative ACK

% Uplink user spesific settings at UE
% User Spesific settings are configured with a structure.
% for additional user use similar structure with prefix userUE(i) with i = user id.
% setting 

% according to spesification some of these parameter is carried to UE by MIB and SIB

userUE(1).ue = struct;                           % UE parameter placeholder
userUE(1).ue.PUCCHResourceIndex = 0;             % UE spesific ResourceIdx

userUE(2).ue = struct;                           % UE parameter placeholder
userUE(2).ue.PUCCHResourceIndex = 1;             % UE spesific ResourceIdx

