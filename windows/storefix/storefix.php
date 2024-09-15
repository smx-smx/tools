<?php
function path_combine(string ...$parts){
    return implode(DIRECTORY_SEPARATOR, $parts);
}
$programFiles = getenv("ProgramFiles");
foreach(glob(path_combine($programFiles, "WindowsApps", "*", "AppxManifest.xml")) as $manifest){
    $inner = implode(' ', [
        'Add-AppxPackage',
        '-Register',
        escapeshellarg($manifest),
        '-DisableDevelopmentMode'
    ]);
    $hProc = proc_open([
        'powershell', '-Command', $inner
    ], [], $p);
    proc_close($hProc);
}
