#ifndef __camera
#define __camera

#include "vector.h"

typedef struct
{
    vector position;
    vector direction;
    float camera_width;
    float camera_height;
    float lens_size;
} camera;

#endif
