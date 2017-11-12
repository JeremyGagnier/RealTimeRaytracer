#ifndef __material
#define __material

#include "vector.h"

typedef struct
{
    vector color;
    // TODO: Implement transparency and refraction.
    //float transparency; // from 0-1, 0 being completely opaque, 1 being completely transparent.
    //float refractive_index;
    float spectrality;  // from 0-1, 0 being completely diffuse, 1 being completely spectral.
    vector absorption;  // from 0-1 rgb absorbtion
} material;

#endif
