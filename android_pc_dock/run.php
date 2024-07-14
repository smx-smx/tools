<?php
function shell(string ...$parts){
	$cmd = implode(' ', $parts);
	print(">>> {$cmd}\n");
	$out = shell_exec($cmd);
	print("<<< {$out}\n");
	return $out;
}

function adb_shell_pipe(string ...$parts){
	$hProc = proc_open([
		'adb',
		'shell',
		'cat - | sh'
	], [
		0 => ['pipe', 'r'],
		1 => ['pipe', 'w'],
	], $pipes);

	$cmd = implode(' ', $parts);
	print(">>> {$cmd}\n");
	
	fwrite($pipes[0], "{$cmd}\n");
	fclose($pipes[0]);

	$out = stream_get_contents($pipes[1]);
	proc_close($hProc);

	print("<<< {$out}\n");
	return $out;
}

function adb(string ...$parts){
	return shell('adb', ...$parts);
}
function ashell(string ...$parts){
	return adb_shell_pipe(...$parts);
}

function services_get(){
	$out = rtrim(ashell('settings', 'get', 'secure', 'enabled_accessibility_services'));
	$list = explode(':', $out);
	return array_flip($list);
}

function services_set($services){
	$list = implode(':', array_keys($services));
	ashell('settings', 'put', 'secure', 'enabled_accessibility_services', $list);
}

function service_enable($service, bool $enable){
	$svcs = services_get();
	if($enable){
		$svcs[$service] = true;
	} else {
		unset($svcs[$service]);
	}
	services_set($svcs);
}

function ime_get(){
	return rtrim(ashell('settings', 'get', 'secure', 'default_input_method'));
}

function density_get(){
	$out = rtrim(ashell('wm', 'density'));
	if(!empty($out) && preg_match('/:\s*(\d+)/', $out, $m)){
		return intval($m[1]);
	}
	return null;
}

$previous_ime = ime_get();
$previous_density = density_get();
if($empty($previous_ime)){
	print("[WARNING]: could not retrieve current IME\n");
	$previous_ime = 'com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME';
}
if(empty($previous_density)){
	print("[WARNING]: could not retrieve current screen density!");
	exit(1);
}

$rotation_svc = 'com.pranavpandey.rotation/com.pranavpandey.rotation.service.RotationService';

/** disable and kill service **/
service_enable($rotation_svc, false);
ashell('am', 'force-stop', 'com.pranavpandey.rotation');

/** make sure the app won't be killed */
ashell('dumpsys', 'deviceidle', 'whitelist', '+com.pranavpandey.rotation');

/** start app **/
ashell('am', 'start', 'com.pranavpandey.rotation');

/** start service */
$wait = 5;
print("waiting {$wait} seconds\n");
sleep($wait);
service_enable($rotation_svc, true);

/** switch to landscape mode */
ashell('am', 'broadcast',
'-a', 'com.pranavpandey.rotation.intent.action.ROTATION_ACTION',
'-n', 'com.pranavpandey.rotation/.receiver.ActionReceiver',
'--es', 'com.pranavpandey.rotation.intent.extra.ACTION',
<<<EOS
'{\""action\"": 104}'
EOS);

/** disable virtual keyboard */
ashell('ime', 'set', 'com.wparam.nullkeyboard/.NullKeyboard');

/** change display density */
ashell('wm', 'density', '215');

/** start scrcpy, with "show touches" option */
shell('scrcpy -t');

/**** if we got here, scrcpy has been stopped. revert everything **/

/** reset rotation to system default */
ashell('am', 'broadcast',
'-a', 'com.pranavpandey.rotation.intent.action.ROTATION_ACTION',
'-n', 'com.pranavpandey.rotation/.receiver.ActionReceiver',
'--es', 'com.pranavpandey.rotation.intent.extra.ACTION',
<<<EOS
'{\""action\"": 103}'
EOS);

/** disable and kill service */
service_enable($rotation_svc, false);
ashell('am', 'force-stop', 'com.pranavpandey.rotation');

//ashell('pm', 'clear', 'com.pranavpandey.rotation');

/** restore screen density */
ashell('wm', 'density', $previous_density);
/** restore virtual keyboard */
ashell('ime', 'set', $previous_ime);
