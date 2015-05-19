% Matlab code for downlink parameterization helper script
% written by Andi Soekartono, MSC Telecommunication
% Date 05-May-2015


%% Cell parameterization

% Resouce grid creation
enb.NDLRB = 100;                 % Number of downlink physical resouce block in the cell
enb.CyclicPrefix = 'normal';    % Length of downlink CyclicPrefix: 'normal' or 'extended'
enb.CellRefP = 1;               % Number of antenna port with CRS signal: 1,2 or 4

% Physical signal insertion (PSS, SSS and CRS)
enb.DuplexMode = 'FDD';         % LTE Duplex mode: 'FDD' (frame type 1) or 'TDD' (frame type 2)
enb.NSubframe = 0;              % Resource grid subframe number relative in LTE frame
enb.NCellID = 0;                % Physical cell ID correspond to PSS, SSS and CRS sequence generation

% Physical control channel

enb.Ng = 'Sixth';               % Ng  HICH group multiplier: 'Sixth' | 'Half' | 'One' | 'Two'
enb.NFrame = 0;                 % System Frame number
enb.PHICHDuration = 'Normal';   % PHICH duration (accord to CP): 'Normal' | 'Extended'
enb.CFI = 1;                    % Control format indicator (CFI) value: 1,2 or 3



%% Shared Channel parameterization

% adding DTCH downlink transmission

% sharedChannelBuilder(enb, type, allocationType, rnti, vrbStart, vrbLength, mcs, rv)

[sharedChannel(1) userChannel(1)] = sharedChannelBuilder(enb,'Downlink-DTCH',2,100,0,100,mcs,0);





