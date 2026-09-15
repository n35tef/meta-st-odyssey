# meta-st-odyssey — scarthgap / OpenSTLinux port: full change report

**Board:** Seeed Studio Odyssey‑STM32MP157C
**Yocto:** scarthgap (5.0.x)
**ST BSP:** OpenSTLinux, kernel `linux-stm32mp` 6.6.129 (`-stm32mp-r3.1`),
`optee-os-stm32mp` 4.0.0, TF‑A + U‑Boot from the ST BSP (unpatched)
**Layer base commit:** `ca506e6` ("wip", 2026‑09‑05) — the pre‑existing
mickledore‑era layer.

---

## 0. TL;DR — what this layer does

1. **Boots the OpenSTLinux secure flow** (BootROM → TF‑A BL2 → OP‑TEE BL32 →
   U‑Boot → Linux, SCMI clocks/resets owned by OP‑TEE) on the Odyssey, which the
   upstream `stm32mp157c-odyssey.dts` does not do.
2. **Adds an OP‑TEE board device tree** for the Odyssey (none exists upstream),
   with the STPMIC1 on **I2C2** (where the Odyssey wires it) instead of I2C4.
3. **Drops** all the mickledore‑era 6.1 kernel / TF‑A / U‑Boot patches that no
   longer apply and are not needed on 6.6.

Everything is contained in `layers/meta-st-odyssey/` plus a handful of
`local.conf` settings (section 7). No files under `layers/openembedded-core/`
or `layers/meta-st/` were modified.

---

## 1. Change summary table

| # | Path (relative to `layers/meta-st-odyssey/`) | Action | Purpose |
|---|---|---|---|
| 1 | `recipes-security/optee/optee-os-stm32mp_%.bbappend` | **modified** | point at the new consolidated OP‑TEE patch; `CFG_WITH_NSEC_I2CS=y` |
| 2 | `recipes-security/optee/optee-os-stm32mp/0001-stm32mp157c-odyssey-optee-dt.patch` | **new** | OP‑TEE Odyssey board DT + non‑secure I2C2 kernel clock + `conf.mk` flavour |
| 3 | `recipes-security/optee/optee-os-stm32mp/0001-Add-stm32mp157c-odyssey-device-tree-based-on-dk2.patch` | **deleted** | superseded by #2 |
| 4 | `recipes-security/optee/optee-os-stm32mp/0002-stm32mp157c-odyssey-pmic-on-i2c2.patch` | **deleted** | superseded by #2 (mickledore‑era, `&hash1` / RNG1 assumptions broke 4.0.0) |
| 5 | `recipes-security/optee/optee-os-stm32mp/0003-fix-change-VCO-from-594MHz-to-750MHz-for-eth-phy.patch` | **deleted** | mickledore‑era OP‑TEE‑side half of the eth‑PHY VCO fix — superseded, see §4 |
| 6 | `recipes-kernel/linux/linux-stm32mp_%.bbappend` | **modified** | new SRC_URI (SCMI patch only) |
| 7 | `recipes-kernel/linux/linux-stm32mp/6.6/6.6.129/0001-ARM-dts-stm32-add-SCMI-variant-for-stm32mp157c-odysse.patch` | **new** | kernel SCMI clock/reset overlay for the OP‑TEE flow |
| 7a | `recipes-kernel/linux/linux-stm32mp/6.6/6.6.129/0002-…-mac-level-phy-reset-delay.patch` | **new** | eth‑PHY reset fix, see §3.3 |
| 7b | `recipes-kernel/linux/linux-stm32mp/6.6/6.6.129/0003-…-drop-broken-eth-assigned.patch` | **new** | drop broken `assigned-clocks`, see §3.3 |
| 8 | `recipes-kernel/linux/linux-stm32mp/6.1/6.1.82/000{1,2,3}-*.patch` | **deleted** | mickledore 6.1 patches (bootup fix, eth VCO, USB‑host) — do not apply to 6.6 |
| 9 | `recipes-bsp/trusted-firmware-a/tf-a-stm32mp_%.bbappend` | **new** (re‑added) | eth‑PHY PLL4 VCO fix, see §4 — the i2c2 patch from the old bbappend is still not needed, board DT is upstream |
| 9a | `recipes-bsp/trusted-firmware-a/tf-a-stm32mp/0001-fix-raise-PLL4-VCO-to-750MHz-for-eth-phy.patch` | **new** | ports the mickledore‑era fix onto ST's current upstream `stm32mp157c-odyssey-som.dtsi` |
| 10 | `recipes-bsp/u-boot/u-boot-stm32mp_%.bbappend` | **new** (re‑added) | OP‑TEE TEE‑client node, see §4.3 |
| 10a | `recipes-bsp/u-boot/u-boot-stm32mp/0001-…-add-optee-tee-client-node.patch` | **new** | lets U‑Boot's BSEC driver reach PTA_BSEC (MAC address, board ID OTP reads) once OP‑TEE owns BSEC exclusively |
| 10b | `recipes-bsp/u-boot/u-boot-stm32mp/0002-…-fix-phy-addr-add-reset.patch` | **new** | fix PHY MDIO address + add `st,eth-clk-sel`/`phy-reset-gpios`, see §4.4 |
| 10c | `recipes-bsp/u-boot/u-boot-stm32mp/0003-net-dwc_eth_qos-stm32-active-phy-reset-gpio.patch` | **new** | generic driver change: optional active PHY reset, see §4.4 |
| 10d | `recipes-bsp/u-boot/u-boot-stm32mp/0004-configs-stm32mp15-enable-Micrel-KSZ9031-PHY-driver.patch` | **new** | enable `CONFIG_PHY_MICREL_KSZ90X1`, see §4.4 |
| 11 | `recipes-example/example/example_0.1.bb` | **deleted** | layer skeleton sample, unused |
| 12 | `recipes-st/images/st-image-weston.bbappend` | **new** | sdcard flashlayout shrink |
| 13 | `docs/scarthgap-port.md` | **new** | this document |

---

## 2. OP‑TEE — Odyssey board device tree

### 2.1 `optee-os-stm32mp_%.bbappend`

```
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI += " file://0001-stm32mp157c-odyssey-optee-dt.patch"
EXTRA_OEMAKE:append = " CFG_WITH_NSEC_I2CS=y"
```

`CFG_WITH_NSEC_I2CS=y` is required because OP‑TEE's `clk-stm32mp15` only
registers non‑secure I²C kernel clocks under that switch, and the Odyssey PMIC
sits on the non‑secure I2C2 bus (see 2.3).

### 2.2 Patch `0001-stm32mp157c-odyssey-optee-dt.patch` — files touched

| File | Hunk(s) | What |
|---|---|---|
| `core/arch/arm/dts/stm32mp157c-odyssey.dts` | new file, 294 lines | the board DT (below) |
| `core/drivers/clk/clk-stm32mp15.c` | 4 hunks | register the **I2C2** non‑secure kernel clock (`_I2C12_SEL`) |
| `core/include/drivers/stm32mp1_rcc.h` | 1 hunk | `RCC_MP_APB1ENSETR_I2C2EN_POS = 22` + `BIT()` macro |
| `core/arch/arm/plat-stm32mp1/conf.mk` | 1 hunk | register `157C_ODYSSEY` flavour, add it to `flavorlist-cryp-512M` |

OP‑TEE 4.0.0‑stm32mp builds one binary per board via
`oe_runmake CFG_EMBED_DTB_SOURCE_FILE=<board>.dts` and validates the flavour
against `conf.mk`. Without the `conf.mk` hunk the build fails with
`check_build_variables: Wrong CFG_DRAM_SIZE 1024MBytes` (the Odyssey has 512 MB
DDR → it belongs in `flavorlist-cryp-512M`).

### 2.3 The OP‑TEE board DT (`stm32mp157c-odyssey.dts`)

Derived from ST's `stm32mp157c-dk2.dts` (same SoM family), i.e. it
`#include`s:

```
stm32mp157.dtsi, stm32mp15xc.dtsi, stm32mp15-pinctrl.dtsi,
stm32mp15xxac-pinctrl.dtsi, stm32mp15xx-dkx.dtsi
```

Deltas from the DK2:

- `model = "Seeed Studio Odyssey-STM32MP157C Board";`
  `compatible = "seeed,stm32mp157c-odyssey", "st,stm32mp157";`
- `aliases { serial0 = &uart4; }` + `chosen { stdout-path = "serial0:115200n8"; }`
  (Odyssey debug UART is UART4, not the DK2's USART3).
- **PMIC relocation:** `/delete-node/ &pmic;` (removes it from I2C4), then
  `&i2c4 { status = "disabled"; };` and a full re‑declaration of the STPMIC1
  under `&i2c2`:
  ```
  &i2c2 {
      compatible = "st,stm32mp15-i2c-non-secure";
      pinctrl-0 = <&i2c2_pins_a>;      /* PH4/PH5 AF4 */
      pinctrl-1 = <&i2c2_sleep_pins_a>;
      status = "okay";
      pmic: stpmic@33 { … full dkx regulator block … };
  };
  ```
  (regulators: `vddcore, vdd_ddr, vdd, v3v3, v1v8_audio, v3v3_hdmi, vtt_ddr,
  vdd_usb, vdda, v1v2_hdmi, vref_ddr, bst_out, vbus_otg, vbus_sw`).
- `&etzpc` firewall matrix: add
  `DECPROT(STM32MP1_ETZPC_I2C2_ID, DECPROT_NS_RW, DECPROT_UNLOCK)` so OP‑TEE can
  hand I2C2 to the non‑secure world; `HASH1` left `NS_RW`, `RNG1` `S_RW`.
- **LTDC / DSI / DSI panel disabled** (`&ltdc`, `&dsi`, `&dsi`'s `panel@0`
  `otm8009a` all end up inert). The Odyssey's on‑board DSI FPC is not usable with
  the panels in the field. This means **no `/dev/dri` node and no GPU (Vivante)
  acceleration** on this board — by design.
- MCU‑SRAM isolation nodes (`SRAM1/2/3`, `RETRAM` with
  `DECPROT_MCU_ISOLATION`) are inherited from `dkx.dtsi` — the Cortex‑M4 memory
  carve‑out is already firewall‑ready for a future remoteproc bring‑up.

### 2.4 Why the mickledore patches were dropped

- `0001-Add-…-based-on-dk2.patch` also enabled `&ltdc`/`&dsi`/`otm8009a` →
  OP‑TEE `LTDC` panic `0xffff0006` at boot.
- `0002-…-pmic-on-i2c2.patch` carried mickledore assumptions (`&hash1`
  enabled, `RNG1` `NS_RW`, secure‑status props) → HASH1 panic `0xffff0001` on
  4.0.0.
- `stm32mp1_pwr.c` in 4.0.0 hard‑requires `vdd-supply`, so the PMIC **cannot**
  simply be dropped from OP‑TEE — it has to be kept and reachable, hence the
  I2C2 non‑secure clock work in `clk-stm32mp15.c`.

---

## 3. Kernel — SCMI variant

### 3.1 `linux-stm32mp_%.bbappend`

```
SRC_URI += " \
    file://${LINUX_VERSION}/${LINUX_VERSION}${LINUX_SUBVERSION}/0001-ARM-dts-stm32-add-SCMI-variant-for-stm32mp157c-odysse.patch \
"
```

### 3.2 Patch `0001-…-add-SCMI-variant-…`

Mirrors ST's own `stm32mp157c-dk2-scmi.dtsi` pattern:

- **new file** `arch/arm/boot/dts/st/stm32mp157c-odyssey-scmi.dtsi` (134 lines):
  `#include "stm32mp15-scmi.dtsi"`, then reparent every clock/reset that OP‑TEE
  now owns to the SCMI providers — `&rcc` becomes
  `compatible = "st,stm32mp1-rcc-secure"`, HSE/HSI/CSI/LSE/LSI → `&scmi_clk`,
  GPIO banks A–Z → `CK_SCMI_GPIOx`, `CRYP1/HASH1/I2C4/I2C6/RNG1/RTC/USART1` →
  SCMI clk+reset, `&m4_rproc` resets → `RST_SCMI_MCU` / `RST_SCMI_MCU_HOLD_BOOT`
  (`/delete-property/ st,syscfg-holdboot`), `&mdma1` reset → `RST_SCMI_MDMA`,
  plus the `optee@de000000` reserved‑memory carve‑out.
- **1 line** added to `arch/arm/boot/dts/st/stm32mp157c-odyssey.dts`:
  `#include "stm32mp157c-odyssey-scmi.dtsi"`.

Without this the non‑secure kernel pokes RCC directly, races OP‑TEE, and hangs
at clock init on the `FlashLayout_*-odyssey-optee.tsv` images. The `.dtb`
filename is unchanged, so `STM32MP_DT_FILES_*` / flashlayout handling is
unaffected.

### 3.3 Patches `0002`/`0003` — Ethernet fix

- **0002** moves the KSZ9031RN's reset to the MAC level
  (`snps,reset-gpio`/`snps,reset-delays-us = <0 30000 50000>` on `&ethernet0`,
  `mdio` → `mdio0`) instead of mainline's default per‑PHY `reset-gpios`
  (300us deassert‑to‑scan — too short for this PHY's PLL to settle, so it
  never answers MDIO). Restores the mickledore‑era fix that was dropped
  without a stated reason during this port.
- **0003** drops the `assigned-clocks`/`assigned-clock-parents`/
  `assigned-clock-rates` on `&ethernet0` — `ETHCK_K` lost its own mux in the
  driver's 6.1‑stm32mp refactor (now a single hardcoded parent), so the
  reparent request is a no‑op `-EINVAL` every boot. Harmless but pointless;
  ST's own DK1/DK2/EV1 never had this construct.

---

## 4. TF‑A — Ethernet PLL4 fix

### 4.1 `tf-a-stm32mp_%.bbappend`

```
SRC_URI += " \
    file://0001-fix-raise-PLL4-VCO-to-750MHz-for-eth-phy.patch \
"
```

### 4.2 Why this is needed

ST's own TF‑A fork already carries this board's DT
(`fdts/stm32mp157c-odyssey.dts` + `-som.dtsi` + `-fw-config.dts`) upstream —
no board‑bring‑up patch is needed to boot. But `-som.dtsi` selects PLL4_P as
the Ethernet clock parent (`CLK_ETH_PLL4P` in `st,pkcs`) while leaving PLL4 at
its generic default: VCO 594 MHz → P = 99 MHz. The onboard KSZ9031RN needs an
exact 125 MHz RGMII reference clock, and the kernel's own (also upstream,
unpatched) `ethernet0` node already requests
`assigned-clock-rates = <125000000>` on `PLL4_P` — a request 99 MHz can never
satisfy, so the PHY link never comes up.

TF‑A's BL2 stage is what actually programs PLL4 at cold boot. The fix is a
one‑line divider change in `-som.dtsi`: VCO 594→750 MHz
(`divmn = <3 98>` → `<3 124>`), giving P = 125 MHz
(`st,pll_div_pqr = <5 7 7>` → `<5 11 11>`).

OP‑TEE's own board DT needs the *same* override even though it never
reprograms PLL4 itself: OP‑TEE validates SCMI clock requests against its own
DT‑described clock‑tree model, independent of what TF‑A actually wrote to
the real registers — without it, OP‑TEE still assumes the stock 594 MHz VCO
it inherited from `dkx.dtsi` and rejects the kernel's 125 MHz request as
unreachable. Same `pll4_vco_594Mhz`/`pll4_cfg1` override, appended to
`optee-os-stm32mp`'s `0001-stm32mp157c-odyssey-optee-dt.patch` (§2).

This is the same fix the mickledore‑era layer carried
(`0002-fix-change-VCO-from-594MHz-to-750MHz-for-eth-phy.patch` against TF‑A,
U‑Boot, kernel 6.1 *and* OP‑TEE) — dropped during the scarthgap port under
the wrong assumption that TF‑A didn't need it. The kernel half of the old fix
(`assigned-clock-rates` on `&ethernet0`) turned out to be unnecessary and was
actively broken on 6.6 — see §3.3. U‑Boot doesn't touch RCC at all in this
OP‑TEE‑secure boot flow, so no VCO patch is needed there.

Confirmed on hardware via `clk_summary`: `pll4`/`pll4_p`/`ethck_k`/`ethrx`
all read back at 750/125/125/125 MHz.

### 4.3 U‑Boot — OP‑TEE TEE‑client node

U‑Boot's own BSEC (OTP — MAC address, board ID) access goes through
`stm32mp_bsec`, which needs a TEE client session to OP‑TEE's `PTA_BSEC` once
OP‑TEE owns BSEC exclusively. Without it: `stm32_smc: Failed to exec
svc=82001003 op=1 in secure mode (err = -1)`, `Error: ethernet@5800a000
address not set.`. ST's own DK1/DK2/EV1 get this via their `-scmi.dtsi`
overlays; this board never had one. Adds just the
`firmware { optee { compatible = "linaro,optee-tz"; ... }; }` node to
U‑Boot's `stm32mp157c-odyssey.dts` — not the separate SCMI‑over‑OP‑TEE
clock/reset transport those overlays also carry, since U‑Boot doesn't touch
any peripheral that reparents here.

An earlier attempt also patched U‑Boot's own PLL4 devicetree config,
assuming U‑Boot's `clk-stm32mp1.c` reprograms PLL4 on every boot. Wrong: that
code is `#if defined(CONFIG_SPL_BUILD)`, and this board's boot flow has no
U‑Boot SPL stage at all (TF‑A replaces it) — dead weight, removed.

### 4.4 U‑Boot — Ethernet (patches 0002–0004)

U‑Boot's own board DTS is a separate, older community port from the
kernel's — it had its own bugs independent of everything else in this
layer:

- **Wrong PHY MDIO address** (`ethernet-phy@0`, `reg = <0>`) — the
  KSZ9031RN is actually at address 7. Fixed in 0002.
- **Missing `st,eth-clk-sel`** — without it, `board_interface_eth_init()`
  (`board/st/stm32mp1/stm32mp1.c`) never sets SYSCFG PMCSETR's
  `eth1_clk_sel` bit, so the SoC's 125MHz `PLL4_P`‑derived clock (correct —
  confirmed via `clk dump`) never actually reaches the PHY. Result: the MAC's
  own DMA soft‑reset never completes (`EQOS_DMA_MODE_SWR stuck`, confirmed
  permanently stuck at the register level via `md.l 0x5800b000 1`, unaffected
  by any amount of extra delay — this is documented DWC_EQOS behavior, the
  reset needs a live PHY‑side clock). This was the actual root cause, not PHY
  reset timing. Fixed in 0002.
- **No PHY reset GPIO** — the STM32 variant of `drivers/net/dwc_eth_qos.c`
  never drove a reset line at all (`eqos_start_resets = eqos_null_ops`),
  unlike e.g. the Tegra186 variant. Not what was blocking `DMA_MODE_SWR`, but
  still needed for MDIO to work afterward. 0003 adds an optional
  `phy-reset-gpios` path (a real assert/deassert sequence), no‑op for every
  board that doesn't set the property.
- **Generic PHY driver instead of the KSZ9031‑aware one** —
  `CONFIG_PHY_MICREL_KSZ90X1` wasn't set in `stm32mp15_defconfig`, so the
  PHY bound to U‑Boot's generic driver (confirmed via `dm tree`:
  `eth_phy_generic_drv`), which skips whatever vendor‑specific setup this
  PHY needs before autonegotiation completes. Fixed in 0004.

Confirmed on hardware: `mdio list` shows `Micrel ksz9031`, `mii info` shows
`1000baseT, FDX`, and `ping` from U‑Boot to the host succeeds.

---

## 5. Image — `st-image-weston.bbappend`

**sdcard flashlayout shrink.** Stock sdcard layout reserves a 4 GiB rootfs
slot → the raw `.img` is ~4.9 GiB while the rootfs uses ~530 MiB. This trims
the rootfs partition so `userfs` slides up and the raw image is ~1.9 GiB.
`FLASHLAYOUT_PARTITION_SIZE:sdcard:rootfs` can only be overridden from an
**anonymous python function** — `flashlayout-stm32mp.bbclass` `require`s
`st-machine-flashlayout-stm32mp.inc` at parse time and
`bb.data.expandKeys()` renames/re‑clobbers the key *after* any plain /
`:append` / `:forcevariable` assignment:
```python
python () {
    d.setVar('FLASHLAYOUT_PARTITION_SIZE:sdcard:rootfs', '1835008')
}
```
Paired with `STM32MP_ROOTFS_SIZE` / `STM32MP_USERFS_SIZE` in `local.conf`
(§7) — those must be global because `sdcard-raw-tools.bb` also reads them.

---

## 6. Not done / postponed

- **Cortex‑M4 remoteproc.** DT infrastructure (`m4_rproc`, `ipcc`,
  `reserved-memory`, MCU‑SRAM isolation) is all present but `status =
  "disabled"`; kernel config already has `STM32_RPROC` / `STM32_IPCC` /
  `RPMSG_*`. Not enabled yet.

---

## 7. Build‑tree settings (NOT part of the layer)

The build uses ST's generic `MACHINE = "stm32mp1"` and selects the board via
`STM32MP_DT_FILES_*`, so there is no board machine/distro conf to carry these —
they must be appended to `build*/conf/local.conf`. The exact block is tracked in
the layer at **`conf/local.conf.append`**; copy it in, or add
`require .../layers/meta-st-odyssey/conf/local.conf.append` to `local.conf`.

```
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE     = "-j 8"

# sdcard image shrink (pairs with the bbappend anon-python override)
STM32MP_ROOTFS_SIZE = "1835008"
STM32MP_USERFS_SIZE = "65536"

# build only the Odyssey board DT (13 boards -> 1; ~3x faster OP-TEE/TF-A/U-Boot/kernel)
STM32MP_DT_FILES_SDCARD:forcevariable = "stm32mp157c-odyssey"
STM32MP_DT_FILES_EMMC:forcevariable   = ""
STM32MP_DT_FILES_NAND:forcevariable   = ""
STM32MP_DT_FILES_NOR_mb:forcevariable = ""

# U-Boot only derives ${fdtfile} for "st," compatibles; the Odyssey's is
# "seeed,stm32mp157c-odyssey" -> it looks for a non-existent dtb and Linux
# silently hangs on U-Boot's control FDT. Pin the DTB explicitly.
UBOOT_EXTLINUX_FDT = "/stm32mp157c-odyssey.dtb"
```

`UBOOT_EXTLINUX_FDT` is **functionally required** for the board to boot; the
rest are convenience/perf.

---

## 8. Boot status

```
BootROM → TF-A BL2 → OP-TEE 4.0.0 (BL32) → U-Boot → Linux 6.6.129 → systemd → login
```

Confirmed working from the kernel log:

- SCMI clocks/resets/regulators (OP-TEE)
- STPMIC1 on I2C2 — `stpmic1 1-0033: PMIC Chip Version: 0x21`
- SD‑card + eMMC
- Weston (software / pixman backend) → login
- Ethernet — `end0` UP/RUNNING, DHCP lease, SSH reachable (fixes in §3.3/§4)

RNG1 stays `DECPROT_S_RW` (secure) — OP‑TEE's own DT enables it as OP‑TEE's
hardware TRNG (stock `stm32mp15xx-dkx.dtsi`, same on every ST reference
board), and its ETZPC bus‑probe panics if it isn't secure. The Linux‑side
`rng@54003000 not allowed on bus (-13)` warning is expected: no `/dev/hwrng`
on this board, by design.

---

## 9. How to build

```sh
# host too new for scarthgap's own tools -> buildtools-extended wrapper
./bb.sh st-image-weston

# sdcard raw (buildtools env needed for sgdisk/mkfs.vfat/mcopy):
cd .../deploy/images/stm32mp1
source .../buildtools/environment-setup-x86_64-pokysdk-linux
env SDCARD_SIZE=4096 ./scripts/create_sdcard_from_flashlayout.sh --compress \
    flashlayout_st-image-weston/optee/FlashLayout_sdcard_stm32mp157c-odyssey-optee.tsv

# flash:
sudo dd if=FlashLayout_sdcard_stm32mp157c-odyssey-optee.raw of=/dev/mmcblk0 \
    bs=8M conv=fsync status=progress
```
