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
#  0002  fix the board DTS's wrong PHY MDIO address (0 -> 7, matches the
#        kernel and the vendor image); add phy-reset-gpios, consumed by
#        0003's driver change; add st,eth-clk-sel, which is what actually
#        fixed "EQOS_DMA_MODE_SWR stuck" every boot - without it,
#        board_interface_eth_init() (board/st/stm32mp1/stm32mp1.c) never
#        sets SYSCFG PMCSETR's eth1_clk_sel bit, so the SoC's 125MHz
#        PLL4_P-derived clock (confirmed correct via "clk dump") never
#        gets routed out to the PHY at all - the DMA soft-reset then
#        never completes (confirmed stuck at the register level via
#        "md.l 0x5800b000 1", unaffected by any amount of extra delay -
#        this is documented DWC_EQOS behavior: the reset needs a live
#        PHY-side clock present). The kernel's DTS always had this
#        property; this separate, older U-Boot board DTS never did.
#  0003  drivers/net/dwc_eth_qos.c: the STM32 variant of this driver never
#        drives a PHY reset GPIO at all. Not what was blocking
#        DMA_MODE_SWR (that was 0002's st,eth-clk-sel), but still needed
#        for the MDIO scan afterwards - this PHY needs an active pulse,
#        confirmed on the kernel side earlier in this same layer's
#        history. Adds an optional phy-reset-gpios path, no-op for every
#        board that doesn't set the property.
#
# NOTE: an earlier attempt here patched U-Boot's own PLL4 devicetree
# config, assuming U-Boot's clk-stm32mp1.c clobbered TF-A's eth-PHY
# PLL4 fix on every boot. That assumption was wrong: the PLL
# reconfiguration code in that driver is gated
# "#if defined(CONFIG_SPL_BUILD)", and this board's boot flow has no
# U-Boot SPL stage at all (TF-A replaces it) - so that code path never
# runs here, the patch was dead weight, and it's been removed.
#  0004  enable CONFIG_PHY_MICREL/PHY_MICREL_KSZ90X1 in stm32mp15_defconfig -
#        neither was set, so the KSZ9031RN bound to U-Boot's generic PHY
#        driver, which skips vendor-specific setup this PHY needs before
#        autonegotiation completes.
SRC_URI += " \
    file://0001-ARM-dts-stm32mp157c-odyssey-add-optee-tee-client-node.patch \
    file://0002-ARM-dts-stm32mp157c-odyssey-fix-phy-addr-add-reset.patch \
    file://0003-net-dwc_eth_qos-stm32-active-phy-reset-gpio.patch \
    file://0004-configs-stm32mp15-enable-Micrel-KSZ9031-PHY-driver.patch \
"
