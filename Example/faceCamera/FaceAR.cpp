// CSIRO has filed various patents which cover the Software.

// CSIRO grants to you a license to any patents granted for inventions
// implemented by the Software for academic, research and non-commercial
// use only.

// CSIRO hereby reserves all rights to its inventions implemented by the
// Software and any patents subsequently granted for those inventions
// that are not expressly granted to you.  Should you wish to license the
// patents relating to the Software for commercial use please contact
// CSIRO IP & Licensing, Gautam Tendulkar (gautam.tendulkar@csiro.au) or
// Nick Marsh (nick.marsh@csiro.au)

// This software is provided under the CSIRO OPEN SOURCE LICENSE
// (GPL2) which can be found in the LICENSE file located in the top
// most directory of the source code.

// Copyright CSIRO 2013

#include "IO.hpp"
#include "myFaceAR.h"
#include "Config.h"

using namespace FACETRACKER;
using namespace std;
//===========================================================================
FaceARParams::~FaceARParams()
{

}
//===========================================================================
FaceAR::~FaceAR()
{

}
//===========================================================================
FaceAR* FACETRACKER::LoadFaceAR(const char* fname)
{
  int type; FaceAR* model=NULL;
  ifstream file(fname); assert(file.is_open()); file >> type; file.close();
  switch(type){
  case IO::MYFACEAR: 
    model = new myFaceAR(fname); break;
  default:    
    file.open(fname,std::ios::binary); assert(file.is_open());
    file.read(reinterpret_cast<char*>(&type), sizeof(type));
    file.close();
    if(type == IOBinary::MYFACEAR){
      model = new myFaceAR(fname, true);
    }
    else
      printf("ERROR(%s,%d) : unknown facetracker type %d\n", 
	     __FILE__,__LINE__,type);
  }return model;
}

//============================================================================
FaceARParams * FACETRACKER::LoadFaceARParams(const char* fname)
{
  int type; FaceARParams * model = NULL;
  ifstream file(fname); assert(file.is_open()); file >> type; file.close();
  switch(type){
  case IO::MYFACEARPARAMS: 
    model =  new myFaceARParams(fname); 
    break;
  default:
    file.open(fname,std::ios::binary); assert(file.is_open());
    file.read(reinterpret_cast<char*>(&type), sizeof(type));
    file.close();
    if(type == IOBinary::MYFACEARPARAMS)
      model = new myFaceARParams(fname, true);
    else
      printf("ERROR(%s,%d) : unknown facetracker parameter type %d\n", 
	     __FILE__,__LINE__,type);
  }return model;
}
//============================================================================

std::string
FACETRACKER::DefaultFaceARModelPathname()
{
  char *v = getenv("CSIRO_FACE_TRACKER_MODEL_PATHNAME");
  if (v)
    return v;
  else
    return FACEAR_DEFAULT_MODEL_PATHNAME;
}

std::string
FACETRACKER::DefaultFaceARParamsPathname()
{
  char *v = getenv("CSIRO_FACE_TRACKER_PARAMS_PATHNAME");
  if (v)
    return v;
  else
    return FACEAR_DEFAULT_PARAMS_PATHNAME;
}

FaceAR *
FACETRACKER::LoadFaceAR()
{
  return LoadFaceAR(DefaultFaceARModelPathname().c_str());
}

FaceARParams *
FACETRACKER::LoadFaceARParams()
{
  return LoadFaceARParams(DefaultFaceARParamsPathname().c_str());
}
