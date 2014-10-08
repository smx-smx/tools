#ifndef __IBMEXTRACT_H
#define __IBMEXTRACT_H
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

const char size_byte[] = "B";
const char size_kbyte[] = "KB";
const char size_mbyte[] = "MB";

#define member_size(type, member) sizeof(((type *)0)->member)
#define swap32(x) x = ntohl(x)

#endif
