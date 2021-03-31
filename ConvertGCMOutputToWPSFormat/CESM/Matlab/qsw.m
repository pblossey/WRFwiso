function [qsat] = qsw(p,T)

%  qsw(p,T) is saturation mass mixing ratio over liquid.  It is
%   based on the saturation vapor pressure over liquid computed
%   following Murphy and Koop (2005, eqn 10, 
%   https://doi.org/10.1256/qj.04.94 )
%
%  The inputs, p and Temp, should be in Pascal and Kelvin,
%  respectively.  The output is in kg/kg.

  global Rd Rv 
  nanind = find(isnan(T));
  log_esat = 54.842763 - 6763.22./T - 4.210*log(T) + 0.000367*T ...
            + tanh(0.0415*(T-218.8)) ...
             .*(53.878 - 1331.22./T - 9.44523*log(T) + 0.014025*T);
  esat = exp(log_esat);
  qsat = (Rd/Rv)*esat./max(esat,p-esat);
  qsat(nanind) = NaN;

  
