 
color = ['r','g','b','c','m','y','k'];                              % line color
marker = ['+','o','*','.','x','s','d','^','v','>','<','p','h'];     % line marker
for i = 1:29                                                        % plot all MCS
    colorIdx = mod(i-1,7)+1;
    markerIdx =  mod(i-1,13)+1;
    lineProp =['-',color(colorIdx),marker(markerIdx)];
    semilogy(0:20,BER(i,:),lineProp)
    hold on;
    legendEntry{i} = ['MCS - ',num2str(i-1)];
end
legend(legendEntry,'Location','eastoutside');