#include <iostream>
#include <cmath>
#include <unistd.h>
#include <stdlib.h>
#include "fpga_dma_st_utils.h"
#include "fpga_dma_st_common.h"
using namespace std;
static sem_t transfer_done;
static int err_cnt = 0;
#define ON_ERR_GOTO(res, label, desc)\
	do {\
		if ((res) != FPGA_OK) {\
			err_cnt++;\
			fprintf(stderr, "Error %s: %s\n", (desc), fpgaErrStr(res));\
			goto label;\
		}\
	} while (0)
volatile static uint64_t bytes_sent;
volatile static uint64_t bytes_rcvd;
volatile static bool eop_rcvd;
volatile static uint64_t cb_count;
fpga_token afc_tok;
fpga_dma_handle_t dma_h = NULL;
fpga_handle afc_h = NULL;
struct config accelerator_config = {
	.bus = CONFIG_UNINIT,
	.device = CONFIG_UNINIT,
	.function = CONFIG_UNINIT,
	.segment = CONFIG_UNINIT,
	.data_size = CONFIG_UNINIT,
	.payload_size = CONFIG_UNINIT,
	.direction = STDMA_INVAL_DIRECTION,
	.transfer_type = STDMA_INVAL_TRANSFER_TYPE,
	.loopback = STDMA_INVAL_LOOPBACK
};
struct time_record times;
static void mtosCb(void *ctx, fpga_dma_transfer_status_t status) {
	//printf("mtosCb %ld\n", cb_count);
	bytes_sent += status.bytes_transferred;
	return;
}
static double getBandwidth(size_t size, double seconds) {
	double throughput = (double)size/((double)seconds*1000*1000);
	return std::round(throughput);
}
// return elapsed time
static double getTime(struct timespec start, struct timespec end) {
	uint64_t diff = 1000000000L * (end.tv_sec - start.tv_sec) + end.tv_nsec - start.tv_nsec;
	return (double) diff/(double)1000000000L;
}
static fpga_result allocate_buffer(fpga_handle afc_h, struct buf_attrs *attrs)
{
	fpga_result res;
	if(!attrs)
		return FPGA_INVALID_PARAM;
	res = fpgaPrepareBuffer(afc_h, attrs->size, (void **)&(attrs->va), &attrs->wsid, 0);
	if(res != FPGA_OK)
		return res;
	res = fpgaGetIOAddress(afc_h, attrs->wsid, &attrs->iova);
	if(res != FPGA_OK) {
		res = fpgaReleaseBuffer(afc_h, attrs->wsid);
		return res;
	}
	//printf("Allocated test buffer of size = %ld bytes\n", attrs->size);
	return FPGA_OK;
}
static fpga_result free_buffer(fpga_handle afc_h, struct buf_attrs *attrs)
{
	if(!attrs)
		return FPGA_INVALID_PARAM;
	return fpgaReleaseBuffer(afc_h, attrs->wsid);
}
static void fill_buffer(uint64_t *buf, uint64_t *original, int length, int buf_size) {
	int count = buf_size;
	for (int i = 0; i < length; i++)
	{
		uint64_t tmp = (uint64_t)(original[i]);
		*buf = tmp;
		buf++;
		count-= sizeof(tmp);
	}
	uint64_t blank_word = 0x00000000;  //N-null
	while (count) {
		*buf = blank_word;
		count -= sizeof(blank_word);
		buf++;
	}
}
//计算数据总共的byte
static int get_buffer_size(int length, int& size) {
	int buffer_size = length * 8; //length * 64 / 8 
	int n = (int)(log(buffer_size)/log(2));
	if (buffer_size % MIN_PAYLOAD_SIZE == 0) {
		//buffer_size = length;
		size = buffer_size;
	}
	else {
		buffer_size = ((buffer_size/MIN_PAYLOAD_SIZE)+1) * MIN_PAYLOAD_SIZE;
		size = pow(2,n);
	}
	return buffer_size;
}
static void * m2sworker(void* arg) {
	struct timespec start, end;
	struct dma_config *dma_config = (struct dma_config *)arg;
	struct config *test_config = dma_config->config;
	fpga_result res = FPGA_OK;
	fpga_dma_transfer_t transfer;
	uint64_t src;
	res = fpgaDMATransferInit(&transfer);
	ON_ERR_GOTO(res, out, "allocating transfer");
	// do memory to stream transfer
	size_t total_size;
	total_size = test_config->data_size;
	uint64_t max;		
	max = ceil((double)test_config->data_size / (double)test_config->payload_size);
	uint64_t tid;
	tid = 0; // transfer id
	src = dma_config->battrs->iova;
	clock_gettime(CLOCK_MONOTONIC, &start);
	while(total_size > 0) {
		uint64_t transfer_bytes = MIN(total_size, test_config->payload_size);
		fpgaDMATransferSetSrc(transfer, src);
		fpgaDMATransferSetDst(transfer, (uint64_t)0);
		fpgaDMATransferSetLen(transfer, transfer_bytes);
		fpgaDMATransferSetTransferType(transfer, HOST_MM_TO_FPGA_ST);
		if(test_config->transfer_type == STDMA_TRANSFER_FIXED)
			fpgaDMATransferSetTxControl(transfer, TX_NO_PACKET);
		else {
			if(max == 1)  // we only have a single buffer
				fpgaDMATransferSetTxControl(transfer, GENERATE_SOP_AND_EOP);
			else if(tid == 0) // first buffer, set SOP
				fpgaDMATransferSetTxControl(transfer, GENERATE_SOP);
			else if(tid == max-1) // last buffer, set EOP
				fpgaDMATransferSetTxControl(transfer, GENERATE_EOP);
			else // set NO_PACKET otherwise
				fpgaDMATransferSetTxControl(transfer, TX_NO_PACKET);
		}
		if(tid == max-1) { // last transfer
			// last transfer is blocking
			fpgaDMATransferSetTransferCallback(transfer, NULL, NULL);
			fpgaDMATransferSetLast(transfer, true);
		}
		else {
			fpgaDMATransferSetTransferCallback(transfer, mtosCb, NULL);
			fpgaDMATransferSetLast(transfer, false);
		}
		res = fpgaDMATransfer(dma_config->dma_h, transfer);
		ON_ERR_GOTO(res, free_transfer, "transfer error");
		total_size -= transfer_bytes;
		src += transfer_bytes;
		tid++;
	}		
	clock_gettime(CLOCK_MONOTONIC, &end);
	dma_config->bw = getBandwidth(test_config->data_size, getTime(start,end));
free_transfer:
	res = fpgaDMATransferDestroy(&transfer);
	//printf("destroyed transfer\n");
out:
	return dma_config->dma_h;
}
fpga_result configure_numa(bool cpu_affinity, bool memory_affinity)
{
	fpga_result res = FPGA_OK;
	fpga_properties props;
	#ifndef USE_ASE
	// Set up proper affinity if requested
	if (cpu_affinity || memory_affinity) {
		unsigned dom = 0, bus = 0, dev = 0, func = 0;
		int retval;
		#if(FPGA_DMA_DEBUG)
				char str[4096];
		#endif
		res = fpgaGetProperties(afc_tok, &props);
		ON_ERR_GOTO(res, out, "fpgaGetProperties");
		res = fpgaPropertiesGetBus(props, (uint8_t *) & bus);
		ON_ERR_GOTO(res, out_destroy_prop, "fpgaPropertiesGetBus");
		res = fpgaPropertiesGetDevice(props, (uint8_t *) & dev);
		ON_ERR_GOTO(res, out_destroy_prop, "fpgaPropertiesGetDevice");
		res = fpgaPropertiesGetFunction(props, (uint8_t *) & func);
		ON_ERR_GOTO(res, out_destroy_prop, "fpgaPropertiesGetFunction");
		// Find the device from the topology
		hwloc_topology_t topology;
		hwloc_topology_init(&topology);
		hwloc_topology_set_flags(topology,
					HWLOC_TOPOLOGY_FLAG_IO_DEVICES);
		hwloc_topology_load(topology);
		hwloc_obj_t obj = hwloc_get_pcidev_by_busid(topology, dom, bus, dev, func);
		hwloc_obj_t obj2 = hwloc_get_non_io_ancestor_obj(topology, obj);
		#if (FPGA_DMA_DEBUG)
			hwloc_obj_type_snprintf(str, 4096, obj2, 1);
			printf("%s\n", str);
			hwloc_obj_attr_snprintf(str, 4096, obj2, " :: ", 1);
			printf("%s\n", str);
			hwloc_bitmap_taskset_snprintf(str, 4096, obj2->cpuset);
			printf("CPUSET is %s\n", str);
			hwloc_bitmap_taskset_snprintf(str, 4096, obj2->nodeset);
			printf("NODESET is %s\n", str);
		#endif
		if (memory_affinity) {
			#if HWLOC_API_VERSION > 0x00020000
				retval = hwloc_set_membind(topology, obj2->nodeset,
								HWLOC_MEMBIND_THREAD,
								HWLOC_MEMBIND_MIGRATE | HWLOC_MEMBIND_BYNODESET);
			#else
				retval =
				hwloc_set_membind_nodeset(topology, obj2->nodeset,
								HWLOC_MEMBIND_BIND,
								HWLOC_MEMBIND_THREAD | HWLOC_MEMBIND_MIGRATE);
			#endif
			ON_ERR_GOTO((fpga_result)retval, out_destroy_prop, "hwloc_set_membind");
		}
		if (cpu_affinity) {
			retval = hwloc_set_cpubind(topology, obj2->cpuset, HWLOC_CPUBIND_STRICT);
			ON_ERR_GOTO((fpga_result)retval, out_destroy_prop, "hwloc_set_cpubind");
		}
	}
out_destroy_prop:
	res = fpgaDestroyProperties(&props);
	#endif
out:
	return res;
}
int find_accelerator(const char *afu_id) {
	fpga_result res;
	fpga_guid guid;
	uint32_t num_matches = 0;
	fpga_properties filter = NULL;
	if(uuid_parse(DMA_AFU_ID, guid) < 0) {
		return 1;
	}
	res = fpgaGetProperties(NULL, &filter);
	ON_ERR_GOTO(res, out, "fpgaGetProperties");
	res = fpgaPropertiesSetObjectType(filter, FPGA_ACCELERATOR);
	ON_ERR_GOTO(res, out_destroy_prop, "fpgaPropertiesSetObjectType");
	res = fpgaPropertiesSetGUID(filter, guid);
	ON_ERR_GOTO(res, out_destroy_prop, "fpgaPropertiesSetGUID");
	if (CONFIG_UNINIT != accelerator_config.bus) {
		res = fpgaPropertiesSetBus(filter, accelerator_config.bus);
		ON_ERR_GOTO(res, out_destroy_prop, "setting bus");
	}
	if (CONFIG_UNINIT != accelerator_config.device) {
		res = fpgaPropertiesSetDevice(filter, accelerator_config.device);
		ON_ERR_GOTO(res, out_destroy_prop, "setting device");
	}
	if (CONFIG_UNINIT != accelerator_config.function) {
		res = fpgaPropertiesSetFunction(filter, accelerator_config.function);
		ON_ERR_GOTO(res, out_destroy_prop, "setting function");
	}
	res = fpgaEnumerate(&filter, 1, &afc_tok, 1, &num_matches);
	ON_ERR_GOTO(res, out_destroy_prop, "fpgaEnumerate");
out_destroy_prop:
	res = fpgaDestroyProperties(&filter);
	ON_ERR_GOTO(res, out, "fpgaDestroyProperties");
out:
	if (num_matches > 0)
		return (int)num_matches;
	else
		return 0;
}
fpga_result init_DMA() {
	fpga_result res;
	#ifndef USE_ASE
	volatile uint64_t *mmio_ptr = NULL;
	#endif
	sem_init(&transfer_done , 0, 0);
	res = fpgaOpen(afc_tok, &afc_h, 0);
	printf("opened afc handle\n");
	#ifndef USE_ASE
	res = fpgaMapMMIO(afc_h, 0, (uint64_t**)&mmio_ptr);
	printf("mapped mmio\n");
	#endif
	res = fpgaReset(afc_h);
	printf("applied afu reset\n");
	// Enumerate DMA handles
	uint64_t ch_count;
	ch_count = 0;
	res = fpgaCountDMAChannels(afc_h, &ch_count);
	if(ch_count < 1) {
		fprintf(stderr, "DMA channels not found (found %ld, expected %d\n", ch_count, 2);
	}
	printf("found %ld dma channels\n", ch_count);
	res = fpgaDMAOpen(afc_h, 0, &dma_h);
	printf("opened memory to stream channel\n");
	return res;
}
bool init_accelerator()
{
	accelerator_config.payload_size = MAX_PAYLOAD_SIZE;
	accelerator_config.transfer_type = STDMA_TRANSFER_FIXED;
	accelerator_config.loopback = STDMA_LOOPBACK_OFF;
	accelerator_config.direction = STDMA_MTOS;
	fpga_result res = FPGA_OK;
	int ret = find_accelerator(DMA_AFU_ID);
	if (ret < 0) {
		fprintf(stderr, "failed to find accelerator\n");
		return false;
	} else if (ret > 1) {
		fprintf(stderr, "Found more than one suitable slot, "
			"please be more specific.\n");
		return false;
	} else {
		bool cpu_affinity = true;
		bool memory_affinity = true;
		printf("found %d accelerator(s)\n", ret);
		res = configure_numa(cpu_affinity, memory_affinity);
		ON_ERR_GOTO(res, out, "configuring NUMA affinity");
		res = init_DMA();
		ON_ERR_GOTO(res, out, "error do_action");
		return true;
	}
out:
	return false;
}
fpga_result send_data(uint64_t* genocase, int caselen, uint64_t* genoctrl, int ctrllen) {
	fpga_result res = FPGA_OK;
	struct buf_attrs cases = {
		.va = NULL,
		.iova = 0,
		.wsid = 0,
		.size = 0
	};
	struct buf_attrs ctrls = {
		.va = NULL,
		.iova = 0,
		.wsid = 0,
		.size = 0
	};
	int case_payload_size = MIN_PAYLOAD_SIZE;
	int ctrl_payload_size = MIN_PAYLOAD_SIZE;
	int case_buf_size = get_buffer_size(caselen, case_payload_size);
	int ctrl_buf_size = get_buffer_size(ctrllen, ctrl_payload_size);
	cases.size = case_buf_size;
	ctrls.size = ctrl_buf_size;
	res = allocate_buffer(afc_h, &cases);
	res = allocate_buffer(afc_h, &ctrls);
    fill_buffer((uint64_t *)cases.va, genocase, caselen, case_buf_size);
	fill_buffer((uint64_t *)ctrls.va, genoctrl, ctrllen, ctrl_buf_size);
	struct dma_config m2s_worker_struct;
  printf("sending case data...\n");	
	fpgaWriteMMIO64(afc_h, 0, FPGA_DMA_ONE_TO_TWO_MUX_CSR, 0x0);
	accelerator_config.data_size = case_buf_size;
	accelerator_config.payload_size = case_payload_size;
	m2s_worker_struct.afc_h = afc_h;
	m2s_worker_struct.dma_h = dma_h;
	m2s_worker_struct.config = &accelerator_config;
	m2s_worker_struct.battrs = &cases;
	m2sworker((void*)&m2s_worker_struct);
	std::cout << "Memory to Stream BW = " << m2s_worker_struct.bw << "MBps" << endl;
	printf("sending ctrl data...\n");
	fpgaWriteMMIO64(afc_h, 0, FPGA_DMA_ONE_TO_TWO_MUX_CSR, 0x1);
	accelerator_config.data_size = ctrl_buf_size;
	accelerator_config.payload_size = ctrl_payload_size;
	m2s_worker_struct.afc_h = afc_h;
	m2s_worker_struct.dma_h = dma_h;
	m2s_worker_struct.config = &accelerator_config;
	m2s_worker_struct.battrs = &ctrls;
	m2sworker((void*)&m2s_worker_struct);
	std::cout << "Memory to Stream BW = " << m2s_worker_struct.bw << "MBps" << endl;
	if(cases.va) {
		free_buffer(afc_h, &cases);
	}
	if(ctrls.va) {
		free_buffer(afc_h, &ctrls);
	}
	return res;
}
fpga_result close_accelerator() {
	fpga_result res = FPGA_OK;
	if(dma_h) {
		res = fpgaDMAClose(dma_h);
		printf("closed dma channel\n");
	}
	#ifndef USE_ASE
	if(afc_h) {
		res = fpgaUnmapMMIO(afc_h, 0);
		printf("unmapped mmio\n");
	}
	#endif
	if (afc_h) {
		res = fpgaClose(afc_h);
		printf("closed afc\n");
	}
	sem_destroy(&transfer_done);
	fpgaDestroyToken(&afc_tok);
	return res;
}
processor_result do_action(uint64_t* genocase, uint64_t* genoctrl, processor_config cfg)
{
	fpga_result res = FPGA_OK;
	struct processor_result results;
	struct timespec start, end, exec;
	clock_gettime(CLOCK_MONOTONIC, &start);	
	res = init_processor(afc_h, cfg);
    ON_ERR_GOTO(res, out, "error");
	res = send_data(genocase, cfg.caselen, genoctrl, cfg.ctrllen);
	ON_ERR_GOTO(res, out, "error");
    clock_gettime(CLOCK_MONOTONIC, &end);
    times.sendtime = getTime(start,end);
	clock_gettime(CLOCK_MONOTONIC, &exec);
	res = run_processor(afc_h);
	ON_ERR_GOTO(res, out, "error");
	clock_gettime(CLOCK_MONOTONIC, &end);
	times.exectime = getTime(exec,end);
	res = get_result(afc_h, &results);
	ON_ERR_GOTO(res, out, "error");
	clock_gettime(CLOCK_MONOTONIC, &end);
	times.totaltime = getTime(start,end);
    printf("==========TIME USED==========\n");
    printf("transfer time = %f ms\n", times.sendtime*1000);
	printf("fpga exec time = %f ms\n", times.exectime*1000);
	printf("total time = %f ms\n", times.totaltime*1000);
out:
	return results;
}
bool do_prepare(uint64_t* genocase, uint64_t* genoctrl, processor_config cfg) {
	fpga_result res = FPGA_OK;
	res = init_processor(afc_h, cfg);
	int caselen = cfg.caselen;
	int ctrllen = cfg.ctrllen;
	res = send_data(genocase, caselen, genoctrl, ctrllen);
	if (res != FPGA_OK)
		return false;
	return true;
}
processor_result do_calculate(processor_config cfg) {
	fpga_result res = FPGA_OK;
	struct processor_result results;
	res = modify_processor(afc_h, cfg);
    ON_ERR_GOTO(res, out, "error");
	res = run_processor(afc_h);
	ON_ERR_GOTO(res, out, "error");
	res = get_result(afc_h, &results);
	ON_ERR_GOTO(res, out, "error");
out:
	return results;
}
