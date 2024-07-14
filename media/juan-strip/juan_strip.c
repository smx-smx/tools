/**
 * Copyright (C) 2021 Stefano Moioli <smxdev4@gmail.com>
 * This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
 * 
 *     1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
 *     2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
 *     3. This notice may not be removed or altered from any source distribution.
 **/

// Error handling is left as an exercise for the reader

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>

#include <arpa/inet.h>


struct __attribute__((packed)) packet_hdr {
	uint8_t id0; // AA
	uint32_t packet_size;

	// is initial number random? seed?
	uint32_t counter; //01 EE 97 B1
	uint8_t unk0; //FC
	uint32_t data_size;
	uint16_t unk1; //01 00, 02 00...
};

void process(const char *outPath, uint8_t *pData, size_t dataSize){
	FILE *fhOut = fopen(outPath, "wb");

	struct packet_hdr hdr;
	size_t i = 0;
	while(i < dataSize){
		memcpy(&hdr, &pData[i], sizeof(hdr));
		hdr.packet_size = ntohl(hdr.packet_size);
		hdr.data_size = ntohl(hdr.data_size);

		fwrite(&pData[i+sizeof(hdr)], hdr.data_size, 1, fhOut);
		printf("[0x%x] %x\n", i, hdr.packet_size);
		i += hdr.packet_size + 5;
	}

	fclose(fhOut);
}

int main(int argc, char *argv[]){
	int fd_in = open(argv[1], O_RDONLY);

	struct stat statBuf;
	fstat(fd_in, &statBuf);

	void *pMem = mmap(0, statBuf.st_size, PROT_READ, MAP_SHARED, fd_in, 0);
	process(argv[2], (uint8_t *)pMem, statBuf.st_size);

	munmap(pMem, statBuf.st_size);
	close(fd_in);
	return 0;
}
