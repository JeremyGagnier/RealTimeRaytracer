#ifndef __mesh
#define __mesh

#include "vector.h"
#include "material.h"

typedef struct 
{
    vec3x3* tris;
    // TODO: Implement textures.
    //vec3x3* uv;
    //texture tex;
    material mat;
} mesh;

#endif
