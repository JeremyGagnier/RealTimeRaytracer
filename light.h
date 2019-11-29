#ifndef __lightsource
#define __lightsource

#include "vector.h"

typedef struct
{
    vector position;
    float radius;
    float intensity;
    vector color;
} light_sphere;

typedef struct
{
    vector toSource;
    float intensity;
    vector color;
} light_ray;

#endif
