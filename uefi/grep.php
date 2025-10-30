<?php
/**
 * grep.php
 * author: Stefano Moioli <smxdev4@gmail.com>
 *
 * Custom variant of grep that supports:
 * - utf8/utf16 strings
 * - hex BE/LE patterns
 */
define("CHUNKSIZE", 1024*1024);

function scangrep(string $path, array $queries, int $maxQLength){
	$offset = 0;

	$fh = @fopen($path, 'rb');
	if(!is_resource($fh)){
		return false;
	}

	while(!feof($fh)){
		fseek($fh, $offset);
		$chunk = fread($fh, CHUNKSIZE);

		foreach($queries as $q){
			$match_pos = strpos($chunk, $q);
			if($match_pos !== false){
				$match_offset = $offset + $match_pos;

				// found, don't try other queries (TODO: flag?)
				fclose($fh);
				return $match_offset;
			}
		}

		$read = strlen($chunk);
		if($read > $maxQLength){
			/**
			 * if we didn't match, and we read more than the query length
			 * we want to make sure the biggest query is included in the window
			 * so we don't skip a partial match
			 */
			$advance = $read - $maxQLength;
			$offset += $advance;
		} else {
			$offset += $read;
		}
	}
	fclose($fh);

	return false;
}

function utf16(string $text){
	return mb_convert_encoding($text, "UTF-16LE", "UTF-8");
}

// get queries
function get_qs(string $mode, string $text){
	$opts = substr($mode, 2);
	$opts = str_split($opts);
	$opts = array_flip($opts);

	$has_opt = function(string $opt) use($opts){
		return isset($opts[$opt]);
	};

	switch($mode[1]){
		// string
		case "s":
			yield $text;
			
			// multi encoding
			if($has_opt('s')){
				yield utf16($text);
			}
			
			// case insensitive
			if($has_opt('i')){
				yield strtolower($text);
				if($has_opt('s')){
					yield utf16(strtolower($text));
				}
			}
			break;
		// hex
		case "x":
			$hex = str_replace(' ', '', $text);
			yield hex2bin($hex);

			// multi endian
			if($has_opt('x')){
				$bytesHex = str_split($hex, 2);
				$hexReverse = implode('', array_reverse($bytesHex));
				yield hex2bin($hexReverse);
			}
			
			
			break;
	}
}

function get_qs_getopt(int $argc, array $argv){
	$opts = getopt("s::x::", [], $optind);
	$has_mode = function(string $opt) use($opts){
		return isset($opts[$opt]);
	};

	if($has_mode('s')){
		$mode = '-s' . $opts['s'];
	} else if($has_mode('x')){
		$mode = '-x' . $opts['x'];
	} else {
		throw new InvalidArgumentException();
	}

	$text = $argv[$optind];
	return get_qs($mode, $text);
}

if($argc > 2){
	$mode = $argv[1];
	$text = $argv[2];
	$where = $argv[3] ?? null;
} else {
	$text = $argv[1];
	$mode = '-x';
	$where = $rgv[2] ?? null;
}

if($where === null){
	$where = __DIR__;
}

$qs = iterator_to_array(get_qs($mode, $text));

foreach($qs as $q){
	print("- q: " . bin2hex($q) . "\n");
}

if(is_dir($where)){
	$dit = new RecursiveDirectoryIterator($where);
	$it = new RecursiveIteratorIterator($dit);
} else {
	$it = new ArrayIterator([
		new SplFileObject($where)
	]);
}

$ql = array_map('strlen', $qs);
sort($ql, SORT_NUMERIC);
$maxQLength = end($ql);

foreach($it as $file){
	/** @var SplFileObject $file */
	if(!$file->isFile()) continue;
	$path = $file->getPathname();

	$ext = $file->getExtension();
	if($ext === 'dmp') continue;

	if(($pos = scangrep($path, $qs, $maxQLength)) !== FALSE){
		$dir = dirname($path);

		$friendly_name = "";
		$uefi_ui_files = glob("{$dir}/*.ui");
		if(count($uefi_ui_files) > 0){
			$friendly_name = implode(",", array_map(function($f){
				$dat = file_get_contents($f);
				return str_replace("\x00", "", $dat);
			}, $uefi_ui_files));
		}

		$path = preg_replace("|/cygdrive/(.*?)/|", '$1:/', $path);
		printf("[%20s:0x%x] {$path}\n", $friendly_name, $pos);
	}
}
