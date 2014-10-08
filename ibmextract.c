/*
 ibmextract - a tool to extract various IBM Server update packages
 Author: smx

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful, 
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <string.h>
#include <arpa/inet.h>
#include <libgen.h>
#include <unistd.h>
#include <getopt.h>

#include <linux/limits.h>
#include <ibmextract.h>

char *remove_ext(const char* mystr) {
	char *retstr, *lastdot;
	if (mystr == NULL) return NULL;
	if ((retstr = (char *)malloc(strlen(mystr) + 1)) == NULL) return NULL;
	strcpy(retstr, mystr);
	lastdot = strrchr (retstr, '.');
	if (lastdot != NULL) *lastdot = '\0';
	return retstr;
}

char *trim(char *str){
	char *end;

	// Trim leading space
	while(isspace(*str)) str++;

	if(*str == 0)  // All spaces?
		return str;

	// Trim trailing space
	end = str + strlen(str) - 1;
	while(end > str && isspace(*end)) end--;

	// Write new null terminator
	*(end+1) = 0;

	return str;
}

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

static void _mkdir(const char *dir) {
	char tmp[PATH_MAX];
	char *p = NULL;
	size_t len;

	snprintf(tmp, sizeof(tmp), "%s" ,dir);
	len = strlen(tmp);
	if(tmp[len - 1] == '/')
		tmp[len - 1] = 0;
	for(p = tmp + 1; *p; p++){
		if(*p == '/') {
			*p = 0;
			mkdir(tmp, S_IRWXU);
			*p = '/';
		}
	}
	mkdir(tmp, S_IRWXU);
}

void fancyprint(char *str){
	int i, j=strlen(str);
	const char *pre="| ";
	const char *post=" |";
	j+=strlen(pre)+strlen(post);
	for(i=0; i<j; i++) putchar('-'); printf("\n");
	printf("%s%s%s\n", pre, str, post);
	for(i=0; i<j; i++) putchar('-'); printf("\n");
}

int main(int argc, char *argv[]){
	int status = EXIT_SUCCESS;
	static int extract_hdr = 0, debug=0;
	static char *dest_dir;
	char *file_name = NULL;
	int c;

	fancyprint("IBM Power Server update extractor v0.3 by Smx");
	while (1){
		static struct option long_options[] = {
			{"extract-headers", no_argument, &extract_hdr, 1},
			{"debug", no_argument, &debug, 1},
		};
		/* getopt_long stores the option index here. */
		int option_index = 0;
		c = getopt_long (argc, argv, "",
						long_options, &option_index);

		/* Detect the end of the options. */
		if (c == -1) break;
		switch (c) {
			case 0x0:
				continue;
			default:
				goto usage;
		}
	}
	//char *outname;
	char outname[PATH_MAX];
	int start = 0;
	if(optind < argc){
		while(optind < argc){
			switch(start){
				case 0: //first argument, filename
					file_name = strdup(argv[optind]);
					break;
				case 1: //second argument, destdir
					strcpy(outname, argv[optind]);
					dest_dir = strdup(argv[optind]);
					break;
			}
			optind++;
			start++;
		}
	}

	if(start == 1){
		dest_dir = ".";
	} else if(start < 2){
		goto usage;
	}

	FILE *out = NULL;
	if(file_name == NULL){
		usage:
			printf("Usage: \n\t %s [input file] [[output dir]] [[--extract-headers]] [[--debug]]\n\n", argv[0]);
			return EXIT_FAILURE;
	}

	FILE *infile = fopen(file_name, "rb");
	if(!infile){
		fprintf(stderr, "Cannot open file '%s'\n", file_name);
		return EXIT_FAILURE;
	}
	int fd = fileno(infile);

	struct stat statbuf;
	if (fstat(fd, &statbuf) < 0) {
		perror("fstat failed");
		return EXIT_FAILURE;
	}

	char *fullpath = realpath(dest_dir, NULL);
	sprintf(fullpath, "%s/%s", fullpath, remove_ext(basename(strdup(file_name))));
	sprintf(dest_dir, "%s/%s", dest_dir, remove_ext(basename(strdup(file_name))));
	printf("making dir %s\n", fullpath);
	_mkdir(fullpath);
	//dest_dir = &outname;
	printf("Extracting '%s' to '%s'\n", file_name, dest_dir);	

	unsigned char *buffer = NULL;
	int filesize = statbuf.st_size;
	if(filesize <= 0) goto notfwupd;

	if ((buffer = mmap(NULL, filesize, PROT_WRITE, MAP_PRIVATE, fd, 0)) == MAP_FAILED) {
		fprintf(stderr, "\nCannot mmap input file (%s). Aborting\n\n", strerror(errno));
		return EXIT_FAILURE;
	}
	
	if(memcmp(buffer, meta_magic, member_size(meta_header_t, magic)) != 0){
		notfwupd:
			fprintf(stderr, "File '%s' is not a valid IBM firmware update\n", file_name);
			status = !status;
			goto finish;
	}

	meta_header_t *header = (meta_header_t *)buffer;
	pak_record_t *file_entry = NULL;
	file_header_t *file_header = NULL;

	//dump meta header
	if(extract_hdr){
		sprintf(outname, "%s/%s.hdr", dest_dir, basename(file_name));
		out = fopen(outname, "wb");
		fwrite(header, 1, ntohl(header->headerSize), out);
		fflush(out);
		fclose(out);
	}

	swap32(header->headerSize);	
	printf("----------Informations----------\n");
	printf("Number of packages: \t %d\n", header->pakCount);
	printf("File Name: \t\t '%s'\n\n", trim(strdup(header->filename)));
	hexprint(header->fwVer, sizeof(header->fwVer), "FW version: ");
	
	int i;
	unsigned char *unk;
	char *filename;
	unsigned char *file_start;
	for(i=0; i<header->pakCount; i++){
		file_entry = (pak_record_t *)(buffer+header->headerSize+(i*sizeof(pak_record_t)));
		//dump file record
		if(extract_hdr){
			sprintf(outname, "%s/rec_%d.hdr", dest_dir, i+1);
			out = fopen(outname, "wb");
			fwrite(file_entry, 1, sizeof(pak_record_t), out);
			fflush(out);
			fclose(out);
		}
		
		swap32(file_entry->offset);
		swap32(file_entry->size);
		swap32(file_entry->checksum);
		file_header = (file_header_t *)(buffer+file_entry->offset);
		
		//dump file header
		if(extract_hdr){
			sprintf(outname, "%s/file_%d.hdr", dest_dir, i+1);
			out = fopen(outname, "wb");
			fwrite(file_header, 1, ntohl(file_header->headerSize), out);
			fflush(out);
			fclose(out);
		}
		

		if(memcmp(file_header->magic, file_magic,
					member_size(file_header_t, magic)) != 0){
			printf("Unknown magic 0x%x, skipping...\n");
			continue;
		}

		filename = file_header->filename;
		filename = (char *)basename(filename);
		switch(*filename){
			case '.':
				sprintf(outname, "%s/file_%d.pak", dest_dir, i+1);
				break;
			case '/':
				sprintf(outname, "%s/roofts_%d.pak", dest_dir, i+1);
				break;
			default:
				sprintf(outname, "%s/%s_%d.pak", dest_dir, filename, i+1);
				break;
		}
		int dc = 0;
		float size = file_entry->size;
		char *sizestr = malloc(strlen(size_mbyte)+5);
		while((int)size/1024 > 0){
			size /= 1024;
			dc++;
		}
		switch(dc){
			case 0:
				strcpy(sizestr, size_byte);
				break;
			case 1:
				strcpy(sizestr, size_kbyte);
				break;
			case 2:
				strcpy(sizestr, size_mbyte);
				break;
		}

		printf("#%u/%u Extracting PAK at 0x%x (%0.2f %s) to '%s'...\n", i+1, header->pakCount, file_entry->offset,
														size, sizestr, outname);
		free(sizestr);

		swap32(file_header->filesize);
		swap32(file_header->headerSize);
		swap32(file_header->checksum);
		if(debug){
			printf("---------------------------\n");
			printf("Unknown: %02x %02x %02x %02x\n", *(file_header->unknown), *(file_header->unknown+1),
													*(file_header->unknown+2), *(file_header->unknown+3));
			printf("Date: %02x%02x/%02x/%02x %02x:%02x\n", file_header->date[0], file_header->date[1],
							file_header->date[2], file_header->date[3],	file_header->date[4], file_header->date[5]);
			hexprint(file_header->unknown2, sizeof(file_header->unknown2), "Unknown: ");
			printf("Checksum: %x\n", file_header->checksum);
			printf("File size: %d\n", file_header->filesize);
			printf("Header Size: %d\n", file_header->headerSize);
			printf("Flags: %02x %02x\n", *(file_header->flags), *(file_header->flags+1));
			printf("File name header: %x\n", file_header->fnstart);
			printf("File name: %s\n", file_header->filename);
		}
		file_start = (unsigned char *)file_header + file_header->headerSize;
		if(debug){
			unk =  file_start - 5;
			hexprint(unk, 0x5, "Unknown: ");
			printf("File start: 0x%x\n", file_start - buffer);
			printf("---------------------------\n");
		}
		
		//dump file content
		out = fopen(outname, "wb");
		if(out == NULL){
			printf("Cannot open the file for writing\n");
			status = !status;
			goto finish;
		}
		fwrite(file_start, 1, file_header->filesize, out);
		fflush(out);
		fclose(out);
	}

	finish:
	if (buffer && munmap(buffer, filesize) < 0){
		perror("un-mmapping failed");
		if(infile) close(fd);
		return EXIT_FAILURE;
	}
	if(infile) close(fd);
	if(status == EXIT_SUCCESS)
		printf("Extraction Completed!\n");
	return status;
}
