function F = mf_fasteners(in, m_modelled)
%MF_FASTENERS  Bottom-up fastener mass against the step 3.1 allowance (step 3.4).
%   F = mf_fasteners(in, m_modelled)
%
%   in = mf_inputs, m_modelled = modelled RGB mass of the roll-up [kg]
%   (step 3.2: 104.18 kg). Each joint of in.fast: n fasteners of diameter d
%   and length L, volume pi/4 d^2 L + (head + washers + nuts + inserts) d^3
%   with the in.c_fast multiples, A286 density. Output F: table F.T (joint,
%   n, size, kg each, kg), F.sum, F.with_k (times the contingency in.k_fast),
%   F.allowance (in.allow_share x m_modelled) and F.diff = allowance - with_k
%   (positive: the allowance covers the estimate). Nothing is changed in the
%   roll-up: the joints are drawn in step 3.9 and the allowance stays until then.
%   Source: Phase 3 report, Section 3.4 ("Bill of materials").

c = in.c_fast;
n = [in.fast.n]';  d = [in.fast.d]';  L = [in.fast.L]';
V = pi / 4 * d.^2 .* L + (c.head + c.washer * [in.fast.wash]' + c.nut * [in.fast.nut]' + c.insert * [in.fast.ins]') .* d.^3;
each = V * in.rho_fast * 1e-9;
F.T = table(string({in.fast.name}'), n, compose("M%d x %d", d, L), each, n .* each, ...
            'VariableNames', {'joint', 'n', 'size', 'kg_each', 'kg'});
F.n = sum(n);
F.sum = sum(n .* each);
F.with_k = in.k_fast * F.sum;
F.allowance = in.allow_share * m_modelled;
F.diff = F.allowance - F.with_k;
end
