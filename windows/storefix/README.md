# storefix
If you have ever encountered the error `The database disk image is malformed`, and you have deleted `StateRepository` from `\ProgramData\Microsoft\Windows\AppRepository` as specified in [this forum post](https://answers.microsoft.com/en-us/windows/forum/all/get-appxpackage-the-database-disk-image-is/a08ae8a1-20b3-4491-82a6-8c1e04ca3e15), you will notice that none of the window app will then work (Store, Notepad, Paint, etc.... - even the Start Menu).

To fix this situation, you need to re-register all Windows apps.
This script is a quick tool i wrote on the fly to do just that.
