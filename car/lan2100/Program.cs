/**
  * Copyright(C) 2024 Stefano Moioli <smxdev4@gmail.com>
  **/

﻿if(args.Length < 2){
	Console.Error.WriteLine("Usage: [upgrade.lgu] [output.zip]");
	Environment.Exit(1);
}

const int LGU_HEADER_SIZE = 1024;

using var stream = new FileStream(
	args[0],
	FileMode.Open,
	FileAccess.Read,
	FileShare.Read);

stream.Position = LGU_HEADER_SIZE;

var xorTbl = File.ReadAllBytes("xortbl.bin");
var idx = 0;

using var outFile = new FileStream(
	args[1],
	FileMode.OpenOrCreate,
	FileAccess.ReadWrite,
	FileShare.Read
);
outFile.SetLength(0);

while(true){
	var b = stream.ReadByte();
	if(b < 0) break;

	b ^= xorTbl[idx];
	idx = (idx + 1) % 1024;

	outFile.WriteByte((byte)b);
}
