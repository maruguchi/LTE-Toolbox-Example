clear;

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
enb.CFI = 3;                    % Control format indicator (CFI) value: 1,2 or 3


% PDCCH format;
cceBits = [1,2,4,8];

TotFrame = 100;

SNRmin = -10;
SNRmax = 5;
SNRpad = 1-SNRmin;


waitBar = waitbar(0,'Start Calculating ....');
progress = 0;
done = (SNRmax-SNRmin+1)*(TotFrame+1);

iformat = 2;
for isnr = SNRmin:SNRmax
    pdcchBitsFull = [];
    pdcchRxHardBitsFull = [];
    convBitsFull = [];
    convRxBitsFull = [];
    crcBitsFull = [];
    crcRxBitsFull = [];
    dciBitsFull = [];
    dciRxBitsFull = [];
    for i = 1:TotFrame
        
        progress = progress + 1;
        waitbar(progress/done,waitBar,['Calculating for SNR = ',num2str(isnr)]);
        
        
        %% DCI bits
        istr = struct('DCIFormat','Format1A','AllocationType',1);
        [ ~, dciBits ] = lteDCI(enb,istr);
       
        
        %% Manual PDCCH symbol generation
        
        % add 16 bit CRC
        crcBits = lteCRCEncode(dciBits,'16');
        % berform 1/3 convolutional coding
        convBits = lteConvolutionalEncode(crcBits);
                
        % rate match according PDCCH format
        % format 0,1,2,3 for CCE agg 1,2,4 or 8 (72 bit each CCE)
                
        pdcchBits = lteRateMatchConvolutional(convBits,cceBits(iformat)*72);
        
        % map PDCCH Bit to to PDCCH Space
        pdcchInfo = ltePDCCHInfo(enb);                                   % Get the total resources for PDCCH
        pdcchSpace = ones(pdcchInfo.MTot, 1);                         % Initialized with -1
        pdcchSpace(1:cceBits(iformat)*72) = pdcchBits;
                
        % modulate QPSK before adding to resource grid
        pdcchSyms = lteSymbolModulate(pdcchSpace,'QPSK');
        
        
        %% Matlab PBCH symbol generation
        
        % this code is to verify manual mode
        % note that manual mode doesn't include bits scrambling according to NCell
        %
        % % Matlab LTE Toolbox to generate BCH transport channel coded bits
        % % containing MIB bits
        % bchCoded = lteBCH(enb,mibBits);
        % % Matlab LTE Toolbox to generate Physical BCH symbols
        % pbchSymbols = ltePBCH(enb,bchCoded);
        
        
        %% Resource grid
        
        % Downlink resource grid
        resourceGrid = lteDLResourceGrid(enb);
        
        pdcchIndices = ltePDCCHIndices(enb, {'1based'});

        % The complex PDCCH symbols are easily mapped to each of the resource grids
        % for each antenna port
        resourceGrid(pdcchIndices) = pdcchSyms;
               
        %% LTE transmission
        
        [ waveform, waveformInfo] = lteOFDMModulate(enb,resourceGrid);
        
        [ rxWaveform ] = channel( waveform,'AWGN', isnr, waveformInfo, enb.CellRefP );
        
        %rxWaveform = awgn(waveform,isnr,'measured');
        
        %% Receiver
        
        % OFDM Demodulate
        [ rxResourceGrid ] = lteOFDMDemodulate(enb, rxWaveform);
        
        % PBCH QPSK Demodulate
        pdcchRxSoftBits = lteSymbolDemodulate(rxResourceGrid(pdcchIndices),'QPSK');
        pdcchRxHardBits = lteSymbolDemodulate(rxResourceGrid(pdcchIndices),'QPSK','hard');
        
        % this code is to verify manual mode
        % note that manual mode doesn't include bits scrambling according to NCell
        % [bchBitsRx, ~, ~, MIB, ~] = ltePBCHDecode(enb, rxResourceGrid(pbchIndices));
        
        % Rate matching recovered
        convRxBits = lteRateRecoverConvolutional(pdcchRxSoftBits(1:cceBits(iformat)*72),size(convBits,1));
        convRxBitsHard = lteRateRecoverConvolutional(pdcchRxHardBits(1:cceBits(iformat)*72),size(convBits,1));
        
        % Deconvolution
        crcRxBits = lteConvolutionalDecode(convRxBits);
        
        % MIB bits crc removal
        [dciRxBits, err] = lteCRCDecode(crcRxBits,'16');
        
        pdcchBitsFull = [pdcchBitsFull;pdcchSpace];
        pdcchRxHardBitsFull = [pdcchRxHardBitsFull; pdcchRxHardBits];
        convBitsFull = [convBitsFull; convBits];
        convRxBitsFull = [convRxBitsFull; convRxBitsHard];
        crcBitsFull = [crcBitsFull;crcBits];
        crcRxBitsFull = [crcRxBitsFull;crcRxBits];
        dciBitsFull = [dciBitsFull;dciBits];
        dciRxBitsFull = [dciRxBitsFull;dciRxBits];
        
        
        
        
        
    end
    
    modulationBER(isnr+SNRpad) = 1 - sum((pdcchBitsFull == pdcchRxHardBitsFull))/ size(pdcchBitsFull,1);
    rateMatchingBER(isnr+SNRpad) = 1 - sum((convBitsFull == convRxBitsFull))/ size(convBitsFull,1);
    convoBER(isnr+SNRpad) = 1 - sum((crcBitsFull == crcRxBitsFull))/ size(crcBitsFull,1);
    crcBER(isnr+SNRpad) = 1 - sum((dciBitsFull == dciRxBitsFull))/ size(dciBitsFull,1);
    
end

delete(waitBar);

BER(1,:) = modulationBER;
BER(2,:) = convoBER;
BER(3,:) = crcBER;
BER(4,:) = 0.5*erfc(sqrt(10.^((SNRmin:SNRmax)/10)));

% add smallest finite number so BER = 0 can be plot
BER = BER + eps;
color = ['r','g','b','c','m','y','k'];                              % line color
marker = ['+','o','*','.','x','s','d','^','v','>','<','p','h'];     % line marker
figure('Name','BER vs SNR','NumberTitle','off');
for iPlot = 1:size(BER,1)                                           % plot all MCS
    colorIdx = mod(iPlot-1,7)+1;
    markerIdx =  mod(iPlot-1,13)+1;
    lineProp =['-',color(colorIdx),marker(markerIdx)];
    semilogy(SNRmin:SNRmax,BER(iPlot,:),lineProp)
    hold on;
    switch iPlot
        case 1
            legendEntry{iPlot} = 'QPSK Modulation BER';
        case 2
            legendEntry{iPlot} = 'BER after convolutional coding';
        case 3
            legendEntry{iPlot} = 'BER after CRC';
        case 4
            legendEntry{iPlot} = 'QPSK Theorical';
    end
end
%set(gca,'Color',[0.8 0.8 0.8]);
xlabel('SNR (dB)') % x-axis label
ylabel('BER') % y-axis label
grid on;
axis([-inf,inf,10^-6,1])
legend(legendEntry,'Location','eastoutside');



