%ltePMIInfo Precoder matrix indication reporting information
%   INFO=ltePMIInfo(ENB,CHS) returns a structure INFO containing
%   information related to Precoder Matrix Indication (PMI) reporting (see
%   TS36.213 Section 7.2.4), in terms of the following fields:
%   k                  - Subband size in resource blocks (equal to NRB for
%                        wideband PMI reporting or transmission schemes
%                        without PMI reporting).
%   NSubbands          - Number of subbands for PMI reporting (equal to 1
%                        for wideband PMI reporting or transmission schemes
%                        without PMI reporting).
%   MaxPMI             - Indicates the maximum permitted PMI value for the 
%                        given configuration; valid PMI values range
%                        0...MaxPMI. For CSI reporting with CSIRefP=8,
%                        MaxPMI is a vector with 2 elements, indicating the
%                        maximum permissible value of i1 and i2, the first
%                        and second codebook indices. For transmission
%                        schemes without PMI reporting, MaxPMI=0.
%   CodebookSubsetSize - Indicates the size of the codebook subset
%                        restriction bitmap, used to restrict the values of 
%                        PMI that can be reported. For transmission schemes
%                        without PMI reporting, CodebookSubsetSize=0.
%
%   The input structure ENB must contain the following fields:
%   NDLRB      - Number of downlink resource blocks 
%   CellRefP   - Optional. Number of cell-specific reference signal antenna 
%                ports (1(default),2,4) 
%   Only required for 'Port7-14' transmission scheme below:
%      CSIRefP - Optional. Number of CSI-RS antenna ports 
%                (1(default),2,4,8)
%
%   The input structure CHS must contain the following fields:
%   PMIMode  - Optional. PMI reporting mode ('Wideband'(default),'Subband')
%   NLayers  - Optional. Number of transmission layers (1...8) (default 1)
%   TxScheme - Optional. Transmission scheme, one of:
%              'Port0'       - Single-antenna port, Port 0
%              'TxDiversity' - Transmit diversity scheme
%              'CDD'         - Large delay CDD scheme
%              'SpatialMux'  - Closed-loop spatial multiplexing scheme 
%                              (default)
%              'MultiUser'   - Multi-user MIMO scheme                                                                               
%              'Port5'       - Single-antenna port, Port 5
%              'Port7-8'     - Single-antenna port, port 7 (when 
%                              NLayers=1); Dual layer transmission, port 7 
%                              and 8 (when NLayers=2)
%              'Port8'       - Single-antenna port, Port 8
%              'Port7-14'    - Up to 8 layer transmission, ports 7-14
%
%   INFO.NSubbands can be used to determine the correct size of the vector
%   PMISet required for Closed-Loop Spatial Multiplexing operation; PMISet 
%   should be a column vector with INFO.NSubbands rows. For CSI reporting
%   with CSIRefP=8, INFO.NSubbands indicates the number of second codebook 
%   indices i2 in the report; first codebook index i1 is always chosen in
%   a wideband fashion therefore is a scalar. PMIMode='Wideband'
%   corresponds to PUSCH reporting Mode 1-2 or PUCCH reporting Mode 1-1
%   (PUCCH Report Type 2) and PMIMode='Subband' corresponds to PUSCH
%   reporting Mode 3-1.
%
%   Example:
%   The structure pmiInfo contains the PMI reporting information for RMC
%   R.13.
%
%   enb = lteRMCDL('R.13');
%   pmiInfo = ltePMIInfo(enb, enb.PDSCH)
%
%   The above example returns:
%                    k: 50
%            NSubbands: 1
%               MaxPMI: 15
%   CodebookSubsetSize: 16
%
%   See also ltePMISelect, ltePDSCH, ltePDSCHDecode, lteDLPrecode,
%   lteCSICodebook.

%   Copyright 2010-2014 The MathWorks, Inc.

function info = ltePMIInfo(enb,chs)
    
    % Check for NDLRB field.
    if (~isfield(enb,'NDLRB'))
        error('lte:error','The function call (ltePMIInfo) resulted in an error: Could not find a structure field NDLRB'); 
    end    
    % validate NDLRB.
    if (enb.NDLRB<6 || enb.NDLRB>110)
        error('lte:error','The function call (ltePMIInfo) resulted in an error: For the parameter field NDLRB, the value (%d) must be within the range [6,110]',enb.NDLRB);
    end
    
    % default CellRefP field if absent.
    if (~isfield(enb,'CellRefP'))
        enb.CellRefP=1;
        defaultValueWarning('CellRefP','1');        
    end               
    % validate CellRefP.
    if (isempty(find([1 2 4]==enb.CellRefP,1)))
        error('lte:error','The function call (ltePMIInfo) resulted in an error: For the parameter field CellRefP, the value (%d) is not one of the set (1, 2, 4)',enb.CellRefP);
    end 
    
    % default TxScheme field if absent.
    if (~isfield(chs,'TxScheme'))
        chs.TxScheme='SpatialMux';
        defaultValueWarning('TxScheme','SpatialMux');   
    end
    % validate TxScheme.
    if (~any(strcmpi(chs.TxScheme,{'CDD', 'SpatialMux', 'MultiUser', 'Port5', 'Port7-8', 'Port8', 'Port7-14'})))
        if (~any(strcmpi(chs.TxScheme,{'Port0', 'TxDiversity'})))
            error('lte:error','The function call (ltePMIInfo) resulted in an error: For the parameter field TxScheme, (%s) is not one of the set (Port0, TxDiversity, CDD, SpatialMux, MultiUser, Port5, Port7-8, Port8, Port7-14)',chs.TxScheme);
        else
            info.k = enb.NDLRB;
            info.NSubbands = 1;
            info.MaxPMI = 0;
            info.CodebookSubsetSize = 0;
        end
    else
        
        % default PMIMode field if absent.
        if (~isfield(chs,'PMIMode'))
            chs.PMIMode='Wideband';
            defaultValueWarning('PMIMode','Wideband');            
        end
        % validate PMIMode.
        if (~any(strcmpi(chs.PMIMode,{'Wideband','Subband'})))            
            error('lte:error','The function call (ltePMIInfo) resulted in an error: For the parameter field PMIMode, (%s) is not one of the set (Wideband, Subband)',chs.PMIMode);
        end

        % default NLayers field if absent. 
        if (~isfield(chs,'NLayers'))
            chs.NLayers=1; 
            defaultValueWarning('NLayers','1');
        end   
        % validate NLayers.
        if (chs.NLayers<1 || chs.NLayers>8)
            error('lte:error','The function call (ltePMIInfo) resulted in an error: For the parameter field NLayers, the value (%d) must be within the range [1,8]',chs.NLayers);
        end               
        if (strcmpi(chs.TxScheme,'Port7-8') && chs.NLayers>2)
            error('lte:error','The function call (ltePMIInfo) resulted in an error: For the Port7-8 transmission scheme, the parameter field NLayers (%d) must be either 1 or 2',chs.NLayers);
        end
        
        if (strcmpi(chs.PMIMode,'Wideband'))
            info.k=enb.NDLRB;
            info.NSubbands=1;
        else
            if (enb.NDLRB>63)
                info.k=8;
            elseif (enb.NDLRB>26)
                info.k=6;
            elseif (enb.NDLRB>7)
                info.k=4;
            else
                info.k=1;
            end
            info.NSubbands=ceil(enb.NDLRB/info.k);   
        end               

        % default CSIRefP field if absent.
        if (~isfield(enb,'CSIRefP'))
            enb.CSIRefP=1;
            if (strcmpi(chs.TxScheme,'Port7-14'))                    
                defaultValueWarning('CSIRefP','1');        
            end
        end
        % validate CSIRefP.
        if (isempty(find([1 2 4 8]==enb.CSIRefP,1)))
            error('lte:error','The function call (ltePMIInfo) resulted in an error: For the parameter field CSIRefP, the value (%d) is not one of the set (1, 2, 4, 8)',enb.CSIRefP);
        end

        if (strcmpi(chs.TxScheme,'CDD'))
            info.MaxPMI = 0;
        elseif (~strcmpi(chs.TxScheme,'Port7-14') || enb.CSIRefP~=8)
            if (strcmpi(chs.TxScheme,'Port7-14'))
                P=enb.CSIRefP;
            else
                P=enb.CellRefP;
            end
            if (chs.NLayers==2 && P==2)
                info.MaxPMI=1;
            else
                if (P==1)
                    info.MaxPMI=0;
                else
                    info.MaxPMI=(2^P)-1;
                end
            end    
        else
            maxi1=[15 15  3  3  3  3  3  0];
            maxi2=[15 15 15  7  0  0  0  0];
            info.MaxPMI=[maxi1(chs.NLayers) maxi2(chs.NLayers)];
        end
        
        info.CodebookSubsetSize = codebookSubsetBitmapSize(enb,chs);
        
    end
    
end

function defaultValueWarning(field,value)
    s=warning('query','backtrace');
    warning off backtrace;        
    warning('lte:defaultValue','Using default value for parameter field %s (%s)',field,value);
    warning(s); 
end

% obtain codebook subset restriction bitmap size A_c for the given
% configuration (implements TS36.213 Table 7.2-1b)
function A_c = codebookSubsetBitmapSize(enb,chs)

    A_c=0;

    if (strcmpi(chs.TxScheme,'CDD'))
        if (enb.CellRefP==2)
            A_c = 2;
        elseif (enb.CellRefP==4)
            A_c = 4;
        end
    end
    
    if (strcmpi(chs.TxScheme,'SpatialMux') && chs.NLayers>1)
        if (enb.CellRefP==2)
            A_c = 6;
        elseif (enb.CellRefP==4)
            A_c = 64;
        end
    end
    
    if ((strcmpi(chs.TxScheme,'SpatialMux') && chs.NLayers==1) || strcmpi(chs.TxScheme,'MultiUser'))
        if (enb.CellRefP==2)
            A_c = 4;
        elseif (enb.CellRefP==4)
            A_c = 16;
        end
    end
    
    if (any(strcmpi(chs.TxScheme,{'Port7-8','Port8'})))
        if (enb.CellRefP==2)
            A_c = 6;
        elseif (enb.CellRefP==4)
            A_c = 32;
        end
    end
    
    if (strcmpi(chs.TxScheme,'Port7-14'))
        if (enb.CSIRefP==2)
            A_c = 6;
        elseif (enb.CSIRefP==4)
            A_c = 64;
        elseif (enb.CSIRefP==8)
            A_c = 109;
        end
    end

end
