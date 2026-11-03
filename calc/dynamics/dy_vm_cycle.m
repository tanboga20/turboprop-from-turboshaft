function v = dy_vm_cycle(Sr, Si)
%DY_VM_CYCLE  Largest von Mises stress over a cycle of a harmonic stress state S(t) = Sr cos wt - Si sin wt.
%   v = dy_vm_cycle(Sr, Si)
%
%   Sr, Si: real arrays with the 6 components [xx yy zz xy yz xz] in the
%   last dimension (any leading dimensions). With P the von Mises quadratic
%   form, vm^2(t) = a cos^2 - 2 c cos sin + b sin^2, a = Sr' P Sr,
%   b = Si' P Si, c = Sr' P Si, whose maximum over the cycle is
%   (a + b) / 2 + sqrt(((a - b) / 2)^2 + c^2). max(vm(Sr), vm(Si)) can
%   read low by up to 1 / sqrt(2).
%   Source: Phase 3 report, Section 3.6 ("Method").

d = ndims(Sr);
q = @(A, B) 0.5 * ((comp(A, 1) - comp(A, 2)) .* (comp(B, 1) - comp(B, 2)) + (comp(A, 2) - comp(A, 3)) .* (comp(B, 2) - comp(B, 3)) + ...
                   (comp(A, 3) - comp(A, 1)) .* (comp(B, 3) - comp(B, 1))) + 3 * (comp(A, 4) .* comp(B, 4) + comp(A, 5) .* comp(B, 5) + comp(A, 6) .* comp(B, 6));
a = q(Sr, Sr);  b = q(Si, Si);  c = q(Sr, Si);
v = sqrt(max((a + b) / 2 + sqrt(((a - b) / 2).^2 + c.^2), 0));

    function x = comp(A, k)
        idx = repmat({':'}, 1, d);  idx{d} = k;
        x = A(idx{:});
    end
end
