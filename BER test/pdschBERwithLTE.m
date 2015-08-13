clear;

%% Cell parameterization

% Resouce grid creation
enb.NDLRB = 25;                 % Number of downlink physical resouce block in the cell
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
enb.CFI = 2;                    % Control format indicator (CFI) value: 1,2 or 3


% pdsch format;


mcs = 28;
[modulation, itbs] = hMCSConfiguration(mcs);
tbs = lteTBS(6,itbs);

Iteration = 100;

SNRmin = 0;
SNRmax = 50;
SNRpad = 1-SNRmin;


waitBar = waitbar(0,'Start Calculating ....');
progress = 0;
done = (SNRmax-SNRmin+1)*(Iteration+1);

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
    
    blockError = 0;
    offset = 0;
    for i = 1:Iteration
        
        progress = progress + 1;
        waitbar(progress/done,waitBar,['Calculating for SNR = ',num2str(isnr)]);
        frame =[];
        for NSubframe = 0:9
            enb.NSubframe = NSubframe;
            
            %% Resource grid
            
            % Downlink resource grid
            resourceGrid = lteDLResourceGrid(enb);
            
            % Matlab LTE Toolbox to generate PSS spesific index in resource grid
            pssIndices = ltePSSIndices(enb);
            % Matlab LTE Toolbox to generate PSS signal for each resource element
            pssSymbols = ltePSS(enb);
            
            % Insert PSS symbol into resource grid according to its indices
            resourceGrid(pssIndices) = pssSymbols;
            
            
            % Matlab LTE Toolbox to generate SSS spesific index in resource grid
            sssIndices = lteSSSIndices(enb);
            % Matlab LTE Toolbox to generate SSS symbol for each resource element
            sssSymbols = lteSSS(enb);
            
            % Insert SSS symbol into resource grid according to its indices
            resourceGrid(sssIndices) = sssSymbols;
            
            % Matlab LTE Toolbox to generate SSS spesific index in resource grid
            crsIndices = lteCellRSIndices(enb);
            % Matlab LTE Toolbox to generate SSS symbol for each resource element
            crsSymbols = lteCellRS(enb);
            
            % Insert CRS symbol into resource grid according to its indices
            resourceGrid(crsIndices) = crsSymbols;
            
            
            if ~(mod(NSubframe,5) == 0)
                
                %% pdsch setting
                pdsch = struct;
                pdsch.TxScheme = 'Port0';
                pdsch.Modulation = {modulation};
                pdsch.NLayer = 1;
                [pdschIndices, Info] = ltePDSCHIndices(enb,pdsch,(0:5).');
                
                %tbs = (Info.G/3-24)+mod ((Info.G/3-24),16);
                %tbs = 4072;
                
                %% TCH bits
                tchBits = repmat([1;0;0;0;0;1],1000,1);
                tchBits = tchBits(1:tbs,1);
                
                %tchBits = randi([0 1], tbs, 1);
                
                rate = double(tbs)/double(Info.G);
                
                %% Manual pdsch symbol generation
                
                % add 24A bit CRC
                crcBits = lteCRCEncode(tchBits,'24A');
                
                % perform 1/3 turbo coding
                turboBits = lteTurboEncode(crcBits);
                
                % rate match according pdsch space
                
                
                pdschBits = lteRateMatchTurbo(turboBits,Info.G,0);
                
                
                % modulate Bits before adding to resource grid
                pdschSyms = lteSymbolModulate(pdschBits,modulation);
                
                pdschBitsFull = [pdschBitsFull;pdschBits];
                turboBitsFull = [turboBitsFull; turboBits];
                crcBitsFull = [crcBitsFull;crcBits];
                tchBitsFull = [tchBitsFull;tchBits];
                
                
                
                
                
                
                % The complex pdsch symbols are easily mapped to each of the resource grids
                % for each antenna port
                resourceGrid(pdschIndices) = pdschSyms;
            end
            frame =[frame resourceGrid];
            
            
            
            
        end
        %% LTE transmission
        
        [ waveform, waveformInfo] = lteOFDMModulate(enb,frame);
        
        
        
        chcfg = struct('Seed',1,'DelayProfile','EPA','NRxAnts',1);
        chcfg.DopplerFreq = 5.0;
        chcfg.MIMOCorrelation = 'Low';
        chcfg.SamplingRate = waveformInfo.SamplingRate;
        chcfg.InitTime = (i-1)*1e-2;
        %chcfg.InitTime = 0;
        chcfg.NormalizeTxAnts = 'On';
        chcfg.NormalizePathGains = 'On';
        chcfg.NTerms = 16;
        chcfg.InitPhase = 'Random';
        chcfg. ModelType = 'GMEDS';
        
        [fdWaveform,infoFd] = lteFadingChannel(chcfg,[waveform;zeros(25,1)]);
                
        
        [ rxWaveform ,noise] = channel( fdWaveform,'AWGN', isnr, waveformInfo, enb.CellRefP, mcs);
                      
        
        %rxWaveform = fdWaveform;
               
        
        %% Receiver
         enb.NSubframe = 0;
         enb.TotSubframes = 10;
%         % Matlab LTE Toolbox to find the beginning of the frame
        off = lteDLFrameOffset(enb, rxWaveform);
        
        if off < 25;
            offset = off;
        end
%         
                
        % Apply offset to align waveform to beginning of the LTE Frame
        rxWaveform = rxWaveform(1 + offset:end);
        % Pad end of signal with zeros after offset alignment
        rxWaveform((size(rxWaveform,1)+1):(size(rxWaveform,1) + offset)) = zeros();
        
%          foffset = lteFrequencyOffset(enb,rxWaveform)
% %         
%          rxWaveform = lteFrequencyCorrect(enb,rxWaveform,foffset);
%         
                % Apply offset to align waveform to beginning of the LTE Frame
        noise = noise(1 + offset:end);
        % Pad end of signal with zeros after offset alignment
        noise((size(noise,1)+1):(size(noise,1) + offset)) = zeros();

        
        % OFDM Demodulate
        [ rxResourceGridFull ] = lteOFDMDemodulate(enb, rxWaveform);
        % Peform channel estimation and equalization
        cec = struct('FreqWindow',29    ,'TimeWindow',15,'InterpType','cubic');
        cec.PilotAverage = 'UserDefined';
        cec.InterpWinSize = 3;
        cec.InterpWindow = 'Centered';
        
        
       
        
         [hest,noisest] = lteDLChannelEstimate(enb,cec,rxResourceGridFull);
        %rxResourceGridFull = lteEqualizeMMSE(rxResourceGridFull, hest, noisest);
        
%             hest = lteDLPerfectChannelEstimate(enb, chcfg, offset); 
%             n = lteOFDMDemodulate(enb, noise(1+offset:end ,:));
%             noisest = var(n(:));

        
        for NSubframe = 0:9
            enb.NSubframe = NSubframe;
            
            rxResourceGrid = rxResourceGridFull(:,(NSubframe*14)+1:((NSubframe+1)*14));
            rxHest = hest(:,(NSubframe*14)+1:((NSubframe+1)*14));
            if ~(mod(NSubframe,5) == 0)
                
                %% pdsch setting
                pdsch = struct;
                pdsch.TxScheme = 'Port0';
                pdsch.Modulation = {modulation};
                pdsch.NLayer = 1;
                [pdschIndices, Info] = ltePDSCHIndices(enb,pdsch,(0:5).');
                
                %tbs = (Info.G/3-24)+mod ((Info.G/3-24),16);
                %tbs = 4072;
                
                % PBCH QPSK Demodulate
                pdschGrid = lteEqualizeMMSE(rxResourceGrid(pdschIndices), rxHest(pdschIndices), noisest);                
                pdschRxSoftBits = lteSymbolDemodulate(pdschGrid,modulation);
                pdschRxHardBits = lteSymbolDemodulate(pdschGrid,modulation,'hard');
                
                
                % Rate matching recovered
                turboRxBits = lteRateRecoverTurbo(pdschRxSoftBits,tbs,0);
                turboRxBitsHard = lteRateRecoverTurbo(pdschRxHardBits,tbs,0);
                
                % Deturboolution
                crcRxBits = lteTurboDecode(turboRxBits);
                
                % MIB bits crc removal
                [tchRxBits, err] = lteCRCDecode(crcRxBits{1},'24A');
                
                pdschRxHardBitsFull = [pdschRxHardBitsFull; pdschRxHardBits];
                turboRxBitsFull = [turboRxBitsFull; turboRxBitsHard{1}];
                crcRxBitsFull = [crcRxBitsFull;crcRxBits{1}];
                tchRxBitsFull = [tchRxBitsFull;tchRxBits];
                
                if ~(err == 0)
                    blockError = blockError + 1;
                end
            end
        end
        
        
    end
    
    modulationBER(isnr+SNRpad) = 1 - sum((pdschBitsFull == pdschRxHardBitsFull))/ size(pdschBitsFull,1);
    rateMatchingBER(isnr+SNRpad) = 1 - sum((turboBitsFull == turboRxBitsFull))/ size(turboBitsFull,1);
    turboBER(isnr+SNRpad) = 1 - sum((crcBitsFull == crcRxBitsFull))/ size(crcBitsFull,1);
    crcBER(isnr+SNRpad) = 1 - sum((tchBitsFull == tchRxBitsFull))/ size(tchBitsFull,1);
    BLER(isnr+SNRpad) = double(blockError)/(double(i)*10);
end

delete(waitBar);

BER(1,:) = modulationBER;
BER(2,:) = turboBER;
BER(3,:) = crcBER;
BER(4,:) = BLER;
switch modulation
    case 'QPSK'
        BER(5,:) = 0.5*erfc(sqrt(10.^((SNRmin:SNRmax)/10)));
    case '16QAM'
        BER(5,:) = 3/4*qfunc(sqrt(4/5*(10.^((SNRmin:SNRmax)/10)))) + ...
                1/2*qfunc(3*sqrt(4/5*(10.^((SNRmin:SNRmax)/10)))) - 1/4*qfunc(5*sqrt(4/5*(10.^((SNRmin:SNRmax)/10))));
    case '64QAM'
        BER(5,:) = 7/12*qfunc(sqrt(2/7*(10.^((SNRmin:SNRmax)/10)))) + ...
                1/2*qfunc(3*sqrt(2/7*(10.^((SNRmin:SNRmax)/10)))) - ...
                1/12*qfunc(5*sqrt(2/7*(10.^((SNRmin:SNRmax)/10)))) + ...
                1/12*qfunc(9*sqrt(2/7*(10.^((SNRmin:SNRmax)/10)))) - 1/12*qfunc(13*sqrt(2/7*(10.^((SNRmin:SNRmax)/10))));
end
%add smallest finite number so BER = 0 can be plot
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
            legendEntry{iPlot} = 'BLER';
        case 5
            legendEntry{iPlot} = [modulation,' Theorical'];
    end
end
%set(gca,'Color',[0.8 0.8 0.8]);
xlabel('SNR (dB)') % x-axis label
ylabel('BER') % y-axis label
title(['MCS - ',num2str(mcs),' code rate: ',num2str(rate)]);
grid on;
axis([-inf,inf,10^-4,1])
legend(legendEntry,'Location','eastoutside');



