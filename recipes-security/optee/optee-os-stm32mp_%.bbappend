FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# OP-TEE 4.0.0-stm32mp has no Odyssey board DT. Add one, derived from the ST DK2
# (same SoM) but with the STPMIC1 relocated from I2C4 to I2C2 - the Odyssey wires
# the PMIC to the non-secure I2C2 bus. The patch:
#   * new core/arch/arm/dts/stm32mp157c-odyssey.dts: dk2 clone (#includes
#     stm32mp15xx-dkx.dtsi), model/compatible, serial0=&uart4, ETZPC I2C2 unlock,
#     /delete-node/ &pmic + re-add it under &i2c2 (PH4/PH5 AF4 = i2c2_pins_a).
#   * clk-stm32mp15.c + stm32mp1_rcc.h: register the I2C2 kernel clock as a
#     non-secure (N_S) clock, mirroring the existing I2C5 entry, so OP-TEE's
#     stm32_i2c driver can clk_dt_get it. Gated by CFG_WITH_NSEC_I2CS (below).
#   * conf.mk: register 157C_ODYSSEY in flavorlist-cryp-512M (512MB DDR ->
#     correct CFG_DRAM_SIZE / CFG_TZDRAM_START).
SRC_URI += " file://0001-stm32mp157c-odyssey-optee-dt.patch"

# The odyssey DT drives the STPMIC1 on I2C2 (a non-secure bus). OP-TEE's
# clk-stm32mp15 only registers non-secure I2C clocks under this switch.
EXTRA_OEMAKE:append = " CFG_WITH_NSEC_I2CS=y"
