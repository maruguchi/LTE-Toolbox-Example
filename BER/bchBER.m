clear;

%% Cell parameterization

% Resouce grid creation
enb.NDLRB = 15;                 % Number of downlink physical resouce block in the cell
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

TotFrame = 100;

SNRmin = -10;
SNRmax = 5;
SNRpad = 1-SNRmin;


waitBar = waitbar(0,'Start Calculating ....');
progress = 0;
done = (SNRmax-SNRmin+1)*(TotFrame+1);


for isnr = SNRmin:SNRmax
    bchBitsFull = [];
    bchRxHardBitsFull = [];
    convBitsFull = [];
    convRxBitsFull = [];
    crcBitsFull = [];
    crcRxBitsFull = [];
    mibBitsFull = [];
    mibRxBitsFull = [];
    for i = 1:TotFrame
        
        progress = progress + 1;
        waitbar(progress/done,waitBar,['Calculating for SNR = ',num2str(isnr)]);
        
        
        %% MIB bits
        
        mibBits = lteMIB(enb);
        
        %% Manual PBCH symbol generation
        
        % add 16 bit CRC
        crcBits = lteCRCEncode(mibBits,'16');
        % berform 1/3 convolutional coding
        convBits = lteConvolutionalEncode(crcBits);
        % rate match to 1920 bits (2 QPSK bits x 240 symbols X 4 Frame)
        bchBits = lteRateMatchConvolutional(convBits,1920);
        % modulate QPSK before adding to resource grid
        pbchSyms = lteSymbolModulate(bchBits,'QPSK');
        
        
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
        
        % Matlab LTE Toolbox to generate PBCH spesific index in resource grid
        pbchIndices = ltePBCHIndices(enb);
        
        % add PBCH to resource grid
        resourceGrid(pbchIndices) = pbchSyms(1:240);
        
        %% LTE transmission
        
        [ waveform, waveformInfo] = lteOFDMModulate(enb,resourceGrid);
        
        [ rxWaveform ] = channel( waveform,'AWGN', isnr, waveformInfo, enb.CellRefP );
        
        %rxWaveform = awgn(waveform,isnr,'measured');
        
        %% Receiver
        
        % OFDM Demodulate
        [ rxResourceGrid ] = lteOFDMDemodulate(enb, rxWaveform);
        
        % PBCH QPSK Demodulate
        bchRxSoftBits = lteSymbolDemodulate(rxResourceGrid(pbchIndices),'QPSK');
        bchRxHardBits = lteSymbolDemodulate(rxResourceGrid(pbchIndices),'QPSK','hard');
        
        % this code is to verify manual mode
        % note that manual mode doesn't include bits scrambling according to NCell
        % [bchBitsRx, ~, ~, MIB, ~] = ltePBCHDecode(enb, rxResourceGrid(pbchIndices));
        
        % Rate matching recovered
        convRxBits = lteRateRecoverConvolutional(bchRxSoftBits,120);
        convRxBitsHard = lteRateRecoverConvolutional(bchRxHardBits,120);
        
        % Deconvolution
        crcRxBits = lteConvolutionalDecode(convRxBits);
        
        % MIB bits crc removal
        [mibRxBits, err] = lteCRCDecode(crcRxBits,'16');
        
        bchBitsFull = [bchBitsFull;bchBits(1:480)];
        bchRxHardBitsFull = [bchRxHardBitsFull; bchRxHardBits];
        convBitsFull = [convBitsFull; convBits];
        convRxBitsFull = [convRxBitsFull; convRxBitsHard];
        crcBitsFull = [crcBitsFull;crcBits];
        crcRxBitsFull = [crcRxBitsFull;crcRxBits];
        mibBitsFull = [mibBitsFull;mibBits];
        mibRxBitsFull = [mibRxBitsFull;mibRxBits];
        
        
        
        
        
    end
    
    modulationBER(isnr+SNRpad) = 1 - sum((bchBitsFull == bchRxHardBitsFull))/ size(bchBitsFull,1);
    rateMatchingBER(isnr+SNRpad) = 1 - sum((convBitsFull == convRxBitsFull))/ size(convBitsFull,1);
    convoBER(isnr+SNRpad) = 1 - sum((crcBitsFull == crcRxBitsFull))/ size(crcBitsFull,1);
    crcBER(isnr+SNRpad) = 1 - sum((mibBitsFull == mibRxBitsFull))/ size(mibBitsFull,1);
    
end

delete(waitBar);

BER(1,:) = modulationBER;
BER(2,:) = convoBER;
BER(3,:) = crcBER;

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
    end
end
%set(gca,'Color',[0.8 0.8 0.8]);
xlabel('SNR (dB)') % x-axis label
ylabel('BER') % y-axis label
grid on;
axis([-inf,inf,10^-6,1])
legend(legendEntry,'Location','eastoutside');



