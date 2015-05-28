figure;

subplot(3,1,1);
bar(snrMin:snrMax, [totalMessage(1,snrMin:snrMax)' totalResend(1,snrMin:snrMax)'])
title(['MCS - ',num2str(mcsTest(1))]);


% xlabel('SNR (dB)');
% ylabel('transport block');
% 
% legend('totalMessage', 'totalResend', 'Location','eastoutside')
% 
% subplot(3,1,2);
% bar(snrMin:snrMax, [totalMessage(2,:)' totalResend(2,:)'])
% title(['MCS - ',num2str(mcsTest(2))]);
% 
% 
% xlabel('SNR (dB)');
% ylabel('transport block');
% 
% legend('totalMessage', 'totalResend', 'Location','eastoutside')
% 
% subplot(3,1,3);
% bar(snrMin:snrMax, [totalMessage(3,:)' totalResend(3,:)'])
% title(['MCS - ',num2str(mcsTest(3))]);
% 
% xlabel('SNR (dB)');
% ylabel('transport block');
% 
% legend('totalMessage', 'totalResend', 'Location','eastoutside')