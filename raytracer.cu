#include "gpu_hook.h"

void find_dist_to_lens(ray_frame* frame)
{
    float dx = frame->c.camera_width / -2.0f;
    float dy = frame->c.camera_height / -2.0f;
    float relative_x = frame->camera_x.x * dx + frame->camera_y.x * dy;
    float relative_y = frame->camera_x.y * dx + frame->camera_y.y * dy;
    float relative_z = frame->camera_x.z * dx + frame->camera_y.z * dy;

    // Find where the ray hits the lens, then update the ray to equal the normal at that point.
    float o_x = (relative_x + frame->c.direction.x * frame->dist_to_lens) / frame->c.lens_size;
    float o_y = (relative_y + frame->c.direction.y * frame->dist_to_lens) / frame->c.lens_size;
    float o_z = (relative_z + frame->c.direction.z * frame->dist_to_lens) / frame->c.lens_size;
    float d_x = frame->c.direction.x / frame->c.lens_size;
    float d_y = frame->c.direction.y / frame->c.lens_size;
    float d_z = frame->c.direction.z / frame->c.lens_size;

    float dir_dot_dir   = d_x * d_x + d_y * d_y + d_z * d_z;
    float orig_dot_dir  = o_x * d_x + o_y * d_y + o_z * d_z;
    float orig_dot_orig = o_x * o_x + o_y * o_y + o_z * o_z;
	
    float two_a = 2.0f * dir_dot_dir;
    float b = 2.0f * orig_dot_dir;
    float determinant = b * b - 2.0f * two_a * (orig_dot_orig - 1.0f);

    float t = (-b + sqrtf(determinant)) / two_a;	// t has to be the plus det root.

    frame->dist_to_lens = t;
}

__device__ void run_raytracer(int i, vector* colors, ray_frame frame)
{
    ray r;
    float pct_x = ((float)(i % frame.width) + 0.5f) / ((float)frame.width) - 0.5f;
    float pct_y = ((float)(i / frame.width) + 0.5f) / ((float)frame.height) - 0.5f;
    float dx = pct_x * frame.c.camera_width;
    float dy = pct_y * frame.c.camera_height;

    // Do the procedure for each ray at that pixel (14).
    for (int ray_num = 0; ray_num < frame.rays_per_pixel; ++ray_num)
    {
        colors[i].x = 0.0f;
        colors[i].y = 0.0f;
        colors[i].z = 0.0f;

        // Find the origin of the ray (0).
        // TODO: Randomize the camera_x and camera_y variables to cast rays from random points within a pixel
        float relative_x = frame.camera_x.x * dx + frame.camera_y.x * dy;
        float relative_y = frame.camera_x.y * dx + frame.camera_y.y * dy;
        float relative_z = frame.camera_x.z * dx + frame.camera_y.z * dy;
        r.origin.x = frame.c.position.x + relative_x;
        r.origin.y = frame.c.position.y + relative_y;
        r.origin.z = frame.c.position.z + relative_z;

        // Find where the ray hits the lens, then update the ray to equal the normal at that point (12).
        float o_x = (relative_x + frame.c.direction.x * frame.dist_to_lens) / frame.c.lens_size;	// Lens space
        float o_y = (relative_y + frame.c.direction.y * frame.dist_to_lens) / frame.c.lens_size;
        float o_z = (relative_z + frame.c.direction.z * frame.dist_to_lens) / frame.c.lens_size;
        float d_x = frame.c.direction.x / frame.c.lens_size;	// Lens space
        float d_y = frame.c.direction.y / frame.c.lens_size;
        float d_z = frame.c.direction.z / frame.c.lens_size;

        float dir_dot_dir   = d_x * d_x + d_y * d_y + d_z * d_z;
        float orig_dot_dir  = o_x * d_x + o_y * d_y + o_z * d_z;
        float orig_dot_orig = o_x * o_x + o_y * o_y + o_z * o_z;

        float two_a = 2.0f * dir_dot_dir;
        float b = -2.0f * orig_dot_dir;
        float determinant = b * b - 2.0f * two_a * (orig_dot_orig - 1.0f);

        float t = (b + __fsqrt_rn(determinant)) / two_a;	// t has to be the plus det root.

        // Update the origin to the surface of the sphere (48 + 1sqrt).
        r.origin.x += frame.c.direction.x * t;
        r.origin.y += frame.c.direction.y * t;
        r.origin.z += frame.c.direction.z * t;

        // Update the direction to be the center of the lens to the surface (51 + 1sqrt)
        r.direction.x = o_x + d_x * t;
        r.direction.y = o_y + d_y * t;
        r.direction.z = o_z + d_z * t;

        float shortestTime = INT_MAX;   // I don't see a float max...
        triangle* hitTri = NULL;
        triangle* trisEnd = frame.tris + frame.numTris;
        for (triangle* triIterator = frame.tris; triIterator < trisEnd; ++triIterator)
        {
            if (hit_tri(r, *triIterator, &shortestTime))
            {
                hitTri = triIterator;
            }
        }
        
        if (hitTri != NULL)
        {
            r.origin.x += r.direction.x * shortestTime;
            r.origin.y += r.direction.y * shortestTime;
            r.origin.z += r.direction.z * shortestTime;
            /*for ()
            {

            }*/
            // TEST
            colors[i].x = hitTri->m->mat.color.x;
            colors[i].y = hitTri->m->mat.color.y;
            colors[i].z = hitTri->m->mat.color.z;
        }
    }
}

// Worst case of 63 operations. Good chance of 18 operations. Very low chance of 8 operations.
__device__ bool hit_tri(ray r, triangle t, float* shortest_time)
{
    float denom = t.normal.x * r.direction.x + t.normal.y * r.direction.y + t.normal.z * r.direction.z;
    if (denom < SMALL_FLOAT & denom > -SMALL_FLOAT)
    {
        // Hit edge on, very low chance (8).
        return false;
    }

    float time = (t.normal.x * (t.origin.x - r.origin.x) + t.normal.y * (t.origin.y - r.origin.y) + t.normal.z * (t.origin.z - r.origin.z)) / denom;
    if (*shortest_time <= time)
    {
        // Can't possibly hit earlier, good chance (~50%) (18).
        return false;
    }

    float hit_point_x = r.origin.x + time * r.direction.x;
    float hit_point_y = r.origin.y + time * r.direction.y;
    float hit_point_z = r.origin.z + time * r.direction.z;
    float wx = hit_point_x - t.origin.x;
    float wy = hit_point_y - t.origin.y;
    float wz = hit_point_z - t.origin.z;
    
    float s_dot_t = t.s.x * t.t.x + t.s.y * t.t.y + t.s.z * t.t.z;
    float s_dot_s = t.s.x * t.s.x + t.s.y * t.s.y + t.s.z * t.s.z;
    float t_dot_t = t.t.x * t.t.x + t.t.y * t.t.y + t.t.z * t.t.z;
    float w_dot_s = wx    * t.s.x + wy    * t.s.y + wz    * t.s.z;
    float w_dot_t = wx    * t.t.x + wy    * t.t.y + wz    * t.t.z;

    denom = s_dot_t * s_dot_t - s_dot_s * t_dot_t;
    float d1 = (s_dot_t * w_dot_t - t_dot_t * w_dot_s) / denom;
    float d2 = (s_dot_t * w_dot_s - s_dot_s * w_dot_t) / denom;

    // Check that the ray passes through the triangle, low chance (53).
    if ((0.0f <= d1) & (d1 <= 1.0f) & (0.0f <= d2) & (d2 <= 1.0f) & ((d1 + d2) <= 1.0f))
    {
        *shortest_time = time;
        return true;
    }
    return false;
}
