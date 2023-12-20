#include "fpga_dma_st_common.h"
#include "fpga_processor.h"
#include <math.h>
#include <unistd.h>
#include <stdlib.h>
// return elapsed time
static double getTime(struct timespec start, struct timespec end) {
	uint64_t diff = 1000000000L * (end.tv_sec - start.tv_sec) + end.tv_nsec - start.tv_nsec;
	return (double) diff/(double)1000000000L;
}
fpga_result copy_to_mmio(fpga_handle fpga_h, uint32_t *ctrl_addr, int len) {
	int i=0;
	fpga_result res = FPGA_OK;
	if(len % DWORD_BYTES != 0) 
		return FPGA_INVALID_PARAM;
	uint64_t csr_addr = (uint64_t)M2S_CSR_ADDRESS;
	for(i = 0; i < len/DWORD_BYTES; i++) {
		res = fpgaWriteMMIO32(fpga_h, 0, csr_addr, *ctrl_addr);
		if(res != FPGA_OK)
			return res;
		ctrl_addr += 1;
		csr_addr += DWORD_BYTES;
	}
	return FPGA_OK;
}
fpga_result init_processor(fpga_handle fpga_h, processor_config config) {
    fpga_result res = FPGA_OK;
	processor_status_t status ={0};
	res = modify_processor(fpga_h, config);
	do {
		res = fpgaReadMMIO32(fpga_h, 0, M2S_CSR_ADDRESS+offsetof(processor_control_t, csr), &status.reg);
	} while(!status.st.busy);
	printf("processor is ready\n");
	return res;	
}
fpga_result modify_processor(fpga_handle fpga_h, processor_config config) {
	processor_control_t pctrl = {0};
	processor_ctrl_t ctrl = {0};
	fpga_result res = FPGA_OK;
	ctrl.go = 1;
	ctrl.cleae_done = 0;
	ctrl.start = 0;
	ctrl.stop = 0;
	pctrl.nlongintcase = config.nlongintcase;
	pctrl.nlongintctrl = config.nlongintctrl;
	pctrl.ncase = config.ncase;
	pctrl.nctrl = config.nctrl;
	pctrl.threshold = config.threshold;
	pctrl.snp = config.p;
	pctrl.csr = ctrl.reg;
	res = copy_to_mmio(fpga_h, (uint32_t*)&pctrl, (sizeof(pctrl)));
	return res;
}
fpga_result run_processor(fpga_handle fpga_h) {
	fpga_result res = FPGA_OK;
	struct timespec start, end1, end2;
	processor_status_t status ={0};
	//start boost
    fpgaWriteMMIO32(fpga_h, 0, M2S_CSR_ADDRESS+offsetof(processor_control_t, csr), 0x80000001);
	//wait boost ready
	do {
		res = fpgaReadMMIO32(fpga_h, 0, M2S_CSR_ADDRESS+offsetof(processor_control_t, csr), &status.reg);
	} while(status.st.ready);
	bool flag = true; 
	clock_gettime(CLOCK_MONOTONIC, &start);	
	//printf("waiting processor complete...\n");
	do {
		res = fpgaReadMMIO32(fpga_h, 0, M2S_CSR_ADDRESS+offsetof(processor_control_t, csr), &status.reg);
		if (flag && status.st.table_done == 1) {
			flag = false;
			clock_gettime(CLOCK_MONOTONIC, &end1);	
		}
	} while(status.st.done != 1);
	clock_gettime(CLOCK_MONOTONIC, &end2);	
	printf("processor done!\n");
	double part1 = getTime(start,end1);
	double part2 = getTime(start,end2);
	printf("first part time = %f ms\n", part1*1000);
	printf("second part time = %f ms\n", part2*1000);
	return res;
}
fpga_result get_result(fpga_handle fpga_h, struct processor_result *result) {
	fpga_result res = FPGA_OK;
	uint32_t data = 0;
	res = fpgaReadMMIO32(fpga_h, 0, M2S_CSR_ADDRESS, &data);
	result->snp_pair_num = data;
	result->snp_pair = static_cast<uint32_t*>(malloc((result->snp_pair_num) * sizeof(uint32_t)));
	for (int i =0; i < result->snp_pair_num; i ++) {
		res = fpgaReadMMIO32(fpga_h, 0, M2S_CSR_ADDRESS+0x4, &data);
		result->snp_pair[i] = data;
	}
    //clear done
	fpgaWriteMMIO32(fpga_h, 0, M2S_CSR_ADDRESS+offsetof(processor_control_t, csr), 0x80000002);
	return res;
}
