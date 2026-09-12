FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Odyssey (Seeed Studio Odyssey-STM32MP157C) BOARD SUPPORT ONLY.
#
#  0001  add the "linaro,optee-tz" TEE client node U-Boot's stm32mp_bsec
#        driver needs to reach OP-TEE's PTA_BSEC for OTP access (MAC
#        address, board ID, ...). Without it every BSEC call falls
#        back to the legacy raw-SMC path, which fails once OP-TEE owns
#        BSEC exclusively: "stm32_smc: Failed to exec svc=82001003
#        op=1 in secure mode (err = -1)", "Error: ethernet@5800a000
#        address not set." ST's own DK1/DK2/ED1 get this via their
#        -scmi.dtsi overlays; this board never had one.
#
# NOTE: an earlier attempt here patched U-Boot's own PLL4 devicetree
# config, assuming U-Boot's clk-stm32mp1.c clobbered TF-A's eth-PHY
# PLL4 fix on every boot. That assumption was wrong: the PLL
# reconfiguration code in that driver is gated
# "#if defined(CONFIG_SPL_BUILD)", and this board's boot flow has no
# U-Boot SPL stage at all (TF-A replaces it) - so that code path never
# runs here, the patch was dead weight, and it's been removed.
SRC_URI += " \
    file://0001-ARM-dts-stm32mp157c-odyssey-add-optee-tee-client-node.patch \
"
