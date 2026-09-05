SUMMARY = "Odyssey LVGL car-dashboard kiosk image (no Weston)"
DESCRIPTION = "Minimal OpenSTLinux image that boots straight to the car-dashboard \
LVGL app on the ILI9486 SPI panel. Same firmware stack as st-image-weston \
(TF-A + OP-TEE + U-Boot), just a tiny rootfs with one app."

require recipes-st/images/st-image-core.bb

# the app + everything the SPI panel / touch needs
IMAGE_INSTALL:append = " \
    car-dashboard \
    kernel-modules \
    libgpiod-tools \
    evtest \
    fbset \
    fbgrab \
"

# no package feed / no Weston desktop here
IMAGE_FEATURES:remove = "package-management"

# boot straight to the app (multi-user, no graphical.target / display-manager)
SYSTEMD_DEFAULT_TARGET = "multi-user.target"

# Same sdcard-flashlayout shrink as st-image-weston.bbappend: the stock layout
# reserves a 4 GiB rootfs slot. Only an anonymous python func sticks here (the
# flashlayout class re-clobbers ...:sdcard:rootfs via expandKeys during parse).
python () {
    d.setVar('FLASHLAYOUT_PARTITION_SIZE:sdcard:rootfs', '1835008')
}
