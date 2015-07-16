%lteCQISelect PDSCH Channel Quality Indication (CQI) calculation.
%   [CQI,SINRS]=lteCQISelect(ENB,CHS,HEST,NOISEEST) performs PDSCH
%   Channel Quality Indication (CQI) calculation for the given cell-wide
%   settings ENB, channel configuration structure CHS, channel estimate
%   resource array HEST and receiver noise variance NOISEEST. 
%
%   ENB must be a structure including the fields:
%   NDLRB          - Number of downlink resource blocks 
%   NCellID        - Physical layer cell identity
%   CellRefP       - Number of cell-specific reference signal antenna ports 
%                    (1,2,4)
%   CyclicPrefix   - Optional. Cyclic prefix length 
%                    ('Normal'(default),'Extended')
%   DuplexMode     - Optional. Duplex mode ('FDD'(default),'TDD')
%   Only required for 'TDD' duplex mode:
%      TDDConfig   - Optional. Uplink/Downlink Configuration (0...6)
%      SSC         - Optional. Special Subframe Configuration (0...9)
%      NSubframe   - Subframe number   
%   Only required for 'Port7-14' transmission scheme below:
%      CSIRefP     - Number of CSI-RS antenna ports (1,2,4,8)
%      CSIRSConfig - CSI-RS configuration index (TS 36.211 Table 
%                    6.10.5.2-1)
%      CSIRSPeriod - Optional. CSI-RS subframe configuration: 
%                    ('On'(default),'Off',Icsi-rs,[Tcsi-rs Dcsi-rs])
%      NFrame      - Optional. Frame number (default 0)
%
%   CHS must be a structure including the fields:
%   NLayers       - Number of transmission layers (1...8)
%   CSIMode       - CSI reporting mode. ('PUCCH 1-0','PUCCH 1-1',
%                   'PUSCH 1-2','PUSCH 3-0','PUSCH 3-1')
%                   (CQI-ReportModeAperiodic, cqi-FormatIndicatorPeriodic)
%   TxScheme      - Transmission scheme, one of:
%                   'Port0'       - Single-antenna port, Port 0
%                   'TxDiversity' - Transmit diversity scheme
%                   'CDD'         - Large delay CDD scheme
%                   'SpatialMux'  - Closed-loop spatial multiplexing scheme
%                   'MultiUser'   - Multi-user MIMO scheme
%                   'Port5'       - Single-antenna port, Port 5
%                   'Port7-8'     - Single-antenna port, port 7 (when 
%                                   NLayers=1); Dual layer transmission, 
%                                   port 7 and 8 (when NLayers=2)
%                   'Port8'       - Single-antenna port, Port 8
%                   'Port7-14'    - Up to 8 layer transmission, ports 7-14
%   Rho           - Optional. PDSCH resource element power allocation in dB 
%                   (default 0) (rho_A, rho_B)
%   SINRs90pc     - Optional. A vector of 15 SINR values or a function
%                   handle to a function of the form f(ENB,CHS) which
%                   returns a vector of 15 SINR values, one for each CQI
%                   index 1...15. These correspond to the lowest SINR for
%                   which the throughput of the PDSCH in the CQI/CSI
%                   reference resource, for the given configuration and CQI
%                   index, is at least 90%. (Default is to internally
%                   select the SINRs based on the configuration given in
%                   ENB and CHS, and assuming the receiver architecture
%                   documented in <a href="matlab: doc('lteCQISelect')"
%                   >lteCQISelect</a>).
%   Only required for 'SpatialMux', 'MultiUser', 'Port5', 'Port7-8', 
%   'Port8' and 'Port7-14' transmission schemes:
%      PMISet     - A vector of Precoder Matrix Indications. The vector may
%                   contain either a single value (corresponding to single
%                   PMI mode) or multiple values (corresponding to multiple 
%                   or subband PMI mode). For the 'Port7-14' transmission
%                   scheme with 8 CSI-RS ports, an additional first value
%                   indicates the wideband codebook index i1 and subsequent
%                   values indicate the subband codebook indices i2 or
%                   wideband codebook index i2. Values are in the range
%                   0...15, with the exact range depending on CellRefP,
%                   CSIRefP, NLayers and TxScheme. (See <a 
%                   href="matlab:help('ltePMIInfo')" >ltePMIInfo</a>)
%   Additionally, one of the following fields must be included:
%   NCodewords    - Number of codewords (1, 2)
%   Modulation    - A cell array of one or two strings specifying the
%                   modulation formats for one or two codewords:
%                   'QPSK', '16QAM', '64QAM'
%
%   The number of codewords can be directly specified in the NCodewords
%   field. Alternatively, if the Modulation field is provided instead, the
%   number of codewords is established from the number of modulation
%   formats in that field. This allows the number of codewords to be
%   established using the channel transmission configuration structure CHS
%   as provided to the <a href="matlab: help('ltePDSCH')"
%   >ltePDSCH</a> function on the transmit side. The  
%   NCodewords field takes precedence over the number of codewords derived
%   from the modulation field if present.
%
%   Note that for transmission schemes using UE-specific beamforming
%   ('Port5', 'Port7-8', 'Port8', 'Port7-14') the performance is dependent
%   on the beamforming used and therefore it is recommended that an
%   appropriate value for the CHS.SINRs90pc field is provided. If this
%   field is not provided for these transmission schemes, the default
%   SINRs90pc values used are the same as those for a single antenna port
%   case.
%
%   HEST is a multidimensional array of size K-by-L-by-NRxAnts-by-P, where
%   K is the number of subcarriers, L is the number of OFDM symbols,
%   NRxAnts is the number of receive antennas and P is the number of
%   transmit antennas.
%
%   NOISEEST is a scalar, an estimate of the received noise power spectral 
%   density. 
%
%   Internally, this function performs CQI selection by obtaining SINR
%   estimates for the given configuration from <a
%   href="matlab:help('ltePMISelect')" >ltePMISelect</a> and then
%   performing a lookup between those SINRs and the CQI index; the lookup
%   is defined as described for the parameter field CHS.SINRs90pc above. CQI
%   selection is conditioned on the rank indicated by CHS.NLayers, except
%   for the 'TxDiversity' transmission scheme where the rank is 1. CQI
%   selection corresponds to Report Type 2 (for reporting Mode 1-1) or
%   Report Type 4 (for reporting Mode 1-0) on the PUCCH or reporting Mode
%   1-2, Mode 3-0 or Mode 3-1 on the PUSCH.
%
%   The CQI output is a column vector containing the CQI report; the
%   contents of the report depend upon the CSI reporting mode. For a single
%   codeword, the contents of the report are as follows:
%   'PUCCH 1-0'   - A single wideband CQI index.
%   'PUSCH 3-0'   - A single wideband CQI index, followed by a subband
%                   differential CQI offset level for each subband. 
%   For two codewords, the contents of the report are as follows:
%   'PUCCH 1-1'   - A single wideband CQI index for codeword 0, followed by 
%                   a spatial differential CQI offset level for codeword 1.
%   'PUSCH 1-2'   - A single wideband CQI index for codeword 0, followed by
%                   a single wideband CQI index for codeword 1. 
%   'PUSCH 3-1'   - A single wideband CQI index for codeword 0, followed by 
%                   a subband differential CQI offset level for each 
%                   subband for codeword 0, followed by a single wideband
%                   CQI index for codeword 1, followed by a subband 
%                   differential CQI offset level for each subband for
%                   codeword 1.
%   Note that the CSI reporting modes above are separated into those that
%   support 1 or 2 codewords as described by the standard, however this
%   function will derive the number of codewords from the specified
%   CHS.Modulation or chs.NCodewords as described for structure CHS above.
%
%   A CQI index is a scalar (0...15), indicating the selected value of the
%   Channel Quality Indication (CQI) index. The CQI index is defined as
%   (per TS36.213 Section 7.2.3) the highest CQI index such that a single
%   PDSCH transport block with a combination of modulation scheme and
%   transport block size corresponding to the CQI index, and occupying a
%   group of downlink physical resource blocks termed the CSI reference
%   resource, could be received with a transport block error probability
%   not exceeding 0.1. If a CQI index of 1 does not satisfy this condition
%   then the returned CQI index will be 0. The CQI reference resource is
%   defined in TS36.213 Section 7.2.3, and the relationship between CQI
%   indices and modulation scheme and code rate (from which transport block
%   size is derived) is described by TS36.213 Table 7.2.3-1.
%
%   A subband differential CQI offset level is the difference between a
%   subband CQI index and the corresponding wideband CQI index.
%
%   A spatial differential CQI offset level is the difference between the
%   wideband CQI index for codeword 0 and the wideband CQI index for
%   codeword 1.
%
%   Within the standard, CQI offsets are reported as "CQI values" which are
%   non-negative integers corresponding to single CQI offset levels or
%   ranges of CQI offset levels (see TS36.213 Tables 7.2-2 and 7.2.1-2).
%   The CQI offset levels reported here are either the single CQI offset
%   level corresponding to the CQI value reported, or the boundary value of
%   the CQI offset level range corresponding to the CQI value reported. For
%   example, a calculated spatial differential CQI offset level of -6 would
%   be reported per the standard as a spatial differential CQI value of 4.
%   This function will return a spatial differential offset level of -4
%   because the calculated differential CQI offset level exceeds this
%   boundary value i.e. -6 < -4 (see TS36.213 Table 7.2-2).
%
%   SINRS is a matrix containing the SINRs, in deciBels, for wideband and
%   subband CQI reports for each codeword. Each column of the matrix
%   represents a single codeword. In the rows, the SINR for the wideband
%   CQI is in the first row, followed by the SINRs for the subband CQIs in
%   subsequent rows if subband CQI reporting is configured. 
%
%   Example:
%   An empty resource grid for RMC R.13 is populated with cell-specific
%   reference signals symbols. The signal is filtered through the channel,
%   demodulated and the corresponding channel is estimated along with an
%   estimate of noise power spectral density on the reference signal
%   subcarriers. The estimates are used for CQI calculation.
%
%   enb = lteRMCDL('R.13');
%   reGrid = lteResourceGrid(enb);
%   reGrid(lteCellRSIndices(enb)) = lteCellRS(enb);
%   txWaveform = lteOFDMModulate(enb,reGrid);
%   chcfg.SamplingRate = 15360000; 
%   chcfg.DelayProfile = 'EPA'; 
%   chcfg.NRxAnts = 4; 
%   chcfg.DopplerFreq = 5; 
%   chcfg.MIMOCorrelation = 'Low'; 
%   chcfg.InitTime = 0; 
%   chcfg.Seed = 1; 
%   rxWaveform = lteFadingChannel(chcfg,txWaveform);
%   rxSubframe = lteOFDMDemodulate(enb,rxWaveform);
%   cec.FreqWindow = 1; 
%   cec.TimeWindow = 31; 
%   cec.InterpType = 'cubic'; 
%   cec.PilotAverage = 'UserDefined'; 
%   cec.InterpWinSize = 1; 
%   cec.InterpWindow = 'Centered'; 
%   [hest, noiseEst] = lteDLChannelEstimate(enb,cec,rxSubframe);
%   cqi = lteCQISelect(enb,enb.PDSCH,hest,noiseEst)
%
%   See also lteRISelect, ltePMISelect.

%   Copyright 2012-2014 The MathWorks, Inc.

function [CQI,SINRs] = lteCQISelect(enb,chs,hest,noiseest)
        
    % Check for CSIMode field.
    if (~isfield(chs,'CSIMode'))
        error('lte:error','The function call (lteCQISelect) resulted in an error: Could not find a structure field CSIMode'); 
    end
    
    % Validate CSIMode.
    if (~any(strcmpi(chs.CSIMode,{'PUCCH 1-0','PUCCH 1-1','PUSCH 1-2','PUSCH 3-0','PUSCH 3-1'})))        
        error('lte:error','The function call (lteCQISelect) resulted in an error: For the parameter field CSIMode, (%s) is not one of the set (PUCCH 1-0, PUCCH 1-1, PUSCH 1-2, PUSCH 3-0, PUSCH 3-1)',chs.CSIMode);
    end
        
    % Check for TxScheme field.
    if (~isfield(chs,'TxScheme'))
        error('lte:error','The function call (lteCQISelect) resulted in an error: Could not find a structure field TxScheme'); 
    end   
    % Validate TxScheme.
    if (~any(strcmpi(chs.TxScheme,{'Port0', 'TxDiversity', 'CDD', 'SpatialMux', 'MultiUser', 'Port5', 'Port7-8', 'Port8', 'Port7-14'})))
        error('lte:error','The function call (lteCQISelect) resulted in an error: For the parameter field TxScheme, (%s) is not one of the set (Port0, TxDiversity, CDD, SpatialMux, MultiUser, Port5, Port7-8, Port8, Port7-14)',chs.TxScheme);
    end       
    
    % Default Rho if absent.
    if (~isfield(chs,'Rho'))
        chs.Rho = 0; 
        defaultValueWarning('Rho','0');
    end
        
    % Configure CQIMode (the CQI feedback type) from CSIMode, for the
    % purposes of obtaining wideband or subband SINR estimates.
    if (any(strcmpi(chs.CSIMode,{'PUSCH 3-0', 'PUSCH 3-1'})));
        CQIMode = 'Subband';
    else
        CQIMode = 'Wideband';
    end
    
    % Check for NCodewords field.
    if (isfield(chs,'NCodewords'))
        ncw = chs.NCodewords;
        if (ncw~=1 && ncw~=2)
            error('lte:error','The function call (lteCQISelect) resulted in an error: For the parameter field NCodewords, the value (%s) must be within the range [1,2]',num2str(ncw));
        end        
    else
        % Check for Modulation field.
        if(~isfield(chs,'Modulation'))
            error('lte:error','The function call (lteCQISelect) resulted in an error: Input structure must contain either an NCodewords or Modulation field.');
        end
        % Determine number of codewords from Modulation field.
        if(iscell(chs.Modulation))
            ncw = length(chs.Modulation);
        else
            ncw = 1;
        end
    end
        
    % Check for NLayers field.
    if (~isfield(chs,'NLayers'))
        error('lte:error','The function call (lteCQISelect) resulted in an error: Could not find a structure field NLayers'); 
    end
    
    % Check for CellRefP field.
    if (~isfield(enb,'CellRefP'))
        error('lte:error','The function call (lteCQISelect) resulted in an error: Could not find a structure field CellRefP'); 
    end
    
    if (strcmpi(chs.TxScheme,'Port7-14'))
        % Check for CSIRefP field.
        if (~isfield(enb,'CSIRefP'))
            error('lte:error','The function call (lteCQISelect) resulted in an error: Could not find a structure field CSIRefP'); 
        end
    end
        
    % Obtain CQI feedback related information; this involves a change of
    % the transmission scheme for the call to ltePMIInfo in the case of a
    % transmission scheme not supporting PMI, and a change of the PMIMode
    % to match the CQI feedback type.
    cqiTxScheme = chs.TxScheme;
    if (any(strcmpi(chs.TxScheme,{'Port0', 'TxDiversity', 'CDD'})))
        cqiTxScheme = 'SpatialMux';
    end
    cqiInfo=ltePMIInfo(enb,setfield(setfield(chs,'TxScheme',cqiTxScheme),'PMIMode',CQIMode)); %#ok<SFLD>
                    
    % Configure codebook restriction to current PMI only. Current PMI is
    % inferred (as 0) from transmission scheme if there is no choice of PMI
    % for that scheme. The size of the current PMI is validated against the
    % CSI reporting mode. The PMIMode for the call to ltePMISelect is also
    % determined; it is generally equal to CQIMode, but in the case of
    % subband PMI and wideband CQI it is set to PMIMode='Subband' in order
    % to obtain subband SINRs for the configured subband PMI and these
    % SINRs are averaged to produce a wideband SINR for CQI selection.
    PMIMode = CQIMode;
    if (any(strcmpi(chs.TxScheme,{'Port0', 'TxDiversity', 'CDD'})))
        chs.CodebookSubset = zeros(cqiInfo.NSubbands,1);
    else        
        % Check for PMISet field.
        if (~isfield(chs,'PMISet'))
            error('lte:error','The function call (lteCQISelect) resulted in an error: Could not find a structure field PMISet'); 
        end
        % Determine number of values for a PMISet of the current CQIMode.
        nPMIs = cqiInfo.NSubbands + length(cqiInfo.MaxPMI) - 1;        
        if (strcmpi(CQIMode,'Subband'))
            % For subband CQI:
            if (size(chs.PMISet,1)==nPMIs)
                % For subband current PMI, use PMISet directly.
                chs.CodebookSubset = chs.PMISet;                                
            else
                % For wideband current PMI, duplicate PMI values into
                % subband PMI. For incorrect PMI, error out.
                nPMIsWideband = length(cqiInfo.MaxPMI);
                if (size(chs.PMISet,1)~=nPMIsWideband)
                    error('lte:error','The function call (lteCQISelect) resulted in an error: the configured PMI set (containing %s) is inconsistent with the configured CSI reporting mode (''%s'', which expects %s).',describeEntries(size(chs.PMISet,1)),chs.CSIMode,describeEntries(nPMIsWideband))
                else
                    if (nPMIsWideband==1)
                        chs.CodebookSubset = repmat(chs.PMISet,cqiInfo.NSubbands,1);
                    else
                        chs.CodebookSubset = [chs.PMISet(1); repmat(chs.PMISet(2),cqiInfo.NSubbands,1)];
                    end
                end
            end
        else
            % For wideband CQI:
            if (size(chs.PMISet,1)==nPMIs)
                % For wideband current PMI, use PMISet directly.
                chs.CodebookSubset = chs.PMISet;
            else
                % For subband current PMI, use PMISet directly and allow
                % subband PMI selection to be performed. The resulting
                % subband SINRs will be averaged to give a wideband SINR
                % for CQI selection. For incorrect PMI, error out.
                PMIMode = 'Subband';
                pmiInfoSubband = ltePMIInfo(enb,setfield(chs,'PMIMode',PMIMode)); %#ok<SFLD>
                nPMIsSubband = pmiInfoSubband.NSubbands + length(pmiInfoSubband.MaxPMI) - 1;                 
                if (size(chs.PMISet,1)~=nPMIsSubband)
                    error('lte:error','The function call (lteCQISelect) resulted in an error: the configured PMI set (containing %s) is inconsistent with the configured CSI reporting mode (''%s'', which expects %s).',describeEntries(size(chs.PMISet,1)),chs.CSIMode,describeEntries(nPMIsSubband));
                else
                    chs.CodebookSubset = chs.PMISet;
                end
            end
        end
    end      
    
    % Perform PMI selection in order to obtain SINR estimates in each 
    % subband / layer for the current PMI set and CQI feedback type.    
    [~,~,~,subbandSINRs] = calculator.ltePMISelect(enb,setfield(setfield(chs,'TxScheme',cqiTxScheme),'PMIMode',PMIMode),hest,noiseest); %#ok<SFLD>
    if (strcmpi(PMIMode,'Subband') && strcmpi(CQIMode,'Wideband'));
        subbandSINRs = mean(subbandSINRs,1);
    end
       
    if (isempty(subbandSINRs))
        CQI = [];
        SINRs = [];
    else        
        % Note first wideband codebook index j=i1 for the case of 
        % i1/i2 precoders, otherwise j=0.
        if (length(cqiInfo.MaxPMI)==2)
            j = chs.CodebookSubset(1);
            offset = 1;
        else
            j = 0;
            offset = 0;
        end

        % Obtain SINR estimate in each subband / codeword by extracting SINR 
        % estimates according to configured PMISet and summing SINRs across 
        % demapped layers. 
        linearSINRs = zeros(cqiInfo.NSubbands,ncw);
        for i = 1:cqiInfo.NSubbands        
            layerSINRs = squeeze(subbandSINRs(i,j+1,chs.CodebookSubset(i+offset)+1,:));        
            codewordSINRs = cellfun(@sum,lteLayerDemap(layerSINRs.',ncw,'SpatialMux'));
            linearSINRs(i,:) = codewordSINRs;
        end         

        % Create wideband SINR values, the mean of the subband SINRs, if
        % subband CQI is configured.
        if (cqiInfo.NSubbands>1)
            linearSINRs = [mean(linearSINRs,1); linearSINRs];
        end

        % Calculate SINRs in deciBels.
        SINRs = 10*log10(linearSINRs);

        % Get SINR to CQI lookup.
        if (~isfield(chs,'SINRs90pc'))        
            SINRs90pc = sinrLookup(enb,chs);            
        else
            if(isa(chs.SINRs90pc,'function_handle'))
                nargs = nargin(chs.SINRs90pc);
                if ((nargs>=0 && nargs~=2) || nargs<-2)
                    if (nargs==1)
                        plural='';
                    else
                        plural='s';
                    end
                    if (nargs<0)
                        nargs = -nargs;
                        extra=' or more';
                    else
                        extra='';
                    end
                    error('lte:error','The function call (lteCQISelect) resulted in an error: if the parameter field SINRs90pc is a function handle, it must take 2 arguments. The function handle provided (%s) takes %d%s argument%s.',func2str(chs.SINRs90pc),nargs,extra,plural);
                end                
                if (nargout(chs.SINRs90pc)==0)
                    error('lte:error','The function call (lteCQISelect) resulted in an error: if the parameter field SINRs90pc is a function handle, it must produce at least one output.');
                end
                SINRs90pc = chs.SINRs90pc(enb,chs);                
            else
                SINRs90pc = chs.SINRs90pc;
            end
        end
        if (~isvector(SINRs90pc) || length(SINRs90pc)~=15)
            error('lte:error','The function call (lteCQISelect) resulted in an error: the parameter field SINRs90pc must be a vector of length 15, or a handle to a function f(ENB,CHS) that returns a vector of length 15.');
        end

        % Calculate CQI index for each SINR value.
        cqiIdx = arrayfun(@(x)cqiSelect(x,SINRs90pc),SINRs);

        % Creart CQI report.            
        if (strcmpi(chs.CSIMode,'PUCCH 1-1'))
            % Report wideband CQI for codeword 0.
            CQI = cqiIdx(1,1);
            if (ncw==2)
                % Report spatial differential CQI for codeword 1.
                [~,cqiOffset] = spatialDifferentialCQI(CQI-cqiIdx(1,2));
                CQI = [CQI; cqiOffset];
            end
        else    
            CQI = [];            
            for cw = 1:ncw                
                % Report wideband CQI for this codeword.
                CQI = [CQI; cqiIdx(1,cw)]; %#ok<AGROW>            
                if (strcmpi(CQIMode,'Subband'))            
                    % Report subband differential CQI for this codeword. 
                    [~,cqiOffsets] = arrayfun(@subbandDifferentialCQI,cqiIdx(2:end,cw)-cqiIdx(1,cw));                
                    CQI = [CQI; cqiOffsets]; %#ok<AGROW>
                end
            end

        end
    end
    
end

% Find biggest CQI that gives at least 90% throughput, or report CQI=0 if 
% CQI=1 fails to give 90%. 
function cqi = cqiSelect(SINR,SINRs90pc)
        
    cqi = find(SINRs90pc<SINR,1,'last');
    if (isempty(cqi))
        cqi = 0;
    end
    
end

% Calculate subband differential CQI value 'value' from subband
% differential CQI offset level 'offset' according to TS36.213 Table
% 7.2.1-2. The 'offset' output also returns the offset saturated to the
% range of reportable values.
function [value,offset] = subbandDifferentialCQI(offset)
    
    if (offset<0)
        value = 3;
        offset = -1;
    else
        if (offset>=2)
            value = 2;
            offset = 2;
        else
            value = offset;
        end
    end

end

% Calculate spatial differential CQI value 'value' from codeword 1 spatial
% differential offset level 'offset' according to TS36.213 Table 7.2-2. The
% 'offset' output also returns the offset saturated to the range of
% reportable values.
function [value,offset] = spatialDifferentialCQI(offset)

    if (offset<0)
        if (offset<=-4)
            value = 4;
            offset = -4;
        else
            value = offset + 8;
        end
    else
        if (offset>=3)
            value = 3;
            offset = 3;
        else
            value = offset;
        end
    end
        
end

% SINR breakpoints for 90% throughput based on the current configuration
% and the simulation assumptions described in the documentation.
function SINRs90pc = sinrLookup(~,chs)
    
    % Get first order polynomial coefficients for SINR to CQI lookup based
    % on the transmission scheme; the polynomials here were obtained from
    % simulations of the SINR required to achieve 90% throughput for CQI
    % indices 2...13.
    if (strcmpi(chs.TxScheme,'Port0'))
        p = [2.11 -9.24];
    elseif (strcmpi(chs.TxScheme,'TxDiversity'))
        p = [2.15 -8.44];
    elseif (strcmpi(chs.TxScheme,'CDD'))
        p = [2.73 -7.29];
    elseif (any(strcmpi(chs.TxScheme,{'SpatialMux','MultiUser'})))
        p = [2.64 -5.69];
    else
        % For UE-specific beamforming schemes 'Port5', 'Port7-8', 'Port8'
        % and 'Port7-14' the performance is dependent on the beamforming
        % used; the performance achieved with a single antenna port is
        % assumed here.
        p = [2.11 -9.24];
    end
    
    % Use the polynomial coefficients obtained above to provide SINR
    % breakpoints for CQI indices 1...15. For CQI indices 2...15 the values
    % are obtained directly from the polynomial. For CQI index 1 the
    % polynomial is evaluated at the point for CQI index 2: this gives a
    % better fit with the simulated performance for very low code rates, as
    % the MCS corresponding to CQI index 1 is generally the same as for CQI
    % index 2.
    SINRs90pc = polyval(p,[2 2:15]);       
    
end

function defaultValueWarning(field,value)
    s=warning('query','backtrace');
    warning off backtrace;        
    warning('lte:defaultValue','Using default value for parameter field %s (%s)',field,value);
    warning(s); 
end

function str = describeEntries(n)
    if (n==1)
        str = '1 entry';
    else
        str = sprintf('%d entries',n);
    end
end
