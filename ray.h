#ifndef __ray
#define __ray

#include "vector.h"
#include "camera.h"

typedef struct
{
    vector origin;
    vector direction;
    float proportion;
} ray;

#endif
