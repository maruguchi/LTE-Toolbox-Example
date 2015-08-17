%ltePMISelect PDSCH precoder matrix indicator calculation
%   [PMISET,INFO,SINRS,SUBBANDSINRS]=ltePMISelect(ENB,CHS,HEST,NOISEEST)
%   performs PDSCH Precoder Matrix Indication (PMI) set calculation for
%   given cell-wide settings ENB, channel configuration structure CHS,
%   channel estimate resource array HEST and receiver noise variance
%   NOISEEST.
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
%   NLayers        - Number of transmission layers (1...8)
%   PMIMode        - Optional. PMI reporting mode 
%                    ('Wideband'(default),'Subband')
%   TxScheme       - Optional. Transmission scheme, one of:
%                    'Port0'       - Single-antenna port, Port 0
%                    'TxDiversity' - Transmit diversity scheme
%                    'CDD'         - Large delay CDD scheme
%                    'SpatialMux'  - Closed-loop spatial multiplexing 
%                                    scheme (default)
%                    'MultiUser'   - Multi-user MIMO scheme      
%                    'Port5'       - Single-antenna port, Port 5
%                    'Port7-8'     - Single-antenna port, port 7 (when 
%                                    NLayers=1); Dual layer transmission, 
%                                    port 7 and 8 (when NLayers=2)
%                    'Port8'       - Single-antenna port, Port 8
%                    'Port7-14'    - Up to 8 layer transmission, ports 7-14
%   CodebookSubset - Optional. String bitmap (default all ones, permitting 
%                    all PMI values) specifying the codebook subset
%                    restriction. It is configured by higher layers, and it
%                    indicates the values of PMI that can be reported. The
%                    bitmap, defined in TS36.213 Section 7.2, is arranged
%                    a_A-1,a_A-2,...a_0 from left to right as the string is
%                    viewed i.e. the element CodebookSubset(1) corresponds
%                    to a_A-1 and the element CodebookSubset(end)
%                    corresponds to a_0. The length of the bitmap is given
%                    by the INFO.CodebookSubsetSize field returned by 
%                    <a href="matlab: help('ltePMIInfo')"
%                    >ltePMIInfo</a>. The bitmap may also be specified in a
%                    hexadecimal form by prefixing the string with '0x'.
%                    Alternatively, a numeric array of the same form as the
%                    PMISET output can be provided, indicating that the
%                    selection should be restricted to only those values;
%                    this is useful for obtaining SINR estimates against an
%                    existing reported PMI for the purposes of RI and CQI
%                    selection. Note that if this parameter field is
%                    defined but is empty, no codebook subset restriction
%                    is applied. (codebookSubsetRestriction)
%
%   HEST is a multidimensional array of size K-by-L-by-NRxAnts-by-P, where
%   K is the number of subcarriers, L is the number of OFDM symbols,
%   NRxAnts is the number of receive antennas and P is the number of
%   transmit antennas.
%
%   NOISEEST is a scalar, an estimate of the received noise power spectral
%   density.
%
%   INFO is a structure containing information related to PMI reporting, as
%   described for the <a href="matlab:
%   help('ltePMIInfo')">ltePMIInfo</a> function.
%   
%   The PMI selection will be performed using the codebooks specified in
%   TS36.213 Section 7.2.4. For the 'Port7-14' transmission scheme, the CSI
%   reporting codebook is used when the number of CSI-RS ports is 8; for
%   other numbers of CSI-RS ports in the 'Port7-14' transmission scheme and
%   for other transmission schemes the PMI selection will be performed
%   using the codebook for Closed-Loop Spatial Multiplexing defined in
%   TS36.211 Tables 6.3.4.2.3-1 and 6.3.4.2.3-2. PMIMode='Wideband'
%   corresponds to PUSCH reporting Mode 1-2 or PUCCH reporting Mode 1-1
%   (PUCCH Report Type 2) and PMIMode='Subband' corresponds to PUSCH
%   reporting Mode 3-1. PMI selection will be conditioned on the rank
%   indicated by CHS.NLayers, except for the 'TxDiversity' transmission
%   scheme where the rank is 1. Note that in PUCCH reporting Mode 1-1,
%   codebook subsampling for submode 2 (TS36.213 Table 7.2.2-1D) can be
%   achieved with an appropriate CHS.CodebookSubset.
%
%   PMISET is a column vector, containing the Precoder Matrix Indications
%   (PMI set) selected. The returned PMISET can be used to configure the
%   PMI for a downlink transmission, for example using <a href="matlab: 
%   help('lteRMCDLTool')">lteRMCDLTool</a> or 
%   <a href="matlab: help('ltePDSCH')"
%   >ltePDSCH</a>. For the 'Port7-14' transmission scheme with 8 CSI-RS 
%   ports, PMISET has INFO.NSubbands+1 rows; the first row indicates
%   wideband codebook index i1 and the subsequent INFO.NSubbands rows
%   indicate the subband codebook indices i2 or wideband codebook index i2
%   (if INFO.NSubbands=1). For other numbers of CSI-RS ports in the
%   'Port7-14' transmission scheme and for other transmission schemes,
%   PMISET has INFO.NSubbands rows, each row giving the subband codebook
%   index for that subband; or for wideband reporting (INFO.NSubbands=1),
%   PMISET is a scalar specifying the selected wideband codebook index.
%   Note that PMISET will be empty if the noise estimate NOISEEST is zero
%   or NaN, or if the channel estimate HEST contains any NaNs in the
%   locations of the reference signal REs used for PMI estimation.
%
%   SINRS is a multi-dimensional array of size K-by-L-by-N1-by-N2 where K
%   is the number of subcarriers, L is the number of OFDM symbols. For the
%   'Port7-14' transmission scheme with 8 CSI-RS ports, N1 is
%   INFO.MaxPMI(1)+1 and N2 is INFO.MaxPMI(2)+1, i.e. the number of
%   possible first and second codebook indices respectively. For other
%   numbers of CSI-RS ports in the 'Port7-14' transmission scheme and for
%   other transmission schemes, N1 is 1 and N2 is INFO.MaxPMI+1, the number
%   of possible codebook indices. The array contains non-NaN values in the
%   time/frequency locations (first two dimensions) of the reference signal
%   REs used for PMI estimation, for all possible codebook indices (last
%   two dimensions). These values are the calculated linear SINRs in the
%   reference signal RE locations for each codebook index combination, and
%   are obtained using a linear MMSE SINR metric. All locations not
%   corresponding to a reference signal RE are set to NaN.
%
%   SUBBANDSINRS is a multi-dimensional array of size
%   INFO.NSubbands-by-N1-by-N2-by-CHS.NLayers, indicating the average
%   linear SINR in the subband specified for each possible PMI value (N1/N2
%   dimensions) and each layer. The SINRS output above is formed by summing
%   a 5-dimensional K-by-L-by-N1-by-N2-by-chs.NLayers estimate of the SINRs
%   across all of the layers (5th dimension). SUBBANDSINRS is formed by
%   averaging that same 5-dimensional estimate across each subband (i.e. in
%   the appropriate region of the K dimension and across the L dimension).
%
%   Example:
%   An empty resource grid for RMC R.13 is populated with cell-specific
%   reference signal symbols. The waveform is passed through the channel
%   and demodulated. Estimates of the channel and noise power spectral
%   density are used for PMI selction. This PMI set is the used to
%   configure a downlink transmission. 
%
%   enb = lteRMCDL('R.13');
%   enb.PDSCH.PMIMode = 'Subband';
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
%   pmi = ltePMISelect(enb,enb.PDSCH,hest,noiseEst)
%   enb.PDSCH.PMISet = pmi; % configure transmitter PMI
%   txWaveform = lteRMCDLTool(enb,[1;0;0;1]);
%
%   See also ltePDSCH, ltePDSCHDecode, lteDLPrecode, ltePMIInfo,
%   lteCSICodebook, lteCQISelect, lteRISelect. 

%   Copyright 2010-2014 The MathWorks, Inc.

function [PMISet,info,SINRs,subbandSINRs] = ltePMISelect(enb,chs,hest,noiseest)
    
    % validate hest.
    if (ischar(hest) || iscell(hest) || isa(hest,'function_handle') || isstruct(hest))
        error('lte:error','The function call (ltePMISelect) resulted in an error: channel estimate input must be a multidimensional array of size K-by-L-by-NRxAnts-by-P, where K is the number of subcarriers, L is the number of OFDM symbols, NRxAnts is the number of receive antennas and P is the number of transmit antennas.');
    end
    
    % dimension information related to channel estimate.
    % K: number of subcarriers
    % L: number of symbols
    % R: number of receive antennas
    K = size(hest,1);
    L = size(hest,2);    
    R = size(hest,3);
    
    % validate noiseest.
    if (~isscalar(noiseest) || ischar(noiseest) || iscell(noiseest) || isa(noiseest,'function_handle') || isstruct(noiseest))
       error('lte:error','The function call (ltePMISelect) resulted in an error: noise estimate input must be a scalar numerical value.');
    end
    
    % default TxScheme field if absent.
    if (~isfield(chs,'TxScheme'))
        chs.TxScheme='SpatialMux';
        defaultValueWarning('TxScheme','SpatialMux');   
    end    
    
    % validate NLayers.
    if (~isfield(chs,'NLayers'))
        error('lte:error','The function call (ltePMISelect) resulted in an error: Could not find a structure field NLayers');
    else
        if (chs.NLayers<1 || chs.NLayers>8)
            error('lte:error','The function call (ltePMISelect) resulted in an error: For the parameter field NLayers, the value (%d) must be within the range [1,8]',chs.NLayers);
        end
    end
    
    % default CyclicPrefix if absent.    
    if (~isfield(enb,'CyclicPrefix'))
        enb.CyclicPrefix='Normal'; 
        defaultValueWarning('CyclicPrefix','Normal');
    end
    
    % default PMIMode field if absent.
    if (~isfield(chs,'PMIMode'))
        chs.PMIMode='Wideband';
        defaultValueWarning('PMIMode','Wideband');            
    end
        
    % PMI feedback related information.
    info = ltePMIInfo(enb,chs);
        
    % default CodebookSubset if absent.
    cssize = info.CodebookSubsetSize;
    nibbles = ceil(cssize/4);
    if (~isfield(chs,'CodebookSubset'))        
        bitmap = char(ones(1,cssize)+'0');        
        if (cssize>=64)
            % convert long bitmaps to hexadecimal representation            
            bitmap = [char(zeros(1,nibbles*4-cssize)+'0') bitmap];
            bitmap = ['0x' dec2hex(bin2dec(reshape(bitmap,4,nibbles).')).'];            
        end
        chs.CodebookSubset = bitmap; 
        defaultValueWarning('CodebookSubset',chs.CodebookSubset);   
    end
    
    % If CodebookSubset is in hexadecimal form, convert to binary form.
    if (length(chs.CodebookSubset)>2)
        if (strcmpi(chs.CodebookSubset(1:2),'0x'))
            bitmap = chs.CodebookSubset(3:end);
            bitmap = arrayfun(@(x)(dec2bin(hex2dec(x),4)),bitmap,'UniformOutput',false);
            bitmap = [bitmap{:}];                            
            % trim leading zeros if the configured hexadecimal string
            % contains the right number of digits
            if ((length(bitmap) == nibbles*4) || (length(bitmap)==4 && nibbles==0))         
                bitmap = bitmap((end-cssize+1):end);
            end
            chs.CodebookSubset = bitmap;
        end
    end    
    
    % Adjust for the difference in expected codebook subset sizes for
    % transmission modes 4 and 6 (spatial multiplexing and spatial
    % multiplexing with 1 layer) - both are signalled with
    % TxScheme='SpatialMux' and are distinguished by chs.NLayers. This
    % adjustment is required for the case where rank selection is
    % performed (across all numbers of layers) and a non-default codebook
    % subset is provided. 
    if (strcmpi(chs.TxScheme,'SpatialMux') && ischar(chs.CodebookSubset))
        if (chs.NLayers==1)      
            if (length(chs.CodebookSubset)>cssize)
                chs.CodebookSubset = chs.CodebookSubset((end-cssize+1):end);
            end
        else                        
            if (length(chs.CodebookSubset)<cssize)
                bitmap = char(ones(1,cssize)+'0');
                bitmap((end-length(chs.CodebookSubset)+1):end) = chs.CodebookSubset;
                chs.CodebookSubset = bitmap;
            end
        end
    end
    
    % further validation on hest size.
    dims = lteResourceGridSize(enb,1);
    if (K~=dims(1) || L~=dims(2))
        error('lte:error','The function call (ltePMISelect) resulted in an error: the first and second dimension sizes of the channel estimate input (%d-by-%d) do not match those expected for the current configuration (%d-by-%d).',K,L,dims(1),dims(2));
    end
    
    % Choose reference signal locations according to transmission scheme
    if (strcmpi(chs.TxScheme,'Port7-14'))
        % Default CSIRSPeriod field if absent.
        if (~isfield(enb,'CSIRSPeriod'))
            enb.CSIRSPeriod='On';
            defaultValueWarning('CSIRSPeriod','On');   
        end  
        % Default NFrame field if absent.
        if (~isfield(enb,'NFrame'))
            enb.NFrame=0;
            defaultValueWarning('NFrame','0');   
        end  
        % Switch off Zero Power CSI-RS as we do not need those REs here; we
        % only estimate from the active CSI-RS. 
        enb.ZeroPowerCSIRSPeriod = 'Off';        
        % 'subs' are subscripts of REs for CSI RS port 7, giving a
        % subsampling of RE positions in the subframe for which to measure
        % SINR.
        subs=lteCSIRSIndices(enb,'sub');
        CsiRS = lteCSIRS(enb);
        subs=subs(subs(:,3)==1,:);        
        CsiRS = CsiRS(:,1);
        subs(CsiRS==0,:)=[];
        % remove half of subs as there are two adjacent symbols with the 
        % same frequency locations
        subs(1:(size(subs,1)/2),:)=[];
    else
        % 'subs' are subscripts of REs for cell RS port 0, giving a
        % subsampling of RE positions in the subframe for which to measure
        % SINR.
        subs=lteCellRSIndices(enb,0,'sub');        
    end
    subs=subs(:,1:2);
    
    % 'SINRs' is 4-D K-by-L-by-N1-N2 where N1 and N2 are the number of
    % valid second and first codebook entries respectively for given setup.
    % For CRS, N1=1; for CSI-RS, N1 may be 1 or more.
    SINRs=[];    
    
    if (isempty(subs))        
        PMISet=[];        
    else                
        
        % Configure number of antennas according to transmission scheme.
        if (strcmpi(chs.TxScheme,'Port7-14'))
            P=enb.CSIRefP;
        else
            P=enb.CellRefP;
        end                
        
        % Use PMI dims to establish maximum PMI index.
        chs.minCodebookIdx=0;    
        chs.maxCodebookIdx=info.MaxPMI;
    
        % Normalise max index up to 2 elements (1 element is produced for 
        % selection against CRS, 2 elements for CSI-RS). 
        if (length(chs.maxCodebookIdx)==1)
            chs.maxCodebookIdx=[0 chs.maxCodebookIdx];
        end
    
        % Codebook subset restriction for 2-antenna, 2-layer spatial 
        % multiplexing.
        if (chs.NLayers==2 && P==2 && any(strcmpi(chs.TxScheme,{'SpatialMux','Port7-8','Port8','Port7-14'})))
            chs.minCodebookIdx=chs.minCodebookIdx+1;
            chs.maxCodebookIdx=chs.maxCodebookIdx+1;    
        end
       
        % Configure codebook ranges. For the 'Port7-14' transmission scheme
        % with 8 CSI-RS ports, codebookRange1 corresponds to precoder
        % indices i1 and codebookRange2 corresponds to precoder indices i2.
        % For other numbers of CSI-RS ports in the 'Port7-14' transmission
        % scheme and for other transmission schemes, codebookRange1 is
        % unused (set to 0) and codebookRange2 corresponds to the precoder
        % indices. 
        if (~ischar(chs.CodebookSubset))
            % For a non-string CodebookSubset, validate it as a column
            % vector corresponding to a PMISet. 
            if (~iscolumn(chs.CodebookSubset) || isstruct(chs.CodebookSubset) || isa(chs.CodebookSubset,'function_handle'))
                error('lte:error','The function call (ltePMISelect) resulted in an error: codebook subset must be a string or a column vector.');
            end
            % Determine number of values for a PMISet of the current PMIMode.        
            if (length(info.MaxPMI)==2)
                nPMIs = info.NSubbands + 1;
            else
                nPMIs = info.NSubbands;
            end
            % Validate the CodebookSubset vector. 
            if (size(chs.CodebookSubset,1)~=nPMIs)                
                error('lte:error','The function call (ltePMISelect) resulted in an error: the configured codebook subset ([%s], containing %s) is inconsistent with the configured PMI reporting mode (''%s'', which expects %s).',num2str(chs.CodebookSubset.'),describeEntries(size(chs.CodebookSubset,1)),chs.PMIMode,describeEntries(nPMIs));
            end                
            % Configure codebook ranges based on the CodebookSubset values.
            if (length(info.MaxPMI)==2)
                chs.codebookRange1=chs.CodebookSubset(1);
                chs.codebookRange2=unique(chs.CodebookSubset(2:end).');
                if (chs.codebookRange1<chs.minCodebookIdx || chs.codebookRange1>chs.maxCodebookIdx(1))
                    error('lte:error','The function call (ltePMISelect) resulted in an error: the first element of the configured codebook subset (%s) is outside of the valid range [%s,%s].',num2str(chs.CodebookSubset(1)),num2str(chs.minCodebookIdx),num2str(chs.maxCodebookIdx(1)));
                end
            else
                chs.codebookRange1=chs.minCodebookIdx;
                chs.codebookRange2=unique(chs.CodebookSubset(1:end).') + chs.minCodebookIdx;            
            end            
            if (any(chs.codebookRange2<chs.minCodebookIdx) || any(chs.codebookRange2>chs.maxCodebookIdx(2)))
                error('lte:error','The function call (ltePMISelect) resulted in an error: the configured codebook subset ([%s]) contains values outside of the valid range [%s,%s].',num2str(chs.CodebookSubset.'),num2str(chs.minCodebookIdx),num2str(chs.maxCodebookIdx(2)));   
            end
        else        
            % For a string CodebookSubset, the codebook range is as defined
            % by the PMI info, and restriction is performed later using the
            % restricted() function. 
            chs.codebookRange1=chs.minCodebookIdx:chs.maxCodebookIdx(1);            
            chs.codebookRange2=chs.minCodebookIdx:chs.maxCodebookIdx(2);
            
            % Validate the CodebookSubset string.
            if (length(chs.CodebookSubset)~=cssize)                
                error ('lte:error','The function call (ltePMISelect) resulted in an error: the configured codebook subset (''%s'', containing %s) is inconsistent with the configured transmission scheme / number of antenna ports (which expects %s).',chs.CodebookSubset,describeEntries(length(chs.CodebookSubset)),describeEntries(cssize));
            end
        end

        % Early check to see if codebook subset restriction results in no
        % valid precoder entries.
        minIdx=chs.minCodebookIdx;
        N1 = chs.maxCodebookIdx(1)-minIdx+1;
        N2 = chs.maxCodebookIdx(2)-minIdx+1;
        % for all second codebook indices:
        restricted = ones(N1,N2);
        for i=chs.codebookRange2        
            % for all first codebook indices (only j=0 against CRS):
            for j=chs.codebookRange1                       
                restricted(j-minIdx+1,i-minIdx+1) = isrestricted(enb,chs,i,j);                
            end
        end
        
        % If there are no valid precoder entries, clear 'subs' in order to
        % just run through the sizing logic below, but not make unnecessary
        % SINR calculations.
        if (all(restricted))
             subs = [];
         end
        
        % Calculate SINR metric for each RE in 'subs', for each valid
        % codebook entry for all transmission layers and enter results for
        % each codebook entry into corresponding (subcarrier,symbol)
        % location in 'SINRs'.        
        SINRs=zeros(K,L,N1,N2);
        layerSINRs=zeros(K,L,N1,N2,chs.NLayers);
        for i=1:size(subs,1)
            k=subs(i,1);
            l=subs(i,2);    
            H = reshape(squeeze(hest(k,l,:,:)),R,size(hest,4));
            layerSINR=codebookSelection(chs,H,P,sqrt(noiseest),restricted);   
            SINR=sum(layerSINR,3);            
            for n1=1:N1
                SINRs(k,l,n1,:)=SINR(n1,:);
                layerSINRs(k,l,n1,:,:)=layerSINR(n1,:,:); 
            end
        end

        % 'PMISet' is the set of codebook entries to be used in subsequent
        % transmission.
        PMISet=zeros(info.NSubbands,2);
        
        % For 'Port7-14' transmission scheme with 8 CSI-RS ports: 
        % Control to enable/disable subband reporting on i1 if
        % config.PMIMode='Subband'. Note that under wideband_i1=false, the
        % final output of this function will still reduce i1 to a single
        % report, using the 'mode' function to chose the most common i1
        % value, in order that the output dimensionality described in the
        % help is adhered to. For compliance with CSI reporting Mode 1-2,
        % wideband_i1=true must be set.
        wideband_i1=true;
        
        if (wideband_i1)
            % wideband part        
            totalSINR=squeeze(sum(sum(SINRs)));
            totalSINR=reshape(totalSINR,N1,N2);
            best1=find(max(totalSINR,[],2)==max(max(totalSINR,[],2)));
            if (~isempty(best1))
                best1=best1(1);
            end
        end
        
        % For each subband (only 1 if not using subband PMI mode)        
        for i=0:info.NSubbands-1

            % Select region of subcarriers in that subband         
            start=(i*info.k*12)+1;
            finish=min([enb.NDLRB (i+1)*info.k])*12;

            % extract the codebook entry that has the best overall SINR in 
            % that region and return as the PMI for that subband
            subbandSINR=squeeze(sum(sum(SINRs(start:finish,:,:,:))));
            SINRallPMI=sum(sum(SINRs,4),3);
            contributions=sum(sum(SINRallPMI(start:finish,:)~=0));
            if (contributions~=0)
                subbandSINR=subbandSINR/contributions;
            end            
            subbandSINR=reshape(subbandSINR,N1,N2);            
            if (wideband_i1)
                best2=find(subbandSINR(best1,:)==max(subbandSINR(best1,:)));
            % else
            %     [best1,best2]=find(subbandSINR==max(subbandSINR(:))); 
            end
            if (~isempty(best2))
                PMISet(i+1,:)=[best1(1) best2(1)]-1;
            else
                PMISet=[];                
                break;
            end
            
        end               
        
    end
                        
    % If only one precoder index (per subband) is to be reported, remove
    % the "first" precoder index which will have a value of zero as this
    % dimension is not selectable under this transmission scheme / number
    % of CSI-RS ports; otherwise return a single (wideband) first precoder
    % index followed by the subband or wideband second precoder indices or
    % index.
    if (~isempty(PMISet))        
        if (length(info.MaxPMI)==1)
            PMISet=PMISet(:,2);
        else
            PMISet=[mode(PMISet(:,1)); PMISet(:,2)];
        end                     
    end
                        
    % Go back and get subband SINRs per layer. 
    if (~isempty(PMISet))
        
        subbandSINRs=zeros(info.NSubbands,N1,N2,chs.NLayers);
        for i=0:info.NSubbands-1

            start=(i*info.k*12)+1;
            finish=min([enb.NDLRB (i+1)*info.k])*12;

            subbandSINR=squeeze(sum(sum(layerSINRs(start:finish,:,:,:,:))));
            SINRallPMI=sum(sum(sum(layerSINRs,5),4),3);
            contributions=sum(sum(SINRallPMI(start:finish,:)~=0));
            if (contributions~=0)
                subbandSINR=subbandSINR/contributions;
            end            
            subbandSINRs(i+1,:,:,:)=reshape(subbandSINR,N1,N2,chs.NLayers);            

        end
        
    else
        subbandSINRs = [];
    end
    
    % NaN out any unused locations in SINRs.
    SINRs(SINRs==0)=NaN;
    
end

% Perform codebook selection using LMMSE SINR metric
function gamma = codebookSelection(chs,H,P,sigma,restricted)
    
    % configure SINR metric output storage.
    minIdx=chs.minCodebookIdx;
    gamma=zeros(chs.maxCodebookIdx(1)-minIdx+1,chs.maxCodebookIdx(2)-minIdx+1,chs.NLayers);    

    % for all second codebook indices:
    for i=chs.codebookRange2
        
        % for all first codebook indices (only j=0 against CRS):
        for j=chs.codebookRange1
       
            % if this codebook index is not restricted by the codebook
            % restriction
            if (~restricted(j-minIdx+1,i-minIdx+1))
                
                % choose codebook entry according to transmission scheme.
                if (strcmpi(chs.TxScheme,'SpatialMux'))
                    W=codebookEntryCRS(P,chs.NLayers,i);
                else
                    W=codebookEntryCSIRS(P,chs.NLayers,j,i);
                end

                % calculate SINR metric.
                den=sigma^2*inv((W'*H')*H*W+(sigma^2*eye(chs.NLayers))); %#ok<MINV>                
                gamma(j-minIdx+1,i-minIdx+1,:)=real((1./diag(den))-1);
                
            end
            
        end
        
    end

end

% Obtain a single codebook entry from CRS codebook
function W = codebookEntryCRS(P,nu,i)

    if (P==1)
        W=1;
    else
        W = lteDLPrecode(eye(nu),P,'SpatialMux',i).';    
    end
    
end

% Obtain a single codebook entry from CSI-RS codebook
function W = codebookEntryCSIRS(P,nu,i1,i2)
    
    if (P==1)
        W=1;
    else
        W = lteCSICodebook(nu,P,i1,i2);
    end
    
end

function defaultValueWarning(field,value)
    s=warning('query','backtrace');
    warning off backtrace;        
    warning('lte:defaultValue','Using default value for parameter field %s (%s)',field,value);
    warning(s); 
end

% Indicates if a given codebook entry (i,j) is restricted under the
% codebook subset restriction bitmap given by config.CodebookSubset. Note
% that for the case of the 'Port7-14' scheme with 8 antenna ports, 'i' is 
% the second codebook index and 'j' is the first; for all other cases, 'i'
% is the codebook index and j=0. 
function r = isrestricted(enb,chs,i,j)
    
    if (~ischar(chs.CodebookSubset) || isempty(chs.CodebookSubset))
        
        r=0;
        
    else
        
        n=0;

        if (strcmpi(chs.TxScheme,'CDD'))            
            if (enb.CellRefP==2)
                n = 1;
            else
                n = chs.NLayers-1;
            end
        elseif (strcmpi(chs.TxScheme,'SpatialMux') && chs.NLayers>1)
            if (enb.CellRefP==2)
                n = 3 + i;
            else
                n = 16*(chs.NLayers-1) + i;
            end
        elseif ((strcmpi(chs.TxScheme,'SpatialMux') && chs.NLayers==1) || strcmpi(chs.TxScheme,'MultiUser'))
            if (enb.CellRefP==2)
                n = i;
            else
                n = i;
            end
        elseif (any(strcmpi(chs.TxScheme,{'Port7-8','Port8'})))
            if (enb.CellRefP==2)
                if (chs.NLayers==1)
                    n = i;
                else
                    n = 3 + i;
                end
            else
                n = 16*(chs.NLayers-1) + i;
            end
        elseif (strcmpi(chs.TxScheme,'Port7-14'))
            if (enb.CSIRefP==2)
                if (chs.NLayers==1)
                    n = i;
                else
                    n = 3 + i;
                end 
            elseif (enb.CSIRefP==4)
                n = 16*(chs.NLayers-1) + i; 
            else
                f1 = [0 16 32 36 40 44 48 52];
                g1 = [0 16 32 48];
                n(1) = f1(chs.NLayers) + j;
                if (chs.NLayers <= 4)
                    n(2) = 53 + g1(chs.NLayers) + i;
                end
            end
        end

        r = any(double(chs.CodebookSubset(end-n)-'0')==0);
        
    end
          
end

function str = describeEntries(n)
    if (n==1)
        str = '1 entry';
    else
        str = sprintf('%d entries',n);
    end
end
