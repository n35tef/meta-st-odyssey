FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Odyssey (Seeed Studio Odyssey-STM32MP157C) BOARD SUPPORT ONLY.
#
# ST's own TF-A fork already carries this board's DT (fdts/stm32mp157c-odyssey.dts
# + -som.dtsi + -fw-config.dts) upstream - no board-bring-up patch is needed here.
# But that upstream -som.dtsi leaves PLL4 at its generic default (VCO 594MHz ->
# PLL4_P = 99MHz), even though it already selects PLL4_P as the Ethernet clock
# parent (CLK_ETH_PLL4P). The onboard KSZ9031RN needs an exact 125MHz RGMII
# reference clock, which 99MHz cannot provide - the kernel's own (also
# upstream, unpatched) ethernet0 node already requests
# `assigned-clock-rates = <125000000>` on PLL4_P; without this patch that
# request can never be satisfied and the PHY link never comes up.
#
#  0001  raise PLL4 VCO from 594MHz to 750MHz (P = 99MHz -> 125MHz)
SRC_URI += " \
    file://0001-fix-raise-PLL4-VCO-to-750MHz-for-eth-phy.patch \
"
