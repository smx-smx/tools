# nand_extract

A small utility to extract a NAND flash dump from an LG TV.

In order to run this tool, you need:
- a 1:1 NAND flash dump from a LG TV
- The partition table, aka `mtdinfo.txt` obtained from the LG EPK through [epk2extract](https://github.com/openlgtv/epk2extract)

This rool runs on linux and requires `mtdblock` and `nandsim` kernel modules
