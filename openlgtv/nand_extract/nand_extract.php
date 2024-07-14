<?php
function kilo($n){ return $n * 1024; }
function mega($n){ return kilo($n) * 1024; }

function to_cmdline(array $cmd){
	return implode(' ', array_map('escapeshellarg', $cmd));
}

function make_pipe(array ...$cmds){
	$cmdlines = array_map('to_cmdline', $cmds);
	return implode('|', $cmdlines);
}

class Nand {
	public $ID;
	public $ERASESIZE;
	public $DATASIZE;
	public $SIZE;
	public $OBBSIZE;
	public $IN;

	
	public function make_write_command(int $start_block, int $num_blocks, int $mtd_num){
		$pages_per_erase = $this->ERASESIZE / $this->DATASIZE;

		$block_size = (0
			// data
			+ ($pages_per_erase * $this->DATASIZE)
			// obb
			+ ($pages_per_erase * $this->OBBSIZE)
		);


		$pipe = [
			['dd', 'if='.$this->IN,
			'bs='.$block_size,
			'skip='.$start_block, 'count='.$num_blocks],
			['nandwrite', '-qo', "/dev/mtd{$mtd_num}"]
		];
		
		$cmd = ['sh', '-c', make_pipe(...$pipe)];
		return $cmd;
	}
}

$nand = new Nand;
$nand->ID = "\xAF\xF1\x00\x1D";
$nand->ERASESIZE = kilo(128);
$nand->DATASIZE = kilo(2);
$nand->SIZE = mega(128);
$nand->OBBSIZE = 64;
$nand->IN = $argv[1];
$TWO_PASS = true;

begin:
$cmds = [];
$cmds[] = ['rmmod', 'mtdblock', 'nandsim'];

$mount = ['modprobe', 'nandsim'];
$mount[] = 'first_id_byte=0x' . bin2hex($nand->ID[0]);
$mount[] = 'second_id_byte=0x' . bin2hex($nand->ID[1]);
$mount[] = 'third_id_byte=0x' . bin2hex($nand->ID[2]);
$mount[] = 'fourth_id_byte=0x' . bin2hex($nand->ID[3]);
$mount[] = 'overridesize=' . log($nand->SIZE / $nand->ERASESIZE) / log(2);
$parts=[];

$data = file('mtdinfo.txt', FILE_SKIP_EMPTY_LINES | FILE_IGNORE_NEW_LINES);

$last_block = 0;
foreach($data as $l){
	if(!preg_match_all("/0x[0-9a-fA-F]{8}/", $l, $m)) continue;
	$m = array_map('hexdec', $m[0]);
	list($start, $end) = $m;
	
	$size = $end - $start;
	$eraseblocks = $size / $nand->ERASESIZE;

	$start_block = $start / $nand->ERASESIZE;
	$end_block = $start_block + $eraseblocks;

	// if new start block is past the last one
	if($start_block > $last_block){
		$padding = $start_block - $last_block;
		$parts[count($parts) - 1] += $padding;
	}

	$parts[] = $eraseblocks;
	$last_block = $end_block;
}

$mount[] = 'parts=' . implode(',', $parts);
$cmds[] = $mount;


$current_block = 0;
foreach($parts as $i => $blocks){
	$cmds[] = $nand->make_write_command($current_block, $blocks, $i);
	$current_block += $blocks;
}

$cmds[] = ['modprobe', 'mtdblock'];

$cmds[] = ['rm', '-r', 'out'];
$cmds[] = ['mkdir', 'out'];

foreach($parts as $i => $_){
	$cmds[] = ['dd', "if=/dev/mtdblock{$i}", "of=out/mtdblock{$i}.bin"];
}
$cmds[] = ['chmod', '-R', '666', 'out'];
$cmds[] = ['chmod', '755', 'out'];
$cmds[] = ['sh', '-c',
	'if [ ! -z "$SUDO_USER" ]; then chown -R $SUDO_USER out; fi'];
$cmds[] = ['sh', '-c',
	preg_replace('/(\r?\n)|\t/', ' ', <<<'EOS'
	for file in out/*; do
		sudo -u $SUDO_USER 
			fakeroot /home/$SUDO_USER/epk2extract/build_linux/epk2extract $file;
	done
	EOS)
];

if($TWO_PASS){
	/** copy new partition table */
	$cmds[] = ['sh', '-c', 
		'cp out/*.txt mtdinfo.txt'
	];
}

foreach($cmds as $i => $c){
	$s_c = implode(' ', $c);
	print("[{$i}] {$s_c}\n");
}

foreach($cmds as $c){
	$h = proc_open($c, [], $p);
	proc_close($h);
}

if($TWO_PASS){
	$TWO_PASS = false;
	goto begin;
}
