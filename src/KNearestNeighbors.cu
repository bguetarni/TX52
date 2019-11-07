#include <vector>
#include <algorithm>
#include <iostream>

#include "Point.h"
#include "KNearestNeighbors.cuh"
#include "ComputeNeighbors.cuh"

////    CPU Version of Neighbors algorithm  ////
void GetKNearestNeighborsCPU(const size_t p, const std::vector<Point>& points, std::vector<size_t>& neighbors, unsigned int k)
{
    std::vector<double> distance(k, 1000);
    neighbors.resize(k);
    for (size_t q = 0; q < points.size(); q++)
    {
        //check that we're not calculating the distance between p and itself
        if (q != p)
        {
            //calcuate the distance between p and q
            double d = Point::Distance(points[p], points[q]);

            //check if q is nearer than the farest of the nearest point
            auto max = std::max_element(distance.begin(), distance.end());
            if (d < *max)
            {
                distance[std::distance(distance.begin(), max)] = d;
                neighbors[std::distance(distance.begin(), max)] = q;
            }
        }
    }
}


void cudaCheck ( int status, char* msg )
{
	if ( status != 0 ) printf ( "CUDA ERROR: %s\n", msg);
}

void GetKNearestNeighborsGPU(const std::vector<Point>& points, std::vector< std::vector<size_t> >& AllNeighbors, unsigned int k)
{
    std::vector<size_t> neighbors;
    
    Point* CPUpoints = (Point*)malloc(points.size() * sizeof(Point));
    size_t* CPUneighbors = (size_t*)malloc(points.size() * k * sizeof(size_t));
    
    //instanciate points coordinates
    for(int i = 0; i < points.size(); i++)
    {
        CPUpoints[i] = points[i];
    }


    //GPU variables
    Point* GPUpoints;
    size_t* GPUneighbors;
    double* GPUdistance;
    cudaCheck( cudaMalloc((void**)&GPUpoints, points.size() * sizeof(Point)), "GPUpoints allocation" );
    cudaCheck( cudaMalloc((void**)&GPUneighbors, points.size() * k * sizeof(size_t)), "GPUneighbors allocation");
    cudaCheck( cudaMalloc((void**)&GPUdistance, points.size()*k * sizeof(double)), "GPUdistance allocation");
    


    //send points coordinates to GPU memory
    cudaCheck( cudaMemcpy(GPUpoints, CPUpoints, points.size() * sizeof(Point), cudaMemcpyHostToDevice), "GPUpoints copy");
    
    std::cout << "Computing neighbors..." << std::endl;
    ComputeNeighbors<<< (points.size()/512)+1, 512 >>>(GPUpoints, GPUneighbors, GPUdistance, points.size(), k);
    
    //recover the neighbors indexes from GPU memory
    cudaCheck( cudaMemcpy(CPUneighbors, GPUneighbors, points.size() * k * sizeof(size_t), cudaMemcpyDeviceToHost), "GPUneighbors copy");

    neighbors.resize(k);
    for(int i = 0; i < points.size(); i++)
    {
        for(int j = 0; j < k; j++)
        {
            neighbors[j] = CPUneighbors[i*k + j];
        }
        AllNeighbors.push_back(neighbors);
    }




    free(CPUpoints);
    free(CPUneighbors);
    cudaFree(GPUpoints);
    cudaFree(GPUneighbors);
    cudaFree(GPUdistance);
}
