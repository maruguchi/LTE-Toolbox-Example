clear;

%% Cell parameterization

% Resouce grid creation
enb.NDLRB = 100;                 % Number of downlink physical resouce block in the cell
enb.CyclicPrefix = 'normal';    % Length of downlink CyclicPrefix: 'normal' or 'extended'
enb.CellRefP = 1;               % Number of antenna port with CRS signal: 1,2 or 4

% Physical signal insertion (PSS, SSS and CRS)
enb.DuplexMode = 'FDD';         % LTE Duplex mode: 'FDD' (frame type 1) or 'TDD' (frame type 2)
enb.NSubframe = 1;              % Resource grid subframe number relative in LTE frame
enb.NCellID = 0;                % Physical cell ID correspond to PSS, SSS and CRS sequence generation

% Physical control channel

enb.Ng = 'Sixth';               % Ng  HICH group multiplier: 'Sixth' | 'Half' | 'One' | 'Two'
enb.NFrame = 0;                 % System Frame number
enb.PHICHDuration = 'Normal';   % PHICH duration (accord to CP): 'Normal' | 'Extended'
enb.CFI = 3;                    % Control format indicator (CFI) value: 1,2 or 3


% pdsch format;
cceBits = [1,2,4,8];

mcs = 25;
[modulation, itbs] = hMCSConfiguration(mcs);
tbs = lteTBS(6,itbs);

TotFrame = 10;

SNRmin = -10;
SNRmax = 15;
SNRpad = 1-SNRmin;


waitBar = waitbar(0,'Start Calculating ....');
progress = 0;
done = (SNRmax-SNRmin+1)*(TotFrame+1);

iformat = 2;
for isnr = SNRmin:SNRmax
    pdschBitsFull = [];
    pdschRxHardBitsFull = [];
    turboBitsFull = [];
    turboRxBitsFull = [];
    crcBitsFull = [];
    crcRxBitsFull = [];
    tchBitsFull = [];
    tchRxBitsFull = [];
    for i = 1:TotFrame
        
        progress = progress + 1;
        waitbar(progress/done,waitBar,['Calculating for SNR = ',num2str(isnr)]);
        
               
        
        %% TCH bits
        tchBits = randi([0 1], tbs, 1);
               
       
        
        %% Manual pdsch symbol generation
        
        % add 24A bit CRC
        crcBits = lteCRCEncode(tchBits,'24A');
        
        % perform 1/3 turbo coding
        turboBits = lteTurboEncode(crcBits);
                
        % rate match according pdsch space
        
        % pdsch setting
        pdsch = struct;
        pdsch.TxScheme = 'Port0';
        pdsch.Modulation = {modulation};
        pdsch.NLayer = 1;
        [pdschIndices, Info] = ltePDSCHIndices(enb,pdsch,(0:5).');
        
                
        pdschBits = lteRateMatchTurbo(turboBits,Info.G,0);
               
                
        % modulate Bits before adding to resource grid
        pdschSyms = lteSymbolModulate(pdschBits,modulation);
        
        

        
        %% Resource grid
        
        % Downlink resource grid
        resourceGrid = lteDLResourceGrid(enb);

        % The complex pdsch symbols are easily mapped to each of the resource grids
        % for each antenna port
        resourceGrid(pdschIndices) = pdschSyms;
               
        %% LTE transmission
        
        [ waveform, waveformInfo] = lteOFDMModulate(enb,resourceGrid);
        
        [ rxWaveform ] = channel( waveform,'AWGN', isnr, waveformInfo, enb.CellRefP, mcs);
        
        %rxWaveform = awgn(waveform,isnr,'measured');
        
        %% Receiver
        
        % OFDM Demodulate
        [ rxResourceGrid ] = lteOFDMDemodulate(enb, rxWaveform);
        
        % PBCH QPSK Demodulate
        pdschRxSoftBits = lteSymbolDemodulate(rxResourceGrid(pdschIndices),modulation);
        pdschRxHardBits = lteSymbolDemodulate(rxResourceGrid(pdschIndices),modulation,'hard');
            
        
        % Rate matching recovered
        turboRxBits = lteRateRecoverTurbo(pdschRxSoftBits,tbs,0);
        turboRxBitsHard = lteRateRecoverTurbo(pdschRxHardBits,tbs,0);
        
        % Deturboolution
        crcRxBits = lteTurboDecode(turboRxBits);
        
        % MIB bits crc removal
        [tchRxBits, err] = lteCRCDecode(crcRxBits{1},'24A');
        
        pdschBitsFull = [pdschBitsFull;pdschBits];
        pdschRxHardBitsFull = [pdschRxHardBitsFull; pdschRxHardBits];
        turboBitsFull = [turboBitsFull; turboBits];
        turboRxBitsFull = [turboRxBitsFull; turboRxBitsHard{1}];
        crcBitsFull = [crcBitsFull;crcBits];
        crcRxBitsFull = [crcRxBitsFull;crcRxBits{1}];
        tchBitsFull = [tchBitsFull;tchBits];
        tchRxBitsFull = [tchRxBitsFull;tchRxBits];
        
        
        
        
        
    end
    
    modulationBER(isnr+SNRpad) = 1 - sum((pdschBitsFull == pdschRxHardBitsFull))/ size(pdschBitsFull,1);
    rateMatchingBER(isnr+SNRpad) = 1 - sum((turboBitsFull == turboRxBitsFull))/ size(turboBitsFull,1);
    turboBER(isnr+SNRpad) = 1 - sum((crcBitsFull == crcRxBitsFull))/ size(crcBitsFull,1);
    crcBER(isnr+SNRpad) = 1 - sum((tchBitsFull == tchRxBitsFull))/ size(tchBitsFull,1);
    
end

delete(waitBar);

BER(1,:) = modulationBER;
BER(2,:) = turboBER;
BER(3,:) = crcBER;
switch modulation
    case 'QPSK'
        BER(4,:) = 0.5*erfc(sqrt(10.^((SNRmin:SNRmax)/10)));
    case '16QAM'
        BER(4,:) = 3/4*qfunc(sqrt(4/5*(10.^((SNRmin:SNRmax)/10)))) + ...
                1/2*qfunc(3*sqrt(4/5*(10.^((SNRmin:SNRmax)/10)))) - 1/4*qfunc(5*sqrt(4/5*(10.^((SNRmin:SNRmax)/10)))); 
    case '64QAM'
        BER(4,:) = 7/12*qfunc(sqrt(2/7*(10.^((SNRmin:SNRmax)/10)))) + ...
                1/2*qfunc(3*sqrt(2/7*(10.^((SNRmin:SNRmax)/10)))) - ...
                1/12*qfunc(5*sqrt(2/7*(10.^((SNRmin:SNRmax)/10)))) + ...
                1/12*qfunc(9*sqrt(2/7*(10.^((SNRmin:SNRmax)/10)))) - 1/12*qfunc(13*sqrt(2/7*(10.^((SNRmin:SNRmax)/10))));
end
% add smallest finite number so BER = 0 can be plot
BER = BER + eps;
color = ['r','g','b','m','y','k'];                              % line color
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
            legendEntry{iPlot} = [modulation,' Modulation BER'];
        case 2
            legendEntry{iPlot} = 'BER after turbo coding';
        case 3
            legendEntry{iPlot} = 'BER after CRC';
        case 4
            legendEntry{iPlot} = [modulation,' Theorical'];
    end
end
%set(gca,'Color',[0.8 0.8 0.8]);
xlabel('Eb/No (dB)') % x-axis label
ylabel('BER') % y-axis label
grid on;
axis([-inf,inf,10^-6,1])
legend(legendEntry,'Location','eastoutside');



