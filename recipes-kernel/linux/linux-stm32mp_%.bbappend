FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Odyssey (Seeed Studio Odyssey-STM32MP157C) BOARD SUPPORT ONLY.
#
# This is the base layer: it makes any Odyssey board boot through the
# OpenSTLinux secure flow (TF-A -> OP-TEE -> U-Boot -> Linux, SCMI clocks
# owned by OP-TEE). It carries no display, touch or demo-app code.
#
# The mainline stm32mp157c-odyssey.dts / -som.dtsi are already carried by the
# scarthgap ST kernel (6.6.129) and the stm32mp157c-odyssey.dtb is already in
# the ST Makefile.
#
#  0001  add the SCMI clock/reset overlay (required for the OP-TEE boot flow)
#
# For the Waveshare 3.5" SPI display + XPT2046 touch + the LVGL car-dashboard
# kiosk demo, add the separate meta-odyssey-demo layer - it carries its own
# kernel bbappend (SPI5 display DT + the ads7846 touch-controller fixes) on
# top of this one.
#
# NOTE: the old mickledore-era 6.1/6.1.82 patches (eth-phy VCO mdio rework,
# USB-host nodes) are intentionally dropped for now.
SRC_URI += " \
    file://${LINUX_VERSION}/${LINUX_VERSION}${LINUX_SUBVERSION}/0001-ARM-dts-stm32-add-SCMI-variant-for-stm32mp157c-odysse.patch \
"
