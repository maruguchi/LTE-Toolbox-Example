BER(1,:) = mibBER;
BER(2,:) = cfiBER;
BER(3,:) = dciBER;
BER(4:3+size(dataBER,1),:) = dataBER;
color = ['r','g','b','c','m','y','k'];                              % line color
marker = ['+','o','*','.','x','s','d','^','v','>','<','p','h'];     % line marker
figure('Name','BER vs SNR','NumberTitle','off','Position',...
        [(screen(3)-plotSize(1))/2,60,plotSize(1),plotSize(2)-80]);
for iPlot = 1:size(BER,1)                                           % plot all MCS
    colorIdx = mod(iPlot-1,7)+1;
    markerIdx =  mod(iPlot-1,13)+1;
    lineProp =['-',color(colorIdx),marker(markerIdx)];
    semilogy(snrMin:snrMax,BER(iPlot,:),lineProp)
    hold on;
    switch iPlot
        case 1
            legendEntry{iPlot} = 'MIB';
        case 2
            legendEntry{iPlot} = 'CFI';
        case 3
            legendEntry{iPlot} = 'DCI';
        otherwise
            legendEntry{iPlot} = ['MCS - ',num2str(mcsTest(iPlot-3))];
    end
end
set(gca,'Color',[0.8 0.8 0.8]);
xlabel('SNR (dB)') % x-axis label
ylabel('BER') % y-axis label
legend(legendEntry,'Location','eastoutside');