function RIV = allocation2RIV(enb,vrbStart,vrbLength)
% RIV = allocation2RIV(enb,vrbStart,vrbLength)
% function to return RIV for VRB allocation
%
%  enb       : eNodeB setting
%  vrbStart  : virtual resource block start
%  vrbLength : virtual resource block length
%
%  RIV       : resource indication value
%
% Matlab code written by Andi Soekartono, MSC Telecommunication
% Date 15-June-2015


% RIV calculation Resource allocation type 2 for 'Format-1A' C-RNTI DCI 
% TS 36.213 - 7.1.6.3
if (vrbLength - 1) < floor(enb.NDLRB/2)
    RIV = enb.NDLRB*(vrbLength - 1) + vrbStart;
else
    RIV = enb.NDLRB*(enb.NDLRB - vrbLength+ 1) + (enb.NDLRB - 1 - vrbStart);
end

