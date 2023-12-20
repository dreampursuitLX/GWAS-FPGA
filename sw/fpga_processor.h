#ifndef __PROCESSOR_H__
#define __PROCESSOR_H__
#include <opae/fpga.h>
#include <time.h>
// slave port address
#define M2S_PATTERN_ADDRESS  0x1000
#define M2S_CSR_ADDRESS   0x3000
// Single pattern is represented as 64Bytes
#define PATTERN_WIDTH 64
// No. of Patterns
#define PATTERN_LENGTH 32
#define QWORD_BYTES 8
#define DWORD_BYTES 4
typedef union {
	uint32_t reg;
	struct {
		uint32_t start:1;
		uint32_t cleae_done:1;
		uint32_t reserved3:28;
		uint32_t stop:1;
		uint32_t go:1;
	} ;
} processor_ctrl_t;
typedef union {
	uint32_t reg;
	struct {
		uint32_t busy:1;
		uint32_t done:1;
		uint32_t ready:1;
		uint32_t table_done:1;
		uint32_t reserved:28;
	} st;
} processor_status_t;
typedef struct __attribute__((__packed__)) {
	//0x0
	uint16_t nlongintcase;
	uint16_t nlongintctrl;
	//0x4
	uint16_t ncase;
	uint16_t nctrl;
	//0x8
	uint16_t snp;
	uint16_t threshold;
	//0xC
	uint32_t csr;
} processor_control_t;
struct processor_config {
	int ncase;
	int nctrl;
	int nlongintcase;
	int nlongintctrl;
	int p;
	int threshold;
	int caselen;
	int ctrllen;
};
struct processor_result{
	uint32_t snp_pair_num;
	uint32_t *snp_pair; 
};
fpga_result init_processor(fpga_handle fpga_h, processor_config config);
fpga_result modify_processor(fpga_handle fpga_h, processor_config config);
fpga_result run_processor(fpga_handle fpga_h);
fpga_result get_result(fpga_handle fpga_h, struct processor_result *result);
#endif 