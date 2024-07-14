# waylandhax
 
Webos Wayland surface hook via LD_PRELOAD.

This library makes it possible to run WebOS-unaware Wayland applications on LG WebOS.

It does so by intercepting `WL_COMPOSITOR_CREATE_SURFACE` and calling `webos_surface_attach` on the resulting surface, which will then report the `appId` and `displayAffinity` to WebOS.

- `appId` is controlled by the `APP_ID` environment variable, and defaults to `com.sample.waylandegl` if not set.
- `displayAffinity` is controlled by the `DISPLAY_ID` environment variable, and defaults to `0` if not set