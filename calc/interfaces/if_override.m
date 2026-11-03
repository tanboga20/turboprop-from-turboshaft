function out = if_override(varargin)
%IF_OVERRIDE  Temporary input overrides for the step 3.3 sensitivity runs.
%   in = if_override(in, name)        applied at the end of an *_inputs function
%   if_override('set', name, fields)  fields: struct of 'a.b' = value pairs as a cell {path, value; ...}
%   if_override('clear')
%
%   The input functions of the earlier steps end with
%     if exist('if_override', 'file') == 2, in = if_override(in, mfilename); end
%   so they behave as before unless calc/interfaces is on the path and an
%   override is set. A path is a dotted field name ('tun.T_gas', 'M_1P').
%   Source: Phase 3 report, Section 3.3 ("Sensitivity").

persistent O
if isempty(O), O = containers.Map(); end
if ischar(varargin{1}) || isstring(varargin{1})
    switch varargin{1}
        case 'set'
            O(varargin{2}) = varargin{3};
        case 'clear'
            O = containers.Map();
    end
    out = [];
    return
end
in = varargin{1};  name = varargin{2};
if isKey(O, name)
    c = O(name);
    for k = 1:size(c, 1)
        p = strsplit(c{k, 1}, '.');
        in = setfield(in, p{:}, c{k, 2}); %#ok<SFLD>
    end
end
out = in;
end
