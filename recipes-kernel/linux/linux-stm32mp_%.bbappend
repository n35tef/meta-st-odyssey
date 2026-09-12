FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Odyssey (Seeed Studio Odyssey-STM32MP157C) board support: makes the board
# boot through the OpenSTLinux secure flow (TF-A -> OP-TEE -> U-Boot -> Linux,
# SCMI clocks owned by OP-TEE).
#
# The mainline stm32mp157c-odyssey.dts / -som.dtsi are already carried by the
# scarthgap ST kernel (6.6.129) and the stm32mp157c-odyssey.dtb is already in
# the ST Makefile.
#
#  0001  add the SCMI clock/reset overlay (required for the OP-TEE boot flow)
#  0002  MAC-level PHY reset with a long settle delay
#        (snps,reset-gpio/snps,reset-delays-us = <0 30000 50000>),
#        matching the mickledore-era kernel patch (mingzq
#        <north_sea@qq.com>) that was dropped without replacement
#        during the scarthgap port. mainline's default per-PHY
#        reset-gpios only waits 300us after deassert before the MDIO
#        scan runs - nowhere near enough for the KSZ9031RN's internal
#        PLL to stabilize. Confirmed by direct testing this isn't a
#        probe-ordering/PMIC race (rebind 10+ min post-boot fails
#        identically) and isn't fixed by removing the GPIO reset
#        assertion entirely either - it needed the long delay.
#  0003  drop the eth0 assigned-clocks construct: ethck_k has exactly one
#        hardcoded parent ("ck_ker_eth", no mux of its own), so
#        "assigned-clock-parents = <&rcc PLL4_P>" can never succeed
#        (logged every boot as "clk: failed to reparent ethck_k to
#        pll4_p: -22") - a plain clk-core topology bug, unrelated to
#        OP-TEE/SCMI/secure boot, present even in current upstream
#        Linux. ST's own reference boards (DK1/DK2/EV1, via
#        stm32mp15xx-dkx.dtsi) never had this construct; the correct
#        clock (PLL4_P, now at the right 125MHz thanks to the TF-A/
#        OP-TEE PLL4 fixes in this same layer) is already selected by
#        the static st,eth-clk-sel default, same as on ST's own boards.
#
# NOTE: the old mickledore-era 6.1/6.1.82 patches (eth-phy VCO mdio rework,
# USB-host nodes) are intentionally dropped for now.
SRC_URI += " \
    file://${LINUX_VERSION}/${LINUX_VERSION}${LINUX_SUBVERSION}/0001-ARM-dts-stm32-add-SCMI-variant-for-stm32mp157c-odysse.patch \
    file://${LINUX_VERSION}/${LINUX_VERSION}${LINUX_SUBVERSION}/0002-ARM-dts-stm32mp157c-odyssey-mac-level-phy-reset-delay.patch \
    file://${LINUX_VERSION}/${LINUX_VERSION}${LINUX_SUBVERSION}/0003-ARM-dts-stm32mp157c-odyssey-drop-broken-eth-assigned.patch \
"
