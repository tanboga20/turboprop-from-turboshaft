function o = os_oil(T, li)
%OS_OIL  MIL-PRF-23699 properties at any temperature from -40 to 150 degC.
%   o = os_oil(T, li)
%
%   li = lb_inputs. From 40 degC up: oil_props (Walther line through the
%   data sheet values at 40 and 100 degC, step 1.4). Below 40 degC the
%   Walther line goes through the data sheet values at -40 degC (li.nu_cold
%   (1), 11,000 cSt) and 40 degC: the 40-100 degC line would give about
%   19,000 cSt at -40 degC. Output struct as oil_props (nu [cSt], rho, eta,
%   cp). Source: Phase 3 report, Section 3.2 ("Cold start").

o = oil_props(max(T, 40), li.oil);
if T < 40
    W = @(nu) log10(log10(nu + 0.7));
    x1 = log10(-40 + 273.15);  x2 = log10(40 + 273.15);
    b = (W(li.nu_cold(1)) - W(li.oil.nu40)) / (x1 - x2);
    o.nu = 10^(10^(W(li.oil.nu40) + b * (log10(T + 273.15) - x2))) - 0.7;
    o.rho = li.oil.rho15 * (1 - li.oil.alpha_rho * (T - 15));
    o.eta = o.nu * o.rho / 1000;
end
end
