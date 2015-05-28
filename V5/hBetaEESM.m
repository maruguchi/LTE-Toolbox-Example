function [ beta ] = hBetaEESM( modulation, codeRate)
%HBETAEESM Summary of this function goes here
%   Detailed explanation goes here
QPSK =[ 0.076 1.70  ;
        0.117 1.33  ;
        0.188 1.36  ;
        0.301 1.79  ; 
        0.438 1.78  ;  
        0.588 1.46  ]; 
QAM16 = [ 0.369 4.51 ;
          0.478 5.26 ;
          0.601 4.58 ];
QAM64 = [ 0.455 4.14 ; 
          0.554 5.08 ; 
          0.650 4.95 ; 
          0.754 8.41 ; 
          0.852 15.23 ; 
	      0.926 27.91 ]; 
end

