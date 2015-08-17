clear;

%% Cell setting

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


% PDSCH transport format

resourceBlockNumber = 6;                        % Number resource block used by PDSCH
mcs = 28;                                       % Modulation and coding scheme setting
[modulation, itbs] = hMCSConfiguration(mcs);    % Decode MCS into modulation and transport block index
tbs = lteTBS(resourceBlockNumber,itbs);         % Lookup transport block using transport block index
                            

% Fading channel and channel estimation setting

% LTE specified fading channel setting
chcfg = struct;
chcfg.DelayProfile = 'EPA';
chcfg.NRxAnts = 1;
chcfg.DopplerFreq = 5.0;
chcfg.MIMOCorrelation = 'Low';
chcfg.NormalizeTxAnts = 'On';
chcfg.NormalizePathGains = 'On';
chcfg.NTerms = 16;
chcfg.InitPhase = 'Random';
chcfg. ModelType = 'GMEDS';
chcfg.Seed = 1;

% Channel estimation setting
cec = struct;
cec.FreqWindow = 15;
cec.TimeWindow = 15;
cec.InterpType = 'cubic';
cec.PilotAverage = 'UserDefined';
cec.InterpWinSize = 3;
cec.InterpWindow = 'Centered';


%% Iteration Initialization

iterationNumber  = 2;                 % number of subframes calculated for each point of SNR
SNRmin = 1;                             % minimum SNR
SNRmax = 35;                            % maximum SNR

% counter initialization        
SNRpad = 1-SNRmin;                                      
waitBar = waitbar(0,'Start Calculating ....');  
progress = 0;
done = (SNRmax-SNRmin+1)*(iterationNumber+1);


% SNR looping
for isnr = SNRmin:SNRmax
    % Prepare data container
    pdschBitsFull = [];
    pdschRxHardBitsFull = [];
    turboBitsFull = [];
    turboRxBitsFull = [];
    crcBitsFull = [];
    crcRxBitsFull = [];
    tchBitsFull = [];
    tchRxBitsFull = [];
    cqiFull = [];
    sinrFull = [];
    blockError = 0;             % BLER counter
    offset = 0;                 % time domain sample offet register
    
    % Iteration looping
    for i = 1:iterationNumber
        
        % Update progress bar
        progress = progress + 1;
        waitbar(progress/done,waitBar,['Calculating for SNR = ',num2str(isnr)]);
        
        
        %% Transmitter
        
        % Building downlink LTE frame
        frame =[];
        % Building subframes
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
                
                % Matlab LTE Toolbox to generate PDSCH spesific index in resource grid
                [pdschIndices, Info] = ltePDSCHIndices(enb,pdsch,(0:5).');
                
                %% generate data bits
                % pattern data bits
                tchBits = repmat([1;0;0;0;0;1],1000,1);    
                tchBits = tchBits(1:tbs,1);
                
                % random data bits
                %tchBits = randi([0 1], tbs, 1); 
                
                % coding rate
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
                
                % Insert data to container
                pdschBitsFull = [pdschBitsFull; pdschBits];  %#ok<*AGROW>
                turboBitsFull = [turboBitsFull; turboBits];
                crcBitsFull = [crcBitsFull; crcBits];
                tchBitsFull = [tchBitsFull; tchBits];
                                
                % Insert PDSCH symbol into resource grid according to its indices
                resourceGrid(pdschIndices) = pdschSyms;
            end
            
            % Insert subframe into frame
            frame =[frame resourceGrid]; 
            
        end
        %% LTE transmission
        
        % OFDM modulation from resoure grid into LTE complex signal 
        [ waveform, waveformInfo] = lteOFDMModulate(enb, frame);
        
        % Apply channel fading into LTE signal
        chcfg.SamplingRate = waveformInfo.SamplingRate;
        chcfg.InitTime = (i-1)*1e-2;
        [ rxWaveform,infoFd] = lteFadingChannel(chcfg,[waveform;zeros(25,1)]);
        
        % Apply AWGN into LTE signal
        [ rxWaveform ,noise] = channel( rxWaveform,'AWGN', isnr, waveformInfo, enb.CellRefP, mcs);
                      
        
        %% Receiver

        % Prepare ENB subframe counter
        enb.NSubframe = 0;
        
        % Matlab LTE Toolbox to find frame offset because of fading channel
        off = lteDLFrameOffset(enb, rxWaveform);
        
        % set offset used
        if off < 25;
            offset = off;
        end
                
        % Apply offset to align waveform to beginning of the LTE Frame
        rxWaveform = rxWaveform(1 + offset:end);
        % Pad end of signal with zeros after offset alignment
        rxWaveform((size(rxWaveform, 1) + 1):(size(rxWaveform, 1) + offset)) = zeros();
        
        
        % OFDM Demodulation
        [ rxResourceGridFull ] = lteOFDMDemodulate(enb, rxWaveform);
        
        % Peform channel estimation and equalization

        [hest,noisest] = lteDLChannelEstimate(enb, cec, rxResourceGridFull);
        
        % Decode data for each subframe
        for NSubframe = 0:9
            enb.NSubframe = NSubframe;
            
            rxResourceGrid = rxResourceGridFull(:, (NSubframe*14) + 1:((NSubframe + 1)*14));
            rxHest = hest(:, (NSubframe*14) + 1:((NSubframe + 1) * 14));
            
            if ~(mod(NSubframe,5) == 0)
                
                %% pdsch setting
                pdsch = struct;
                pdsch.TxScheme = 'Port0';
                pdsch.Modulation = {modulation};
                pdsch.NLayers = 1;
                pdsch.CSIMode = 'PUCCH 1-0';
                
                % Matlab LTE Toolbox to generate PDSCH spesific index in resource grid
                [pdschIndices, Info] = ltePDSCHIndices(enb, pdsch, (0:5).');
               
                % Matlab LTE Toolbox to equalize resource grid
                pdschGrid = lteEqualizeMMSE(rxResourceGrid(pdschIndices), rxHest(pdschIndices), noisest); 
                % Matlab LTE Toolbox to demodulate PDSCH symbols into bits
                pdschRxSoftBits = lteSymbolDemodulate(pdschGrid, modulation);
                pdschRxHardBits = lteSymbolDemodulate(pdschGrid, modulation, 'hard');
                                
                % Matlab LTE Toolbox to perform rate matching recovery to
                % get transport block bits
                turboRxBits = lteRateRecoverTurbo(pdschRxSoftBits, tbs, 0);
                turboRxBitsHard = lteRateRecoverTurbo(pdschRxHardBits, tbs, 0);
                
                % Matlab LTE Toolbox to perform turbo decoding
                crcRxBits = lteTurboDecode(turboRxBits);
                
                % Matlab LTE Toolbox to remove CRC bits
                [tchRxBits, err] = lteCRCDecode(crcRxBits{1}, '24A');
                
                % Calculate CQI and SINRS
                [cqi, sinrs] = lteCQISelect(enb, pdsch, rxHest, noisest);
                
                % Update RX data container
                pdschRxHardBitsFull = [pdschRxHardBitsFull; pdschRxHardBits];
                turboRxBitsFull = [turboRxBitsFull; turboRxBitsHard{1}];
                crcRxBitsFull = [crcRxBitsFull; crcRxBits{1}];
                tchRxBitsFull = [tchRxBitsFull; tchRxBits];
                cqiFull = [cqiFull ; cqi];
                sinrFull = [sinrFull ; sinrs];
                if ~(err == 0)
                    blockError = blockError + 1;
                end
            end
        end
        
        
    end
    
    % Calculate average BER for all iteration done
    modulationBER(isnr + SNRpad) = 1 - sum((pdschBitsFull == pdschRxHardBitsFull)) / size(pdschBitsFull, 1); %#ok<*SAGROW>
    rateMatchingBER(isnr + SNRpad) = 1 - sum((turboBitsFull == turboRxBitsFull)) / size(turboBitsFull, 1);
    turboBER(isnr + SNRpad) = 1 - sum((crcBitsFull == crcRxBitsFull)) / size(crcBitsFull, 1);
    crcBER(isnr + SNRpad) = 1 - sum((tchBitsFull == tchRxBitsFull)) / size(tchBitsFull, 1);
    BLER(isnr + SNRpad) = double(blockError) / (double(i) * 8);
    cqiValue{isnr + SNRpad} = cqiFull;
    sinrsValue{isnr + SNRpad} = sinrFull;
end

% close progress bar
delete(waitBar);

%% Ploting result
% BER performance
figure;
semilogy(SNRmin:SNRmax, crcBER, '-bo')
xlabel('SNR (dB)') % x-axis label
ylabel('BER') % y-axis label
title(['MCS - ',num2str(mcs),' code rate: ',num2str(rate)]);
axis([-inf,inf,10^-4,1])
grid on;

% BLER performance
figure;
semilogy(SNRmin:SNRmax, BLER, '-bo')
xlabel('SNR (dB)') % x-axis label
ylabel('BLER') % y-axis label
title(['MCS - ',num2str(mcs),' code rate: ',num2str(rate)]);
axis([-inf,inf,10^-4,1])
grid on;



