#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define N 1024

// Naive GEMM kernel: one thread computes one element of C
__global__ void gemm_naive(const float *A, const float *B, float *C, int n) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < n && col < n) {
        float sum = 0.0f;
        for (int k = 0; k < n; k++) {
            sum += A[row * n + k] * B[k * n + col];
        }
        C[row * n + col] = sum;
    }
}

// Initialize matrix with random values
void init_matrix(float *mat, int size) {
    for (int i = 0; i < size; i++) {
        mat[i] = (float)(rand() % 100) / 100.0f;
    }
}

// Verify result against CPU computation (spot check)
void verify(const float *A, const float *B, const float *C, int n) {
    int errors = 0;
    for (int i = 0; i < 10; i++) {
        int row = rand() % n;
        int col = rand() % n;
        float expected = 0.0f;
        for (int k = 0; k < n; k++) {
            expected += A[row * n + k] * B[k * n + col];
        }
        if (fabsf(expected - C[row * n + col]) / fabsf(expected) > 1e-3f) {
            errors++;
            printf("Mismatch at (%d,%d): expected %.6f, got %.6f\n",
                   row, col, expected, C[row * n + col]);
        }
    }
    if (errors == 0) printf("Verification PASSED (10 random elements checked)\n");
    else printf("Verification FAILED: %d mismatches\n", errors);
}

int main() {
    size_t bytes = N * N * sizeof(float);

    // Host allocation
    float *h_A = (float *)malloc(bytes);
    float *h_B = (float *)malloc(bytes);
    float *h_C = (float *)malloc(bytes);

    srand(42);
    init_matrix(h_A, N * N);
    init_matrix(h_B, N * N);

    // Device allocation
    float *d_A, *d_B, *d_C;
    cudaMalloc(&d_A, bytes);
    cudaMalloc(&d_B, bytes);
    cudaMalloc(&d_C, bytes);

    cudaMemcpy(d_A, h_A, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, bytes, cudaMemcpyHostToDevice);

    // Launch config: 16x16 threads per block
    dim3 blockDim(16, 16);
    dim3 gridDim((N + blockDim.x - 1) / blockDim.x,
                 (N + blockDim.y - 1) / blockDim.y);

    // Warmup
    gemm_naive<<<gridDim, blockDim>>>(d_A, d_B, d_C, N);
    cudaDeviceSynchronize();

    // Timed run
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    gemm_naive<<<gridDim, blockDim>>>(d_A, d_B, d_C, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float ms = 0.0f;
    cudaEventElapsedTime(&ms, start, stop);

    // Compute GFLOP/s: 2*N^3 FLOPs for matrix multiply
    double flops = 2.0 * (double)N * (double)N * (double)N;
    double gflops = (flops / (ms / 1000.0)) / 1e9;

    printf("=== Naive GEMM ===\n");
    printf("Matrix size: %d x %d\n", N, N);
    printf("Block size:  16 x 16\n");
    printf("Kernel time: %.3f ms\n", ms);
    printf("Performance: %.2f GFLOP/s\n", gflops);

    // Copy result back and verify
    cudaMemcpy(h_C, d_C, bytes, cudaMemcpyDeviceToHost);
    verify(h_A, h_B, h_C, N);

    // Cleanup
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);
    free(h_A);
    free(h_B);
    free(h_C);

    return 0;
}
