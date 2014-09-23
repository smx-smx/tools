#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <string.h>
#include <arpa/inet.h>
#include <libgen.h>

typedef struct {
	unsigned char magic[4]; //55 49 00 01
	unsigned char fwVer[6]; //version of fw, not sure how to read it. last 2 seem to always be 00 00
	unsigned int headerSize;
	unsigned char padding;
	unsigned int pakCount;
	unsigned char filename[];
}__attribute__((packed)) meta_header_t;

typedef struct {
	unsigned char type[2];
	unsigned char flags[2];
	unsigned int size; //including header
	unsigned int offset;
	unsigned int checksum;
}__attribute__((packed)) pak_record_t;

typedef struct {
	unsigned char magic[4]; //02 22 00 03
	unsigned char unknown[4];
	unsigned char date[6]; /* 20 12 01 19 17 31, aka Y/M/D H:M  */
	unsigned char unknown2[2];
	unsigned int checksum;
	unsigned int filesize;
	unsigned int headerSize;
	unsigned char flags[2];
	unsigned short fnstart; //00 04 pair
	unsigned char filename[];
}__attribute__((packed)) file_header_t;

const char meta_magic[] = "\x55\x49\x00\x01";
const char file_magic[] = "\x02\x22\x00\x03";
#define member_size(type, member) sizeof(((type *)0)->member)
#define swap32(x) x = ntohl(x)

char *remove_ext(const char *mystr);
char *remove_ext(const char* mystr) {
	char *retstr, *lastdot;
	if (mystr == NULL) return NULL;
	if ((retstr = (char *)malloc(strlen(mystr) + 1)) == NULL) return NULL;
	strcpy(retstr, mystr);
	lastdot = strrchr (retstr, '.');
	if (lastdot != NULL) *lastdot = '\0';
	return retstr;
}

void hexprint(unsigned char *src, int num, const char *format, ...);
void hexprint(unsigned char *src, int num, const char *format, ...){
	va_list args;
    va_start(args, format);
	vfprintf( stdout, format, args );
    va_end(args);
	int i;
	for(i=0; i<num; i++){
		if(i != 0) printf(" ");
		printf("%02x", *(src+i));
	}
	printf("\n");
}

int main(int argc, char *argv[]){
	FILE *out = NULL;
	char outname[50];
	printf("IBM Update file extractor v0.3 by Smx ;)\n");
	if(argc < 2){
		printf("Usage: %s [in]\n", argv[0]);
		return EXIT_FAILURE;
	}

	int fd = open(argv[1], O_RDONLY);
	if(!fd){
		printf("Cannot open file '%s'\n", argv[1]);
		return EXIT_FAILURE;
	}

	struct stat statbuf;
	if (fstat(fd, &statbuf) < 0) {
		printf("\nfstat error\n\n");
		return EXIT_FAILURE;
	}
	
	int fileLength = statbuf.st_size;
	unsigned char *buffer;
	if ( (buffer = mmap(NULL, fileLength, PROT_WRITE, MAP_PRIVATE, fd, 0)) == MAP_FAILED ) {
		printf("\nCannot mmap input file (%s). Aborting\n\n", strerror(errno));
		return EXIT_FAILURE;
	}
	
	if(memcmp(buffer, meta_magic, member_size(meta_header_t, magic)) != 0){
		printf("File '%s' is not a valid IBM firmware update\n");
		goto finish;
	}

	meta_header_t *header = (meta_header_t *)buffer;
	pak_record_t *file_entry = NULL; //buffer+sizeof(meta_header_t); //first entry after meta header
	file_header_t *file_header = NULL;
	
	//dump meta header
	strcpy(outname, basename(strdup(argv[1])));
	strcat(outname, ".hdr");
	out = fopen(outname, "wb");
	fwrite(header, 1, ntohl(header->headerSize), out);
	fflush(out);
	fclose(out);

	swap32(header->headerSize);	
	printf("------Informations------\n");
	printf("Number of packages: %d\n", header->pakCount);
	printf("File Name: %s\n\n", header->filename);
	hexprint(header->fwVer, sizeof(header->fwVer), "Fw version: ");
	
	int i;
	unsigned char *unk;
	char *filename;
	unsigned char *file_start;
	for(i=0; i<header->pakCount; i++){
		file_entry = (pak_record_t *)(buffer+header->headerSize+(i*sizeof(pak_record_t)));
		//dump file record
		sprintf(outname, "rec_%d.hdr", i);
		out = fopen(outname, "wb");
		fwrite(file_entry, 1, sizeof(pak_record_t), out);
		fflush(out);
		fclose(out);
		
		swap32(file_entry->offset);
		swap32(file_entry->size);
		swap32(file_entry->checksum);
		file_header = (file_header_t *)(buffer+file_entry->offset);
		
		//dump file header
		sprintf(outname, "file_%d.hdr", i);
		out = fopen(outname, "wb");
		fwrite(file_header, 1, ntohl(file_header->headerSize), out);
		fflush(out);
		fclose(out);
		
		printf("\n[+]Pak Number %d\n", i);
		printf("Offset: 0x%x\n", file_entry->offset);
		printf("Size: %d\n", file_entry->size);
		if(memcmp(file_header->magic,
					file_magic,
					member_size(file_header_t, magic)
					) != 0) continue;
		swap32(file_header->filesize);
		swap32(file_header->headerSize);
		swap32(file_header->checksum);
		printf("\n---------------------------\n");
		printf("Unknown: %02x %02x %02x %02x\n", *(file_header->unknown), *(file_header->unknown+1), *(file_header->unknown+2), *(file_header->unknown+3));
		printf("Date: %02x%02x/%02x/%02x %02x:%02x\n", file_header->date[0], file_header->date[1], file_header->date[2], file_header->date[3],
														file_header->date[4], file_header->date[5]);
		hexprint(file_header->unknown2, sizeof(file_header->unknown2), "Unknown: ");
		printf("Checksum: %x\n", file_header->checksum);
		printf("File size: %d\n", file_header->filesize);
		printf("Header Size: %d\n", file_header->headerSize);
		printf("Flags: %02x %02x\n", *(file_header->flags), *(file_header->flags+1));
		printf("File name header: %x\n", file_header->fnstart);
		printf("File name: %s\n", file_header->filename);
		file_start = (unsigned char *)file_header + file_header->headerSize;
		unk =  file_start - 5;
		hexprint(unk, 0x5, "Unknown: ");
		printf("File start: 0x%x\n", file_start - buffer);
		printf("---------------------------\n");
		filename = file_header->filename;
		filename = (char *)basename(filename);
		if(*filename == '.')
			sprintf(outname, "file_%d", i);
		else if(*filename == '/')
			sprintf(outname, "roofts_%d", i);
		else
			sprintf(outname, "%s_%d", filename, i);
		
		//dump file content
		strcpy(outname, remove_ext((char *)&outname));
		strcat(outname, ".pak");
		printf("Saving to '%s'\n", outname);
		out = fopen(outname, "wb");
		if(!out){
			printf("Cannot open the file for writing\n");
			goto finish;
		}
		fwrite(file_start, 1, file_header->filesize, out);
		fflush(out);
		fclose(out);
	}

	finish:
	if (munmap(buffer, fileLength) == -1){
		printf("Error un-mmapping the file");
		close(fd);
		return EXIT_FAILURE;
	}
	close(fd);
	return EXIT_SUCCESS;
}