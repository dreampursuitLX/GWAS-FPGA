/**
 * \fpga_dma_st_common.h
 * \brief FPGA STDMA Common Header
 */
#ifndef __FPGA_DMA_ST_COM_H__
#define __FPGA_DMA_ST_COM_H__
#define FPGA_DMA_ST_ERR(msg_str) \
		fprintf(stderr, "Error %s: %s\n", __FUNCTION__, msg_str);
#define MIN(X,Y) (X<Y)?X:Y
// Convenience macros
#ifdef FPGA_DMA_DEBUG
#define debug_print(fmt, ...) \
do { \
	if (FPGA_DMA_DEBUG) {\
		fprintf(stderr, "%s (%d) : ", __FUNCTION__, __LINE__); \
		fprintf(stderr, fmt, ##__VA_ARGS__); \
	} \
} while (0)
#define error_print(fmt, ...) \
do { \
	fprintf(stderr, "%s (%d) : ", __FUNCTION__, __LINE__); \
	fprintf(stderr, fmt, ##__VA_ARGS__); \
	err_cnt++; \
 } while (0)
#else
#define debug_print(...)
#define error_print(...)
#endif
#endif // __FPGA_DMA_ST_COM_H__
