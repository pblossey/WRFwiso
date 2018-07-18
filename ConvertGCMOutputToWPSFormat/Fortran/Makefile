# set up for olympus/challenger at UW

F90=ifort -convert big_endian 
FFLAGS=-O2 -fp-model source
FFLAGS_NOOPT=-g -O0 -debug -traceback -fpe0 -check all -ftrapuv
#FFLAGS=$(FFLAGS_NOOPT)

ifeq ($(HOSTNAME),olympus.atmos.washington.edu)
  INC_NETCDF=$(INC_NETCDF_NS)
  LIB_NETCDF=$(LIB_NETCDF_UW)

  FFLAGS+=$(INC_NETCDF)
  LDFLAGS=$(LIB_NETCDF)
endif

SOURCES=WPSGlobalAttributes.f90 DumpIntermediateFormat.f90 WPSNetcdf2IntermediateFormat.f90
OBJECTS=$(SOURCES:.f90=.o)

all: $(SOURCES) WPSNetcdf2IntermediateFormat

WPSGlobalAttributes.o: WPSGlobalAttributes.f90
DumpIntermediateFormat.o: DumpIntermediateFormat.f90 WPSGlobalAttributes.o
WPSNetcdf2IntermediateFormat.o: WPSGlobalAttributes.o DumpIntermediateFormat.o

WPSNetcdf2IntermediateFormat: $(OBJECTS) 
	$(F90) $(FFLAGS) $(OBJECTS) -o WPSNetcdf2IntermediateFormat $(LDFLAGS) 

.PHONY:

clean:
	rm -f *.o *.mod WPSNetcdf2IntermediateFormat

%.o : %.f90
	$(F90) -c $(FFLAGS) $<
