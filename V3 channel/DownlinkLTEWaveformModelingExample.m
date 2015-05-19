%% LTE Waveform Modeling Using Downlink Transport and Physical Channels
% This example shows how to generate a time domain waveform containing a
% Physical Downlink Shared Channel (PDSCH), corresponding Physical Downlink
% Control Channel (PDCCH) transmission and the Physical Control Format
% Indicator Channel (PCFICH), for one subframe.

% Copyright 2009-2014 The MathWorks, Inc.

%% Introduction
% This example demonstrates how to generate a complete Downlink Shared
% Channel (DL-SCH) transmission for 6 resource blocks, 4 antenna transmit
% diversity using the functions from the LTE System Toolbox(TM). The
% following physical channels are modeled:
% 
% * Physical Downlink Shared Channel (PDSCH)
% * Physical Downlink Control Channel (PDCCH)
% * Physical Downlink Control Format Indicator Channel (PCFICH)
% 
% This example generates a time domain (post OFDM modulation) for all 4
% antenna ports. A single subframe (number 0) is considered in this
% example.
% 
% Note: The recommended way to generate RMC waveforms is using
% <matlab:doc('lteRMCDLTool') lteRMCDLTool>, this example shows how a
% waveform can be built by creating and combining individual physical
% channels, as happens in an LTE system.

%% Cell-wide Settings
% eNodeB settings are configured with a structure.

enbConfig.NDLRB = 100;              % No of Downlink Resource Blocks(DL-RB)
enbConfig.CyclicPrefix = 'Normal';  % CP length
enbConfig.PHICHDuration = 'Normal'; % Normal PHICH duration
enbConfig.DuplexMode = 'FDD';       % FDD duplex mode
enbConfig.CFI = 3;                  % 4 PDCCH symbols
enbConfig.Ng = 'Sixth';             % HICH groups
enbConfig.CellRefP = 4;             % 4-antenna ports
enbConfig.NCellID = 10;             % Cell id
enbConfig.NSubframe = 0;            % Subframe number 0

%% Subframe Resource Grid Generation
% A resource grid can easily be created using
% <matlab:doc('lteDLResourceGrid') lteDLResourceGrid>. This creates an
% empty resource grid for one subframe. The subframe is a 3 dimensional
% matrix. The number of rows represents the number of subcarriers
% available, this is equal to |12*enbConfig.NDLRB| since there are 12
% subcarriers per resource block. The number of columns equals the number
% of OFDM symbols in a subframe, i.e. 7*2, since we have 7 OFDM symbols per
% slot for normal cyclic prefix and there are 2 slots in a subframe. The
% number of planes (3rd dimension) in subframe is 4 corresponding to the 4
% antenna ports as specified in |enbConfig.CellRefP|.

subframe = lteDLResourceGrid(enbConfig);

%% DL-SCH Channel Coding
% We now generate the DL-SCH bits and apply channel coding. This includes
% CRC calculation, code block segmentation and CRC insertion, turbo coding,
% rate matching and code block concatenation. It can be performed using
% <matlab:doc('lteDLSCH') lteDLSCH>.
%
% DL-SCH transport block size is chosen according to rules in TS36.101,
% Annex A.2.1.2 [ <#16 1> ] "Determination of payload size" with target
% code rate $R=1/3$ and number of bits per subframe given by
% |codedTrBlkSize|.
[pdschIndices, pdschInfo] = ltePDSCHIndices(enbConfig, pdschConfig, prbs, {'1based'});
codedTrBlkSize = 480;  % Coded transport block size

% Transmission mode configuration for PDSCH
pdschConfig.NLayers = 4;               % No of layers
pdschConfig.TxScheme = 'TxDiversity';  % Transmission scheme
pdschConfig.Modulation = 'QPSK';       % Modulation scheme
pdschConfig.RNTI = 1;                  % 16-bit UE-specific mask
pdschConfig.RV = 0;                    % Redundancy Version

transportBlkSize = 152;                % Transport block size
dlschTransportBlk = randi([0 1], transportBlkSize, 1);

% Perform Channel Coding
codedTrBlock = lteDLSCH(enbConfig, pdschConfig, pdschInfo.G, ...
               dlschTransportBlk);

%% PDSCH Complex Symbols Generation
% The following operations are applied to the coded transport block to
% generate the Physical Downlink Shared Channel complex symbols:
% scrambling, modulation, layer mapping and precoding. This can be achieved
% using <matlab:doc('ltePDSCH') ltePDSCH>. As well as some of the cell-wide
% settings specified in |enbConfig| this function also requires other
% parameters related to the modulation and channel transmission
% configuration, |pdschConfig|. The resulting matrix |pdschSymbols| has 4
% columns. Each column contains the complex symbols to map to each antenna
% port.

pdschSymbols = ltePDSCH(enbConfig, pdschConfig, codedTrBlock);

%% PDSCH Mapping Indices Generation and Mapping
% The indices to map the PDSCH complex symbols to the subframe resource
% grid are generated using <matlab:doc('ltePDSCHIndices') ltePDSCHIndices>.
% The parameters required by this function include some of the cell-wide
% settings in |enbConfig|, channel transmission configuration |pdsch| and
% the physical resource blocks (PRBs). The latter indicates the resource
% allocation for transmission of the PDSCH. In this example we have assumed
% all resource blocks are allocated to the PDSCH. This is specified using a
% column vector as shown below.
%
% These indices are made '1based' for direct mapping on the resource grid
% as MATLAB(R) uses 1 based indexing. In this case we have assumed that
% both slots in the subframe share the same resource allocation. It is
% possible to have different allocations for each slot by specifying a two
% column matrix as allocation, where each column will refer to each slot in
% the subframe.
%
% The resulting matrix |pdschIndices| has 4 columns, each column contains a
% set of indices in linear style pointing to the resource elements to be
% used for the PDSCH in each antenna port. Note that this function returns
% indices avoiding resource elements allocated to reference signals, the
% control region, broadcast channels and synchronization signals.
% 
% The generated indices are represented in 1-base format as used by MATLAB
% but can be made standard specific 0-based using string options |'0based'|
% instead of |'1based'|. If this string option is not specified the default
% is 1-based index generation.

prbs = (0:enbConfig.NDLRB-1).';  % Subframe resource allocation
pdschIndices = ltePDSCHIndices(enbConfig, pdschConfig, prbs, {'1based'});

% Map PDSCH symbols on resource grid
subframe(pdschIndices) = pdschSymbols;  

%% DCI message configuration
% Downlink Control Information (DCI), conveys information about the DL-SCH
% resource allocation, transport format, and information related to the
% DL-SCH hybrid ARQ. <matlab:doc('lteDCI') lteDCI> can be used to generate
% a DCI message to be mapped to the Physical Downlink Control Channel
% (PDCCH). These parameters include the number of downlink Resource Blocks
% (RBs), the DCI format and the Resource Indication Value (RIV). The RIV of
% 26 correspond to full bandwidth assignment. <matlab:doc('lteDCI') lteDCI>
% returns a structure |dciMessage| and a vector containing the DCI message
% bits |dciMessageBits|. Both contain the same information; the structure
% is more readable, while the serialized DCI message is a more suitable
% format to send to the channel coding stages.

dciConfig.DCIFormat = 'Format1A';  % DCI message format
dciConfig.Allocation.RIV = 26;     % Resource indication value

[dciMessage, dciMessageBits] = lteDCI(enbConfig, dciConfig); % DCI message
 
%% DCI Channel Coding
% The DCI message bits are channel coded. This includes the following
% operations: CRC insertion, tail-biting convolutional coding and rate
% matching. The field |PDCCHFormat| indicates that one Control Channel
% Element (CCE) is used for the transmission of PDCCH, where a CCE is
% composed of 36 useful resource elements.

pdcchConfig.NDLRB = enbConfig.NDLRB;  % Number of DL-RB in total BW
pdcchConfig.RNTI = pdschConfig.RNTI;  % 16-bit value number
pdcchConfig.PDCCHFormat = 0;          % 1-CCE of aggregation level 1

% Performing DCI message bits coding to form coded DCI bits
codedDciBits = lteDCIEncode(pdcchConfig, dciMessageBits);

%% PDCCH Bits Generation
% The capacity of the control region depends on the bandwidth, the Control
% Format Indicator (CFI), the number of antenna ports and the PHICH groups.
% The total number of resources available for PDCCH can be calculated using
% <matlab:doc('ltePDCCHInfo') ltePDCCHInfo>. This returns a structure
% |pdcchInfo| where the different fields express the resources available to
% the PDCCH in different units: bits, CCEs, Resource Elements (REs) and
% Resource Elements Groups (REGs). The total number of bits available in
% the PDCCH region can be found in the field |pdcchInfo.MTot|. This allows
% us to build a vector with the appropriate number of elements. Not all the
% available bits in the PDCCH region are necessarily used. Therefore the
% convention adopted is to set unused bits to -1, while bit locations with
% values 0 or 1 are used.
% 
% Note that we have initialized all elements in |pdcchBits| to -1,
% indicating that initially all the bits are unused. The elements of
% |codedDciBits| are mapped to the appropriate locations in |pdcchBits|.
% 
% Only a subset of all the bits in |pdcchBits| may be used, these are
% called the candidate bits. Indices to these can be calculated using
% <matlab:doc('ltePDCCHSpace') ltePDCCHSpace>. This returns a two column
% matrix. Each row indicates the available candidate locations for the
% provided cell-wide settings |enbConfig| and PDCCH configuration structure
% |pdcchConfig|. The first and second columns contain the indices of the
% first and last locations respectively of each group of candidates. In
% this case these indices are 1-based and refer to bits, hence they can be
% used to access locations in |pdcchBits|. The vector |pdcchBits| has 664
% elements. The 72 bits of |codedDciBits| are mapped to the chosen
% candidate in |pdcchBits|. Therefore out of 664 elements, 72 will take 0
% and 1 values, while the rest remain set to -1. <matlab:doc('ltePDCCH')
% ltePDCCH> will interpret these locations as unused and will only consider
% those with 1s and 0s.

pdcchInfo = ltePDCCHInfo(enbConfig);    % Get the total resources for PDCCH
pdcchBits = -1*ones(pdcchInfo.MTot, 1); % Initialized with -1

% Performing search space for UE-specific control channel candidates
candidates = ltePDCCHSpace(enbConfig, pdcchConfig, {'bits','1based'});

% Mapping PDCCH payload on available UE-specific candidate. In this example
% the first available candidate is used to map the coded DCI bits.
pdcchBits( candidates(1, 1) : candidates(1, 2) ) = codedDciBits;

%% PDCCH Complex Symbol Generation
% From the set of bits used in |pdcchBits| (values not set to -1) PDCCH
% complex symbols are generated. The following operations are required:
% scrambling, QPSK modulation, layer mapping and precoding.
% 
% <matlab:doc('ltePDCCH') ltePDCCH> takes a set of PDCCH bits and generates
% complex-valued PDCCH symbols performing the operations mentioned above.
% In this case pdcchSymbols is a 4 column matrix, each corresponding to
% each antenna port.

pdcchSymbols = ltePDCCH(enbConfig, pdcchBits);

%% PDCCH Mapping Indices Generation and Resource Grid Mapping
% PDCCH indices are generated for symbol mapping on resource grid.
% |pdcchIndices| is a matrix with 4 columns, one column per antenna port.
% The rows contain the indices in linear form for mapping the PDCCH symbols
% to the subframe resource grid.

pdcchIndices = ltePDCCHIndices(enbConfig, {'1based'});

% The complex PDCCH symbols are easily mapped to each of the resource grids
% for each antenna port
subframe(pdcchIndices) = pdcchSymbols;

%% CFI Channel Coding
% The number of OFDM symbols in a subframe is linked to the Control Format
% Indicator (CFI) value. Cell-wide settings enbConfig specifies a CFI value
% of 3, which means that 4 OFDM symbols are used for the control region in
% the case of 6 downlink resource blocks. The CFI is channel coded using
% <matlab:doc('lteCFI') lteCFI>. The resulting set of coded bits is a 32
% element vector.

cfiBits = lteCFI(enbConfig);

%% PCFICH Complex Symbol Generation
% The CFI coded bits are then scrambled, QPSK modulated, mapped to layers
% and precoded to form the PCFICH complex symbols. The |pcfichSymbols| is a
% matrix having 4 columns where each column contains the PCFICH complex
% symbols that map to each of the antenna ports.

pcfichSymbols = ltePCFICH(enbConfig, cfiBits);

%% PCFICH Indices Generation and Resource Grid Mapping
% The PCFICH complex symbols are mapped to the subframe resource grid using
% the appropriate mapping indices. These are generated using
% <matlab:doc('ltePCFICHIndices') ltePCFICHIndices> and will be used to map
% the PCFICH symbol quadruplets to resource element groups in the first
% OFDM symbol in a subframe. All antenna ports are considered, and resource
% elements used by Reference Signals (RSs) are avoided. Note that the
% resulting matrix has 4 columns; each column contains the indices in
% linear form for each antenna port. These indices are 1-based, however
% they can also be generated using 0-based. The linear indexing style used
% makes the resource grid mapping process straight forward. The resulting
% matrix contains the complex symbols in |pcfichSymbols| in the locations
% specified by |pcfichIndices|.

pcfichIndices = ltePCFICHIndices(enbConfig);

% Map PCFICH symbols to resource grid
subframe(pcfichIndices) = pcfichSymbols;

%% OFDM Modulation
% Time domain mapping by performing OFDM modulation for downlink symbols.
% The resulting matrix has 4 columns; each column contains the samples for
% each antenna port.

[timeDomainMapped, timeDomainInfo] = lteOFDMModulate(enbConfig, subframe);

%% Selected Bibliography
% # 3GPP TS 36.101

displayEndOfDemoMessage(mfilename) 