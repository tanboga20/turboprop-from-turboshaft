function s = support(type, varargin)
%SUPPORT  One support of rotor_model, with every field filled.
%   s = support('direct', kxx, kyy, cxx, cyy)
%   s = support('chain', k_b, m_j, k_sc, c_sfd, m_h, khx, khy, chx, chy)
%   s = support(..., 'n', node)   puts the support at a given shaft node
%
%   Units N/m, N s/m, kg. rotor_model explains the two types. All supports
%   carry the same fields so that they can sit in one struct array.
%
%   Source: Phase 2 report, Section 2.1 ("Model").

s = struct('type', type, 'n', [], 'kxx', 0, 'kyy', 0, 'cxx', 0, 'cyy', 0, ...
           'k_b', 0, 'm_j', 0, 'k_sc', 0, 'c_sfd', 0, 'm_h', 0, ...
           'khx', 0, 'khy', 0, 'chx', 0, 'chy', 0);
k = find(strcmp(varargin, 'n'), 1);
if ~isempty(k)
    s.n = varargin{k + 1};
    varargin(k:k + 1) = [];
end
v = varargin;
switch type
    case 'direct'
        [s.kxx, s.kyy, s.cxx, s.cyy] = v{1:4};
    case 'chain'
        [s.k_b, s.m_j, s.k_sc, s.c_sfd, s.m_h, s.khx, s.khy, s.chx, s.chy] = v{1:9};
    otherwise
        error('support: type must be direct or chain');
end
end
