#ifndef __gpu_hook
#define __gpu_hook

#include "cuda_runtime.h"
#include "camera.h"
#include "triangle.h"
#include "ray.h"

typedef struct
{
    camera c;
    int numTris;
    triangle* tris;
    int width;
    int height;
    int rays_per_pixel;
    int depth;
	vector up;
	vector camera_x;	// Calculated from up cross c.direction.
	vector camera_y;	// Calculated from c.direction cross camera_y
	float dist_to_lens;
} ray_frame;

void find_dist_to_lens(ray_frame* frame);

__device__ void run_raytracer(int i, vector* colors, ray_frame frame);
__device__ bool hit_tri(ray r, triangle t, float* shortest_time);

__device__ const float SMALL_FLOAT = 0.000035f;
__device__ const float PI = 3.1415926535897932384626433832795028841971f; 

#endif
