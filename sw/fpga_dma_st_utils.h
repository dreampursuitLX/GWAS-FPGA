/**
 * \fpga_dma_st_test_utils.h
 * \brief Streaming DMA test utils
 */
#ifndef __FPGA_DMA_ST_UTILS_H__
#define __FPGA_DMA_ST_UTILS_H__
#include <string.h>
#include <uuid/uuid.h>
#include <opae/fpga.h>
#include <time.h>
#include <stdlib.h>
#include <assert.h>
#include <semaphore.h>
#ifndef USE_ASE
#include <hwloc.h>
#endif
#include "fpga_dma.h"
#include "fpga_processor.h"
#include "fpga_dma_st_common.h"
#define DMA_AFU_ID				"EB59BF9D-B211-4A4E-B3E3-753CE68634BA"
// Single pattern is represented as 64Bytes
#define PATTERN_WIDTH 64
// No. of Patterns
#define PATTERN_LENGTH 32
#define MIN_PAYLOAD_LEN 64
#define CONFIG_UNINIT (0)
#define BEAT_SIZE (64) // bytes
#define FPGA_DMA_TWO_TO_ONE_MUX_CSR (0x40)
#define FPGA_DMA_ONE_TO_TWO_MUX_CSR (0x50)
#define MAX_PAYLOAD_SIZE 1048576
#define MIN_PAYLOAD_SIZE 64
#ifndef USE_ASE
//#include <hwloc.h>
#endif
enum stdma_loopback {
	STDMA_INVAL_LOOPBACK = 0,
	STDMA_LOOPBACK_ON,
	STDMA_LOOPBACK_OFF
};
enum stdma_direction {
	STDMA_INVAL_DIRECTION = 0,
	STDMA_MTOS,
	STDMA_STOM
};
enum stdma_transfer_type {
	STDMA_INVAL_TRANSFER_TYPE = 0,
	STDMA_TRANSFER_FIXED,
	STDMA_TRANSFER_PACKET
};
struct config {
	int bus;
	int device;
	int function;
	int segment;
	uint64_t data_size;
	uint64_t payload_size;
	enum stdma_direction direction;
	enum stdma_transfer_type transfer_type;
	enum stdma_loopback loopback;
	uint16_t decim_factor;
};
struct dma_config {
		fpga_handle afc_h;
		fpga_dma_handle_t dma_h;
		struct config *config;
		unsigned long long int bw;
		struct buf_attrs *battrs;
};
struct buf_attrs {
	void *va;
	uint64_t iova;
	uint64_t wsid;
	uint64_t size;
};
struct time_record {
	double exectime;
	double totaltime;
	double sendtime;
};
bool init_accelerator();
fpga_result close_accelerator();
processor_result do_action(uint64_t* genocase, uint64_t* genoctrl, processor_config cfg);
bool do_prepare(uint64_t* genocase, uint64_t* genoctrl, processor_config cfg);
processor_result do_calculate(processor_config cfg);
#endif
