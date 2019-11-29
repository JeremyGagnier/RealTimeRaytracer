#include "kernel.h"

__global__ void kernelWrapper(vector* colors, ray_frame* frame)
{
    int i = threadIdx.x + blockDim.x*blockIdx.x;
    colors[i].x = 0.0f;
	colors[i].y = 0.0f;
	colors[i].z = 0.0f;
    run_raytracer(i, colors, *frame);
}

void checkErrors() {
    cudaError_t cudaStatus = cudaGetLastError();
    if (cudaStatus != cudaSuccess)
    {
        fprintf(stderr, "addKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
    }
    
    cudaStatus = cudaDeviceSynchronize();
    if (cudaStatus != cudaSuccess)
    {
        fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
    }
}

int kernel_main()
{
    // Set up inputs --------------------------------------------------------------------------------------------------
    vector cameraPosition = {0.0f, 0.0f, 0.0f};
    vector cameraDirection = {0.0f, 0.0f, 1.0f};
    float cameraWidth = 1.0f;
    float cameraHeight = 0.5625f;
    float lensSize = 3.0f;

    // TODO: Load meshes from files
    mesh red_mesh  = {0, {{1.0f, 0.0f, 0.0f}, 0.0f, {0.0f, 0.5f, 0.5f}}};
    mesh blue_mesh = {0, {{0.0f, 1.0f, 0.0f}, 0.0f, {0.5f, 0.0f, 0.5f}}};
    // TODO: Compute tris from meshes
    const int numTris = 2;
    triangle tris[numTris] =
    {
        {{-1.0f, -1.0f, 10.0f}, {0.0f, 10.0f, 0.0f}, {10.0f, 0.0f, 0.0f}, {0, 0, -1}, 0},
        {{1.0f, 1.0f, 10.0f}, {0.0f, -10.0f, 0.0f}, {-10.0f, 0.0f, 0.0f}, {0, 0, -1}, 0}
    };

    int width = 16;		// 1.0000
    int height = 9;		// 0.5625
    int rays_per_pixel = 1;
    int depth = 1;
	
    // Build the core datastructures ----------------------------------------------------------------------------------
    camera camera = 
    {
        cameraPosition,
        cameraDirection,
        cameraWidth,
        cameraHeight,
        lensSize
    };
	vector up = {0.0f, 1.0f, 0.0f}; // TODO: Make sure that the camera isn't parallel to up
	vector camera_x = {up.y * cameraDirection.z - up.z * cameraDirection.y,
					   up.z * cameraDirection.x - up.x * cameraDirection.z,
					   up.x * cameraDirection.y - up.y * cameraDirection.x};
	vector camera_y = {cameraDirection.y * camera_x.z - cameraDirection.z * camera_x.y,
					   cameraDirection.z * camera_x.x - cameraDirection.x * camera_x.z,
					   cameraDirection.x * camera_x.y - cameraDirection.y * camera_x.x};
    ray_frame frame = 
	{
		camera,
        numTris,
		0,      // This reference will be set in the GPU
		width,
        height,
		rays_per_pixel,
        depth,
		up,
        camera_x,
        camera_y,
		0.0f
	};
	find_dist_to_lens(&frame);

    // Allocate memory in the GPU -------------------------------------------------------------------------------------
    mesh* red_mesh_ptr;
    mesh* blue_mesh_ptr;
    triangle* tris_ptr;
    vector* colors_ptr;
    ray_frame* frame_ptr;

    cudaSetDevice(0);
    cudaMalloc((void**)&red_mesh_ptr, sizeof(mesh));
    cudaMalloc((void**)&blue_mesh_ptr, sizeof(mesh));
    cudaMalloc((void**)&tris_ptr, sizeof(triangle) * numTris);
    cudaMalloc((void**)&colors_ptr, sizeof(vector) * width * height);
    cudaMalloc((void**)&frame_ptr, sizeof(ray_frame));

    tris[0].m = red_mesh_ptr;
    tris[1].m = blue_mesh_ptr;
    frame.tris = tris_ptr;

    cudaMemcpy(red_mesh_ptr, &red_mesh, sizeof(mesh), cudaMemcpyHostToDevice);
    cudaMemcpy(blue_mesh_ptr, &blue_mesh, sizeof(mesh), cudaMemcpyHostToDevice);
    cudaMemcpy(tris_ptr, tris, sizeof(triangle) * numTris, cudaMemcpyHostToDevice);
    cudaMemcpy(frame_ptr, &frame, sizeof(ray_frame), cudaMemcpyHostToDevice);

    // Run the kernal -------------------------------------------------------------------------------------------------
    int threads = height;
    int blocks = width;
    if (threads > 1024)
    {
        threads /= 2;
        blocks *= 2;
    }
    kernelWrapper<<<blocks, threads>>>(colors_ptr, frame_ptr);
    checkErrors();

    vector* colors = (vector*)malloc(sizeof(vector) * width * height);
    cudaMemcpy(colors, colors_ptr, sizeof(vector) * width * height, cudaMemcpyDeviceToHost);

    // cudaDeviceReset must be called before exiting in order for profiling and tracing tools such as Nsight and Visual
    // Profiler to show complete traces.
    cudaDeviceReset();

    
	for (int i = 0; i < width * height; ++i)
	{
        if (true)//(colors[i].x != 0.0f || colors[i].y != 0.0f || colors[i].z != 0.0f)
        {
		    fprintf(stdout, "(%f, %f, %f)\n", colors[i].x, colors[i].y, colors[i].z);
        }
	}

    cudaFree(frame_ptr);
    cudaFree(colors_ptr);
    cudaFree(tris_ptr);
    cudaFree(blue_mesh_ptr);
    cudaFree(red_mesh_ptr);
    
	system("pause");
    return 0;
}
