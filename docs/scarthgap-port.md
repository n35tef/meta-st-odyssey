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
`local.conf` settings (section 6). No files under `layers/openembedded-core/`
or `layers/meta-st/` were modified.

---

## 1. Change summary table

| # | Path (relative to `layers/meta-st-odyssey/`) | Action | Purpose |
|---|---|---|---|
| 1 | `recipes-security/optee/optee-os-stm32mp_%.bbappend` | **modified** | point at the new consolidated OP‑TEE patch; `CFG_WITH_NSEC_I2CS=y` |
| 2 | `recipes-security/optee/optee-os-stm32mp/0001-stm32mp157c-odyssey-optee-dt.patch` | **new** | OP‑TEE Odyssey board DT + non‑secure I2C2 kernel clock + `conf.mk` flavour |
| 3 | `recipes-security/optee/optee-os-stm32mp/0001-Add-stm32mp157c-odyssey-device-tree-based-on-dk2.patch` | **deleted** | superseded by #2 |
| 4 | `recipes-security/optee/optee-os-stm32mp/0002-stm32mp157c-odyssey-pmic-on-i2c2.patch` | **deleted** | superseded by #2 (mickledore‑era, `&hash1` / RNG1 assumptions broke 4.0.0) |
| 5 | `recipes-security/optee/optee-os-stm32mp/0003-fix-change-VCO-from-594MHz-to-750MHz-for-eth-phy.patch` | **deleted** | Ethernet PLL4 rework — postponed, see §5 |
| 6 | `recipes-kernel/linux/linux-stm32mp_%.bbappend` | **modified** | new SRC_URI (SCMI patch only) |
| 7 | `recipes-kernel/linux/linux-stm32mp/6.6/6.6.129/0001-ARM-dts-stm32-add-SCMI-variant-for-stm32mp157c-odysse.patch` | **new** | kernel SCMI clock/reset overlay for the OP‑TEE flow |
| 8 | `recipes-kernel/linux/linux-stm32mp/6.1/6.1.82/000{1,2,3}-*.patch` | **deleted** | mickledore 6.1 patches (bootup fix, eth VCO, USB‑host) — do not apply to 6.6 |
| 9 | `recipes-bsp/trusted-firmware-a/…` (bbappend + 2 patches) | **deleted** | TF‑A i2c2 + eth‑VCO patches — not needed; ST BSP TF‑A used as‑is |
| 10 | `recipes-bsp/u-boot/…` (bbappend + 2 patches) | **deleted** | U‑Boot board + eth‑VCO patches — board already in ST BSP U‑Boot; DT pinned via `local.conf` |
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
  acceleration** on this board — by design. `meta-odyssey-demo`'s SPI panel is
  the display path.
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

`meta-odyssey-demo`'s kernel bbappend adds its own patches (SPI5 display DT,
ads7846 fixes) on top of this one — Yocto stacks every layer's
`linux-stm32mp_%.bbappend` for the same recipe, so both apply together
whenever that optional layer is present.

---

## 4. Image — `st-image-weston.bbappend`

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
(§6) — those must be global because `sdcard-raw-tools.bb` also reads them.

---

## 5. Not done / postponed

- **Ethernet.** The Odyssey PHY needs RGMII 125 MHz off PLL4‑P, but the OP‑TEE
  `&rcc` PLL4 VCO is 594 MHz (→ PLL4_P = 99 MHz) and the secure RCC refuses the
  kernel's reparent request (`-EINVAL`). Fix = port PLL4‑VCO‑750 (`divmn = <3
  124>`, `pqr = <5 11 11>`) into the OP‑TEE `&rcc` node. The mickledore
  `0003-fix-change-VCO-…` patches targeted TF‑A/U‑Boot/6.1 and don't apply.
  **Deleted, not yet re‑implemented.**
- **Cortex‑M4 remoteproc.** DT infrastructure (`m4_rproc`, `ipcc`,
  `reserved-memory`, MCU‑SRAM isolation) is all present but `status =
  "disabled"`; kernel config already has `STM32_RPROC` / `STM32_IPCC` /
  `RPMSG_*`. Not enabled yet.

---

## 6. Build‑tree settings (NOT part of the layer)

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

## 7. Boot status (verified on hardware)

```
BootROM → TF-A BL2 → OP-TEE 4.0.0 (BL32) → U-Boot → Linux 6.6.129 → systemd → login
```

Confirmed working from the kernel log:

- SCMI clocks/resets/regulators (OP-TEE)
- STPMIC1 on I2C2 — `stpmic1 1-0033: PMIC Chip Version: 0x21`
- SD‑card + eMMC
- Weston (software / pixman backend) → login

---

## 8. How to build

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
