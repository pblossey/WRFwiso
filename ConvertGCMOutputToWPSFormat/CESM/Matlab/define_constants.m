%  DEFINE_CONSTANTS defines important thermodynamic constants.
%
%      This script defines important thermodynamic constants as global
%      variables using values defined in Appendix 2 of Emanuel.  The
%      values with their appropriate units are as follows:
%
%         g       = 9.8 m/s^2         (gravitational acceleration)
%         stefan  = 5.67e-8 W/m^2 K^4 (Stefan-Boltzman constant)
%         r_earth = 6.37*10^6 m       (radius of earth)
%         Omega   = 2*pi/86400 s^(-1) (rotational rate of earth)
%         
%         Rd     =  287.04 J/kg K     (specific gas constant for dry air)
%         Rv     =  461.50 J/kg K     (specific gas constant for water vapor)
%         Cp     = 1005.7  J/kg K     (specific heat of air at constant p)
%         Cpv    = 1870    J/kg K     (specific heat of water vapor)
%         Cw     = 4190    J/kg K     (constant in formula for Lv(temp))
%         L      = 2.5e6   J/kg       (specific latent heat of condensation)
%         Ls     = 2.844e6 J/kg       (specific latent heat of sublimation)
%
%         Reference values for subtropical convective boundary layers:
%           psurf  = 1.022e5 Pa       (surface pressure)
%           pref   = 1.0175e5 Pa      (reference pressure)
%           rhoref = 1.29     kg/m^3  (reference air density)
%
%      Script was written initially by Chris Bretherton.
%      Help comments added by Peter Blossey (October 2003).

  global g stefan r_earth Omega Rd Rv Cp Cpv Cw L Ls delta psurf pref ...
      rhoref rhoLiquidWater CLiquidWater

  g     = 9.8;
  stefan= 5.67e-8;
  r_earth = 6370*1000;
  Omega   = 2*pi/86400;

  Rd    = 287.04;
  Rv    = 461.50;
  Cp    = 1005.7;
  Cpv   = 1870;
  Cw    = 4190;
  L     = 2.5e6;
  Ls    = 2.8440e6;
  delta = 0.608;

  rhoLiquidWater = 1000; % liquid water density, kg/m3
  CLiquidWater = 4187; % Liquid water heat capacity, J/kg/K

%  Reference values and definitions for subtropical CBL's

  psurf = 1022*100;
  pref  = psurf - 45*100;
  rhoref = 1.29;
  
% molecular weight of common gases -- useful for translating from
% vmr to mmr
 mwdry =  28.966; %  molecular weight dry air
 mwco2 =  44.;    % molecular weight co2
 mwh2o =  18.016; % molecular weight h2o
 mwn2o =  44.;    % molecular weight n2o
 mwch4 =  16.;    % molecular weight ch4
 mwf11 = 136.;    % molecular weight cfc11
 mwf12 = 120.;    % molecular weight cfc12
 mwo3  =  48.;    %  ozone, strangely missing
% mixingRatioMass = mol_weight/mol_weight_air * mixingRatioVolume


% Coefficients for computation of saturation vapor pressure of
% water using 8th order polynomail.  From Flatau et al (1992) in
% Journal of Applied Meteorology.  Evaluate using
% polyval(pcoef_esx,T) where x specifies water or ice and T is the
% temperature in degrees Centigrade.

global pcoef_esw pcoef_esi

pcoef_esw = [-0.3704404e-15   0.2564861e-13   0.6936113e-10 ...
              0.2031998e-7    0.2995057e-5    0.2641412e-3  ...
              0.1430341e-1    0.4440316       6.105851];
pcoef_esi = [ 0.252751365e-14 0.146898966e-11 0.385852041e-9 ...
              0.602588177e-7  0.615021634e-5  0.420895665e-3 ...
              0.188439774e-1  0.503160820     6.11147274];

orange = [255 127 0]/255;
purple = [128 0 128]/255;
forestgreen = [34 139 34]/255;
brown = [153 76 0]/255;

lcolor = linecolors2(6,0.2);

colorlist = [0 0 0
0 255 0
1 0 103
213 255 0
255 0 86
158 0 142
14 76 161
255 229 2
0 95 57
149 0 58
255 147 126
164 36 0
0 21 68
145 208 203
98 14 0
107 104 130
0 0 255
0 125 181
106 130 108
0 174 126
194 140 159
190 153 112
0 143 156
95 173 78
255 0 0
255 0 246
255 2 157
104 61 59
255 116 163
150 138 232
152 255 82
167 87 64
1 255 254
255 238 232
254 137 0
189 198 255
1 208 255
187 136 0
117 68 177
165 255 210
255 166 254
119 77 0
122 71 130
38 52 0
0 71 84
67 0 44
181 0 255
255 177 103
255 219 102
144 251 146
126 45 210
189 211 147
229 111 254
222 255 116
0 255 120
0 155 255
0 100 1
0 118 255
133 169 0
0 185 23
120 130 49
0 255 198
255 110 65
232 94 190];
colorlist = colorlist/255;