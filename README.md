# WRFwiso
A water-isotope-enabled version of WRF (version 3.9.1.1)

This repository contains four pieces:

 - WRFV3: a copy of WRF version 3.9.1.1 with an additional, limited implementation of water isotopes (HDO, H218O) in the Thopson 2008 microphysics and the MYJ PBL and surface schemes,
 - WPS: a copy of WPS version 3.9.1 with the ability to input initial and boundary conditions for water isotopic fields,
 - PWRF3.9.1: a copy of Polar WRF version 3.9.1 with modifications for the water isotope implementation
 - ConvertGCMOutputToWPSFormat: which includes MATLAB scripts and a fortran program for converting iCESM output into the WRF intermediate format

Notes
 + This repository was put together for a project that involved downscaling output from iCESM over Antartica and reflects the needs of that particular project.  If you just want to run the isotope-enabled WRF in idealized cases, you may be able to ignore everything outside the WRFV3/ directory.
 + The water isotopes are not included in any of the shallow or deep convection schemes, so (as currently implemented) the model must be run without convective parameterizations on all grids.  Some work could be done to permit coarse outer grids to be run without neither convective parameterizations nor water isotopes.  Then, the isotopic initial/boundary conditions could be used to initialize water isotopic fields on inner grids which would be run with water isotopes and wihtout convective parameterization.
 + In retrospect, it would have been preferrable to develop WRFwiso as a patch for a standard release of WRF, including only those routines that differ from the standard release.  (This is what is done by Polar WRF.)  This would have made staying up-to-date with newer WRF releases easier.  It would be better to include the isotope implementation in a more up-to-date version of WRF and to implement the isotopes in the aerosol-aware Thompson scheme or another, more modern scheme.
 + I have run this mainly on NCAR's Cheyenne cluster, which may be the ideal place in the world to run WRF.  It may be more difficult to get the libraries/compilers and all set up properly elsewhere.  I would suggest starting with idealized cases

TODO
 + Getting Started Guide
 + HOWTO for running idealized cases in WRFV3: test/em_hill2d_x and test/em_seabreeze2d_x
 + HOWTO for running real cases
 + HOWTO for running Antarctica simulations downscaled from iCESM
 + Description of implementation

Thanks
 + to David Bromwich and Keith Hines of Ohio State University for sharing Polar WRF and allowing me to include the modified Polar WRF routines in this repository.
 + to David Reusch, Jordan Powers and Kevin Manning for advice on configuring WRF simulations over Antarctica.
 + to all of the people who worked on WRF and WPS, especially Greg Thompson for answering many queries about his microphysics.
 + to Andrew Pauling for helping to refine the HOWTO for running the Antartica simualtions.
 + to the US National Science Foundation for supporting the development of this implementation through grants AGS-1260368 and 1602435

