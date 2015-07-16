function color =  colorMap(index)
% color =  colorMap(index)
% function to return UCL color palette RGB vector
%  color : RGB vector
%  index : number or color name
%
% Matlab code written by Andi Soekartono, MSC Telecommunication
% Date 15-June-2015


% UCL color palette name

colorname{1} = 'lightpurple';
colorname{2} = 'darkpurple';
colorname{3} = 'purple';
colorname{4} = 'blueceleste';
colorname{5} = 'lightblue';
colorname{6} = 'skyblue';
colorname{7} = 'brightblue';
colorname{8} = 'navyblue';
colorname{9} = 'darkblue';
colorname{10} = 'darkgreen';
colorname{11} = 'midgreen';
colorname{12} = 'brightgreen';
colorname{13} = 'lightgreen';
colorname{14} = 'stone';
colorname{15} = 'darkgrey';
colorname{16} = 'darkbrown';
colorname{17} = 'darkred';
colorname{18} = 'burgundy';
colorname{19} = 'pink';
colorname{20} = 'richred';
colorname{21} = 'midred';
colorname{22} = 'orange';
colorname{23} = 'yellow';
colorname{24} = 'white';
colorname{25} = 'black';

% conversion from index number to name
if ischar(index)
    name =  index;
else
    name =  colorname{index};
end

% return appropriate RGB for given color name
switch name
    case 'lightpurple'
        color = [ 198 176 188] / 255;
    case  'darkpurple'
        color = [ 75 56 76] / 255;
    case 'purple'
        color = [ 80 7 120] / 255;
    case 'blueceleste'
        color = [ 164 219 232] / 255;
    case 'lightblue'
        color = [ 141 185 202] / 255;
    case 'skyblue'
        color = [ 155 184 211] / 255;
    case 'brightblue'
        color = [ 0 151 169] / 255;
    case 'navyblue'
        color = [ 0 40 85] / 255;
    case 'darkblue'
        color = [ 0 61 76] / 255;
    case 'darkgreen'
        color = [ 85 80 37] / 255;
    case 'midgreen'
        color = [ 143 153 62] / 255;
    case 'brightgreen'
        color = [ 181 189 0] / 255;
    case 'lightgreen'
        color = [ 187 197 146] / 255;
    case 'stone'
        color = [ 214 210 196] / 255;
    case 'darkgrey'
        color = [ 140 130 121] / 255;
    case 'darkbrown'
        color = [ 78 54 41] / 255;
    case 'darkred'
        color = [ 101 29 50] / 255;
    case 'burgundy'
        color = [ 147 39 44] / 255;
    case 'pink'
        color = [ 172 20 90] / 255;
    case 'richred'
        color = [ 213 0 50] / 255;
    case 'midred'
        color = [ 224 60 49] / 255;
    case 'orange'
        color = [ 234 118 0] / 255;
    case 'yellow'
        color = [ 246 190 0] / 255;
    case 'white'
        color = [ 255 255 255] / 255;
    case 'black'
        color = [ 0 0 0] / 255;
        
end
end