FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Odyssey (Seeed Studio Odyssey-STM32MP157C) support.
#
# The mainline stm32mp157c-odyssey.dts / -som.dtsi are already carried by the
# scarthgap ST kernel (6.6.129) and the stm32mp157c-odyssey.dtb is already in
# the ST Makefile.
#
#  0001  add the SCMI clock/reset overlay (required for the OP-TEE boot flow)
#  0002  wire the Waveshare 3.5" ILI9486 SPI TFT + XPT2046 touch onto the 40-pin
#        header (SPI5). Needs the fragment below (fbtft lives in staging, which
#        the ST cleanup fragment turns off).
#
# NOTE: the old mickledore-era 6.1/6.1.82 patches (eth-phy VCO mdio rework,
# USB-host nodes) are intentionally dropped for now.
SRC_URI += " \
    file://${LINUX_VERSION}/${LINUX_VERSION}${LINUX_SUBVERSION}/0001-ARM-dts-stm32-add-SCMI-variant-for-stm32mp157c-odysse.patch \
    file://${LINUX_VERSION}/${LINUX_VERSION}${LINUX_SUBVERSION}/0002-ARM-dts-stm32mp157c-odyssey-add-SPI5-ILI9486-display.patch \
    file://odyssey/fragment-90-spi-tft-display.config;subdir=fragments \
"

KERNEL_CONFIG_FRAGMENTS:append = " ${WORKDIR}/fragments/odyssey/fragment-90-spi-tft-display.config"
