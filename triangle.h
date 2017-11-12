#ifndef __triangle
#define __triangle

#include "mesh.h"

typedef struct
{
    vector origin;
    vector s;   // s direction
    vector t;   // t direction
    vector normal;
    mesh* m;
} triangle;

#endif
