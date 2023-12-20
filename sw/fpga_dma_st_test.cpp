#include <getopt.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <time.h>
#include "fpga_dma_st_utils.h"
#include "fpga_processor.h"
//typedef unsigned long long uint64;
struct genotype {
	uint64_t* genocase;
	uint64_t* genoctrl;
};
int GetDataSize(char* filename, int** DataSize)//每个文件的样本数和SNP数
{
	FILE* fp, * fp_i;
	int c, ndataset;
	time_t st, ed;
	int n = 0, p = 0;
	int i, flag, ii;
	char filename_i[100];
	fp = fopen(filename, "r");
	if (fp == NULL)
	{
		fprintf(stderr, "can't open input file %s\n", filename);
		exit(1);
	}
	ndataset = 0;
	while (!feof(fp)) {
		ndataset++;
		fscanf(fp, "%s\n", &filename_i);
	}
	*DataSize = (int*)calloc(ndataset * 2, sizeof(int));
	ii = 0;
	rewind(fp);
	while (!feof(fp)) {
		ii++;
		fscanf(fp, "%s\n", &filename_i);
		fp_i = fopen(filename_i, "r");
		if (fp_i == NULL)
		{
			fprintf(stderr, "can't open input file %s\n", filename_i);
			exit(1);
		}
		printf("start getting data size of file %d: %s\n", ii, filename_i);
		time(&st);
		//initialization
		if (ii == 1)
		{
			n = 0;//samples number
			// find the number of samples: n
			while (1)
			{
				int c = fgetc(fp_i);//read a character from the data file
				switch (c)
				{
				case '\n'://the end of line
					n++;
					break;
					// fall through,
					// count the '-1' element
				case EOF://file end
					goto out;
				default:
					;
				}
			}
		}
	out:
		rewind(fp_i);//Repositions the file pointer to the beginning of a file
		// find number of variables: p
		p = 0;
		i = 0;
		flag = 1;
		while (1)
		{
			c = getc(fp_i);
			if (c == '\n') goto out2;//end of line
			if (isspace(c))
			{
				flag = 1;
			}
			/*do {
				c = getc(fp);
				if(c=='\n') goto out2;//end of line
			} while(isspace(c));//space
			*/
			if (!isspace(c) && (flag == 1))
			{
				p++;//indicate the dimension of the vector
				flag = 0;
			}
		}
	out2:
		fclose(fp_i);
		time(&ed);
		//	DataSize[0] = n;
		(*DataSize)[ndataset * 0 + ii - 1] = n;
		(*DataSize)[ndataset * 1 + ii - 1] += p - 1;
	}
	fclose(fp);
	//printf("Data contains %d rows and %d column. \n", n, p);
	printf("cputime for getting data size: %d seconds.\n", (int)(ed - st);
	return ndataset;
}
genotype* loadData(int &n, int &p, int &ncase, int &nctrl, int &nlongintcase, int &nlongintctrl)
{
	FILE* fp, * fp_i;
	char filename_i[100];
	char filename[100] = "filenamelist.txt";
	fp = fopen(filename, "r");
	if (fp == NULL)
	{
		fprintf(stderr, "can't open input file %s\n", filename);
		return NULL;
	}
	printf("start loading ...\n");
	int* DataSize;
	int ndataset;
	//int n, p;  //n--number of samples; p number of varibles
	int i, j, ii, k;
	//int ncase, nctrl, nlongintcase, nlongintctrl;
	int tmp;
	int LengthLongType = 64;
	int icase, ictrl;
	int flag;
	struct genotype* pgeno;
	time_t st, ed;
	uint64_t mask1 = 0x0000000000000001;
	ndataset = GetDataSize(filename, &DataSize);
	n = DataSize[0];
	p = 0;
	printf("n = %d\n", n);
	for (i = 0; i < ndataset; i++)
	{
		p += DataSize[ndataset * 1 + i];
		printf("DataSize %d-th file: p[%d] = %d \n", i + 1, i + 1, DataSize[ndataset * 1 + i]);
	}
	printf("p = %d\n", p);
	// get ncase and nctrl
	i = 0;
	j = 0;
	ncase = 0;
	nctrl = 0;
	rewind(fp);
	// only use the first file to get ncase and nctrl
	fscanf(fp, "%s\n", &filename_i);
	printf("%s\n", filename_i);
	fp_i = fopen(filename_i, "r");
	while (!feof(fp_i)) {
		/* loop through and store the numbers into the array */
		if (j == 0)
		{
			//j = 0 means read ind class label y
			fscanf(fp_i, "%d", &tmp);
			if (tmp)
			{
				ncase++;
			}
			else
			{
				nctrl++;
			}
			j++;
		}
		else
		{
			fscanf(fp_i, "%d", &tmp);
			j++; //column index
			if (j == (DataSize[ndataset] + 1)) // DataSize[ndataset] is the nsnp in the first dataset
			{
				j = 0;
				i++; // row index
			}
		}
		if (i >= n)
		{
			break;
		}
	}
	printf("total sample: %d (ncase = %d; nctrl = %d).\n", n, (int)ncase, (int)nctrl);
	nlongintcase = ceil(((double)ncase) / LengthLongType);
	nlongintctrl = ceil(((double)nctrl) / LengthLongType);
	printf("nLongIntcase = %d; nLongIntctrl = %d.\n", nlongintcase, nlongintctrl);
	//calloc memory for bit representation
	pgeno = (struct genotype*)malloc(sizeof(struct genotype) * p * 3);// p SNPs, each contains 3 genotypes
	for (j = 0; j < 3 * p; j++)
	{
		(pgeno + j)->genocase = (uint64_t*)calloc(nlongintcase, sizeof(uint64_t));
		(pgeno + j)->genoctrl = (uint64_t*)calloc(nlongintctrl, sizeof(uint64_t));
	}
	//load data to bit representation
	rewind(fp);
	time(&st);
	j = 0; // column index
	ii = 0; // file index
	k = 0;
	while (!feof(fp)) {
		ii++;
		fscanf(fp, "%s\n", &filename_i);
		fp_i = fopen(filename_i, "r");
		if (fp_i == NULL)
		{
			fprintf(stderr, "can't open input file %s\n", filename_i);
			exit(1);
		}
		i = 0; //row index
		icase = -1;
		ictrl = -1;
		printf("Loading data in file %d: %s\n", ii, filename_i);
		while (!feof(fp_i)) {
			/* loop through and store the numbers into the array */
			if (j == 0)
			{
				//j = 0 means read class label y
				fscanf(fp_i, "%d", &tmp);
				if (tmp)
				{
					// tmp=1 means case
					icase++;
					flag = 1;
				}
				else
				{
					ictrl++;
					flag = 0;
				}
				j++;
			}
			else
			{
				fscanf(fp_i, "%d", &tmp);
				if (flag)
				{
					pgeno[(j + k - 1) * 3 + tmp].genocase[icase / LengthLongType] |= (mask1 << (icase % LengthLongType));
				}
				else
				{
					pgeno[(j + k - 1) * 3 + tmp].genoctrl[ictrl / LengthLongType] |= (mask1 << (ictrl % LengthLongType));
				}
				j++; //column index
				if (j == (DataSize[ndataset + ii - 1] + 1))
				{
					j = 0;
					i++; // row index
				}
			}
			if (i >= n)
			{
				break;
			}
		}
		fclose(fp_i);
		k += DataSize[ndataset + ii - 1];
	}
	fclose(fp);
	time(&ed);
	printf("cputime for loading data: %d seconds\n", (int)(ed - st);
	free(DataSize);
	return pgeno;
}
void printResult(processor_result result) {
	printf("==========Result==========\n");
	printf("snp pair num = %d\n", result.snp_pair_num);
	for (unsigned int i = 0; i < result.snp_pair_num; i++) {
		//int snp1 = result.snp_pair[i] >> 16;
		//int snp2 = result.snp_pair[i] & 0x0000ffff;
		//printf("snp pair: <%d, %d>\n", snp1, snp2);
	}
}
int main(int argc, char *argv[]) {
	int n, p = 0;
	int ncase, nctrl;
	int nlongintcase = 0, nlongintctrl = 0;
	int threshold = 30;
	struct genotype* pgeno = loadData(n, p, ncase, nctrl, nlongintcase, nlongintctrl);
    printf("snp num: %d\n", p);
    printf("ncase: %d, nctrl: %d\n", ncase, nctrl);
    printf("nlongintcase: %d, nlongintctrl: %d\n", nlongintcase, nlongintctrl);
	uint64_t* pcase = (uint64_t *)calloc(4 * p * nlongintcase, sizeof(uint64_t));
	uint64_t* pctrl = (uint64_t *)calloc(4 * p * nlongintctrl, sizeof(uint64_t));
	int caselen, ctrllen;
	int count = 0;
    p = atoi(argv[1]);
  	nlongintcase = 4;
  	nlongintctrl = 4;
  	ncase = 16;
  	nctrl = 16;
	for (int i = 0; i < p; i++)
	{
		for (int j = 0; j < nlongintcase; j++)
		{
			for (int k = 0; k < 3; k++)
			{
				pcase[count++] = (uint64_t) pgeno[3 * i + k].genocase[j];
			}
			pcase[count++] = (uint64_t)(i);
		}
	}
	caselen = count;
	count = 0;
	for (int i = 0; i < p; i++)
	{
		for (int j = 0; j < nlongintctrl; j++)
		{
			for (int k = 0; k < 3; k++)
			{
				pctrl[count++] = (uint64_t) pgeno[3 * i + k].genoctrl[j];
			}
			pctrl[count++] = (uint64_t)(i);
		}
	}
	ctrllen = count;
	bool res = init_accelerator();
	if (res) {
		processor_config pconfig;
		pconfig.caselen = caselen;
        pconfig.ctrllen = ctrllen;
		pconfig.ncase = ncase;
		pconfig.nctrl = nctrl;
		pconfig.nlongintcase = nlongintcase;
		pconfig.nlongintctrl = nlongintctrl;
		pconfig.p = p;
		pconfig.threshold = threshold;
		processor_result presult;
        presult = do_action(pcase, pctrl, pconfig);
		printResult(presult);
	} 
	res = close_accelerator();
	return 0;
}
