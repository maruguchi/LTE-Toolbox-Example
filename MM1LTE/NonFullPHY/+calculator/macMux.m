function [ pdu ] = macMux( tbs, sdu )
% [ pdu ] = macMux( tbs, sdu )
% function to perform MAC sdu multiplexing into MAC pdu
%  tbs : transport block size
%  sdu : cell array of payload sdu bit
%
%  pdu : pdu data bit
%
% Matlab code written by Andi Soekartono, MSC Telecommunication
% Date 15-June-2015


% PDU header based on TS 36.321 section 6.1.2

rre  = [0 0 1];
f = 0;
pad = [0 0 0 1 1 1 1 1];

% initialization
pdu = zeros(tbs, 1);
headerStart = 0;
sduStart = length(sdu)*16 + 8;
lcid = 1;

% insert each sdu to pdu
for i = 1:length(sdu)
    % insert sdu information in pdu header (lcid and sdu byate length)
    pdu(headerStart + (1:16)) = [rre de2bi(lcid,5,'left-msb') f de2bi((length(sdu{i}) / 8),7,'left-msb')];
    pdu(sduStart + (1 : length(sdu{i}))) = sdu{i};
    headerStart = 16 * i;
    lcid = lcid + 1;
    sduStart = sduStart + length(sdu{i});
end

% add padding information (this also mark as end of the pdu header)
pdu(headerStart + (1:8)) = pad;


end

