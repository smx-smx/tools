# lan8900

Tool to decrypt the `upgrade.lgu` file for the LG LAN8900 (Kia Carens/Kia Sportage, and others)

## Details

The `upgrade.lgu` file is a disguised corrupted Rar archive (probably as an attempt to confuse people).\
It has a `Rar!` signature at offset 0x400 (after the LGU header), but it will actually decrypt to `PK` (zip) once the XOR table is applied to the file.

This process is carried out by the update tool, `Abraham.exe`, as part of `CLguStreamFilter::DoFilter`.\
The resulting file will be a password-protected `.zip` file, which can be extracted with `7-Zip` like any normal zip file.

The password (also found from `Abraham.exe`) is `I_LOVE_LG^^`, as seen in `CLguFile::_Open`
