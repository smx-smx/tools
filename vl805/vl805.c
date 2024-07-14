/**
 * @file vl805.c
 * @author Stefano Moioli <smxdev4@gmail.com>
 * @brief Abstract initialization flow for VL805
 * @version 0.1
 * @date 2024-07-07
 * 
 * @copyright Copyright (c) 2024 Stefano Moioli
 * This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
 * 
 *     1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
 *     2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
 *     3. This notice may not be removed or altered from any source distribution.
 */

#include <stdint.h>
#include <unistd.h>

#define IN
#define OUT

typedef intptr_t EFI_STATUS;
typedef uint32_t UINT32;
typedef uintptr_t UINTN;
typedef void VOID;

typedef enum {
  EfiPciIoWidthUint8 = 0,
  EfiPciIoWidthUint16,
  EfiPciIoWidthUint32,
  EfiPciIoWidthUint64,
  EfiPciIoWidthFifoUint8,
  EfiPciIoWidthFifoUint16,
  EfiPciIoWidthFifoUint32,
  EfiPciIoWidthFifoUint64,
  EfiPciIoWidthFillUint8,
  EfiPciIoWidthFillUint16,
  EfiPciIoWidthFillUint32,
  EfiPciIoWidthFillUint64,
  EfiPciIoWidthMaximum
} EFI_PCI_IO_PROTOCOL_WIDTH;

typedef
EFI_STATUS
(*pfnPciRead)(
  IN     EFI_PCI_IO_PROTOCOL_WIDTH    Width,
  IN     UINT32                       Offset,
  IN     UINTN                        Count,
  IN OUT VOID                         *Buffer
);

typedef
EFI_STATUS
(pfnPciWrite)(
  IN     EFI_PCI_IO_PROTOCOL_WIDTH    Width,
  IN     UINT32                       Offset,
  IN     UINTN                        Count,
  IN OUT VOID                         *Buffer
);

#define VIA_REG_FLAGS 0x43
#define VIA_REG_ADDR 0x78
#define VIA_REG_DATA 0x7C
#define VIA_REG_CTRL 0x7E

pfnPciRead pci_read;
pfnPciWrite pci_write;

uint8_t firmware[0x4000];
uint8_t memoryMap[0x18000];

static inline uint8_t via_readflags(){
	uint8_t flags = 0;
	pci_read(EfiPciIoWidthUint8, VIA_REG_FLAGS, 1ULL, &flags);
	return flags;
}
static inline void via_writeflags(uint8_t flags){
	pci_write(EfiPciIoWidthUint8, VIA_REG_FLAGS, 1ULL, &flags);
}
static inline void via_writecfg16(uint32_t addr, uint16_t data){
	pci_write(EfiPciIoWidthUint32, VIA_REG_ADDR, 1, &addr);
	pci_write(EfiPciIoWidthUint16, VIA_REG_CTRL, 1, &data);
}
static inline void via_write8(uint32_t addr, uint8_t data){
	pci_write(EfiPciIoWidthUint32, VIA_REG_ADDR, 1, &addr);
	pci_write(EfiPciIoWidthUint8, VIA_REG_DATA, 1, &data);
}
static inline void via_write16(uint32_t addr, uint16_t data){
	pci_write(EfiPciIoWidthUint32, VIA_REG_ADDR, 1, &addr);
	pci_write(EfiPciIoWidthUint16, VIA_REG_DATA, 1, &data);
}
static inline void via_write32(uint32_t addr, uint32_t data){
	pci_write(EfiPciIoWidthUint32, VIA_REG_ADDR, 1, &addr);
	pci_write(EfiPciIoWidthUint32, VIA_REG_DATA, 1, &data);
}
static inline uint8_t via_read8(uint32_t addr){
	uint8_t v = 0;
	pci_write(EfiPciIoWidthUint32, VIA_REG_ADDR, 1, &addr);
	pci_read(EfiPciIoWidthUint8, VIA_REG_DATA, 1, &v);
	return v;
}
static inline uint16_t via_read16(uint32_t addr){
	uint8_t v = 0;
	pci_write(EfiPciIoWidthUint32, VIA_REG_ADDR, 1, &addr);
	pci_read(EfiPciIoWidthUint16, VIA_REG_DATA, 1, &v);
	return v;
}
static inline uint32_t via_read32(uint32_t addr){
	uint32_t v = 0;
	pci_write(EfiPciIoWidthUint32, VIA_REG_ADDR, 1, &addr);
	pci_read(EfiPciIoWidthUint32, VIA_REG_DATA, 1, &v);
	return v;
}

void leave_mfg_mode(){
	uint8_t flags = via_readflags();
	flags &= 1u;
	via_writeflags(flags);
}

void enter_mfg_mode(){
	uint8_t flags = via_readflags();
	flags |= 1u;
	via_writeflags(flags);
}

void firmware_write(){
	uint8_t *pData;
	pData = firmware;
	for(int i=0; i<0x3000; i++, pData++){
		via_write32(i + 0x52000, __builtin_bswap32(*pData));
	}
	via_write8(0x51000, 0x4C);
	via_write8(0x51004, 0x80);
	usleep(15 * 200);
}

void firmware_verify(){
	uint8_t *pData = firmware;
	for(int i=0; i<0x3000; i++, pData++){
		uint32_t readBack = via_read32(0x52000 + i);
		if((uint8_t)readBack != *pData){
			uint8_t readBack_byte;
			do {
				via_write8(0x51000, 0x48);
				via_write8(0x51004, 0);
				usleep(15 * 200);
				via_write32(0x52000 + i, __builtin_bswap32(*pData));
				via_write8(0x51000, 0x4C);
				via_write8(0x51004, 0x80);
				usleep(15 * 200);
				readBack_byte = via_read8(0x52000 + i);
			} while(readBack_byte != *pData);
		}
	}
	via_write8(0x51000, 0x48);
	via_write8(0x51004, 0);
}

void set_chip_configuration(){
	uint8_t flags8;
	uint16_t flags16;

	pci_read(EfiPciIoWidthUint8, 4, 1, &flags8);
	flags8 &= 0xF8;
	pci_write(EfiPciIoWidthUint8, 4, 1, &flags8);

	// must be page aligned
	uint32_t memAddr = (uintptr_t)&memoryMap >> 6;
	via_write32(0x30000, memAddr);
	flags8 = via_read8(0x30004);
	flags8 |= 1;
	via_write8(0x30004, flags8);
	flags16 = via_read16(0x30004);
	flags16 &= ~0x100;
	via_write16(0x30004, flags16);
	via_write32(0x3000C, 0x500);
	via_writecfg16(0x30008, flags16);
	flags16 = flags16 & 0x7FF | 0x1800;
	via_writecfg16(0x30008, flags16);
	flags8 = via_read8(0x30008);
	flags8 |= 1;
	via_write8(0x30008, flags8);
}

void init(){
	uint8_t ident;
	uint16_t vid, pid;

	pci_read(EfiPciIoWidthUint8, 9u, 1ULL, &ident);
	if(ident != 48) return;
	
	pci_read(EfiPciIoWidthUint16, 0, 1ULL, &vid);
	pci_read(EfiPciIoWidthUint16, 2u, 1ULL, &pid);
	if(vid != 0x1106 || pid != 0x3483) return;

	// populate firmware

	enter_mfg_mode();
	firmware_write();
	firmware_verify();
	set_chip_configuration();

	leave_mfg_mode();

	uint8_t flags8 = 7;
	pci_write(EfiPciIoWidthUint8, 4, 1, &flags8);
	pci_read(EfiPciIoWidthUint8, 4, 1, &flags8);
	usleep(15 * 2000);

	via_writeflags(1);
	via_read32(0x30008);
	via_writeflags(0);
}
