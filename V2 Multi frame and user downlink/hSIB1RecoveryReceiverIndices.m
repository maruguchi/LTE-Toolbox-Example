%hSIB1RecoveryReceiverIndices Receiver and channel indices
%   [RXIND,CHIND] = hSIB1RecoveryReceiverIndices(ENB,IND,NRXANTS)
%   obtains the received symbol matrix physical Resource Element (RE)
%   indices RXIND and channel matrix RE indices CHIND for a physical
%   channel.
%
%   The returned indices are dependent on the eNodeB configuration
%   structure ENB, the channel configuration structure CHS, the RE indices
%   of the transmitted channel of interest IND and the number of receive
%   antennas NRXANTS.

%   Copyright 2010-2013 The MathWorks, Inc.

function [rxInd,chInd] = hSIB1RecoveryReceiverIndices(enb,ind,NRxAnts)

    griddims = lteResourceGridSize(enb);
    NRE = size(ind, 1);       % Number of channel REs in one antenna plane
    R = NRxAnts;              % Number of receive antennas
    K = griddims(1);          % Number of subcarriers
    L = griddims(2);          % Number of OFDM symbols in a subframe    
    P = enb.CellRefP;         % Number of transmit antennas
    
    % Calculate RE indices within received grid
    rxInd = repmat(ind(:, 1), [1 R]) + repmat(uint32(0:R-1)*K*L, [NRE 1]);
    
    % Calculate RE indices within channel grid
    chInd = repmat(rxInd, [1 1 P]) + ...
        reshape(repmat(uint32(0:P-1)*K*L*R, [NRE*R 1]), [NRE R P]);

end   
