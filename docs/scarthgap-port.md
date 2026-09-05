# meta-st-odyssey — scarthgap / OpenSTLinux port: full change report

**Board:** Seeed Studio Odyssey‑STM32MP157C
**Yocto:** scarthgap (5.0.x)
**ST BSP:** OpenSTLinux, kernel `linux-stm32mp` 6.6.129 (`-stm32mp-r3.1`),
`optee-os-stm32mp` 4.0.0, TF‑A + U‑Boot from the ST BSP (unpatched)
**Layer base commit:** `ca506e6` ("wip", 2026‑09‑05) — the pre‑existing
mickledore‑era layer.

This document lists **every change** made on top of that base commit, where it
lives, and why. It is meant to be the basis of an upstream contribution back to
Seeed.

---

## 0. TL;DR — what the port does

1. **Boots the OpenSTLinux secure flow** (BootROM → TF‑A BL2 → OP‑TEE BL32 →
   U‑Boot → Linux, SCMI clocks/resets owned by OP‑TEE) on the Odyssey, which the
   upstream `stm32mp157c-odyssey.dts` does not do.
2. **Adds an OP‑TEE board device tree** for the Odyssey (none exists upstream),
   with the STPMIC1 on **I2C2** (where the Odyssey wires it) instead of I2C4.
3. **Adds a Waveshare 3.5" ILI9486 SPI panel + XPT2046 touch** on the 40‑pin
   header (kernel `fbtft`).
4. **Adds an LVGL "car‑dashboard" kiosk** app and a minimal image that boots
   straight to it (no Weston).
5. **Drops** all the mickledore‑era 6.1 kernel / TF‑A / U‑Boot patches that no
   longer apply and are not needed on 6.6.

Everything is contained in `layers/meta-st-odyssey/` plus a handful of
`local.conf` settings (section 8). No files under `layers/openembedded-core/`
or `layers/meta-st/` were modified.

---

## 1. Change summary table

| # | Path (relative to `layers/meta-st-odyssey/`) | Action | Purpose |
|---|---|---|---|
| 1 | `recipes-security/optee/optee-os-stm32mp_%.bbappend` | **modified** | point at the new consolidated OP‑TEE patch; `CFG_WITH_NSEC_I2CS=y` |
| 2 | `recipes-security/optee/optee-os-stm32mp/0001-stm32mp157c-odyssey-optee-dt.patch` | **new** | OP‑TEE Odyssey board DT + non‑secure I2C2 kernel clock + `conf.mk` flavour |
| 3 | `recipes-security/optee/optee-os-stm32mp/0001-Add-stm32mp157c-odyssey-device-tree-based-on-dk2.patch` | **deleted** | superseded by #2 |
| 4 | `recipes-security/optee/optee-os-stm32mp/0002-stm32mp157c-odyssey-pmic-on-i2c2.patch` | **deleted** | superseded by #2 (mickledore‑era, `&hash1` / RNG1 assumptions broke 4.0.0) |
| 5 | `recipes-security/optee/optee-os-stm32mp/0003-fix-change-VCO-from-594MHz-to-750MHz-for-eth-phy.patch` | **deleted** | Ethernet PLL4 rework — postponed, see §7 |
| 6 | `recipes-kernel/linux/linux-stm32mp_%.bbappend` | **modified** | new SRC_URI (SCMI + display patches + config fragment) |
| 7 | `recipes-kernel/linux/linux-stm32mp/6.6/6.6.129/0001-ARM-dts-stm32-add-SCMI-variant-for-stm32mp157c-odysse.patch` | **new** | kernel SCMI clock/reset overlay for the OP‑TEE flow |
| 8 | `recipes-kernel/linux/linux-stm32mp/6.6/6.6.129/0002-ARM-dts-stm32mp157c-odyssey-add-SPI5-ILI9486-display.patch` | **new** | SPI5 ILI9486 panel + ADS7846 touch on the 40‑pin header |
| 9 | `recipes-kernel/linux/linux-stm32mp/odyssey/fragment-90-spi-tft-display.config` | **new** | kernel config: re‑enable staging/fbtft/fbcon, `ads7846`, `SPI_STM32=y` |
| 10 | `recipes-kernel/linux/linux-stm32mp/6.1/6.1.82/000{1,2,3}-*.patch` | **deleted** | mickledore 6.1 patches (bootup fix, eth VCO, USB‑host) — do not apply to 6.6 |
| 11 | `recipes-bsp/trusted-firmware-a/…` (bbappend + 2 patches) | **deleted** | TF‑A i2c2 + eth‑VCO patches — not needed; ST BSP TF‑A used as‑is |
| 12 | `recipes-bsp/u-boot/…` (bbappend + 2 patches) | **deleted** | U‑Boot board + eth‑VCO patches — board already in ST BSP U‑Boot; DT pinned via `local.conf` |
| 13 | `recipes-example/example/example_0.1.bb` | **deleted** | layer skeleton sample, unused |
| 14 | `recipes-st/images/st-image-weston.bbappend` | **new** | bring‑up tools + sdcard flashlayout shrink |
| 15 | `recipes-st/images/odyssey-dashboard.bb` | **new** | minimal LVGL kiosk image (no Weston) |
| 16 | `recipes-hmi/car-dashboard/car-dashboard_1.0.bb` + `files/` | **new** | LVGL speedometer scaffold app (fbdev + evdev) |
| 17 | `docs/spi-display.md`, `docs/scarthgap-port.md` | **new** | documentation |

Base‑commit reference: `git -C layers/meta-st-odyssey diff ca506e6` reproduces
items 1–16.

---

## 2. OP‑TEE — Odyssey board device tree  (items 1–2)

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
  the panels in the field; the display path is the SPI ILI9486 (§4). This also
  means **no `/dev/dri` node and no GPU (Vivante) acceleration** on this board —
  by design.
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

## 3. Kernel — SCMI variant  (items 6–7)

### 3.1 `linux-stm32mp_%.bbappend` (new SRC_URI)

```
SRC_URI += " \
    file://${LINUX_VERSION}/${LINUX_VERSION}${LINUX_SUBVERSION}/0001-ARM-dts-stm32-add-SCMI-variant-for-stm32mp157c-odysse.patch \
    file://${LINUX_VERSION}/${LINUX_VERSION}${LINUX_SUBVERSION}/0002-ARM-dts-stm32mp157c-odyssey-add-SPI5-ILI9486-display.patch \
    file://odyssey/fragment-90-spi-tft-display.config;subdir=fragments \
"
KERNEL_CONFIG_FRAGMENTS:append = " ${WORKDIR}/fragments/odyssey/fragment-90-spi-tft-display.config"
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

---

## 4. Kernel — SPI ILI9486 display + touch  (items 8–9)

### 4.1 Patch `0002-…-add-SPI5-ILI9486-display.patch`

Appends ~87 lines to `arch/arm/boot/dts/st/stm32mp157c-odyssey.dts`:

- a board pinmux group `spi5_odyssey_pins_a` — SCK **PH6**, MOSI **PF9**, MISO
  **PH7** (the header SPI5 pins differ from the stock `spi5_pins_a` PF7/PF8
  group) + a `spi5_odyssey_sleep_pins_a` analog group.
- `&spi5`: `cs-gpios = <&gpiof 6 …>, <&gpiof 3 …>` (LCD CS = PF6, touch CS =
  PF3, both GPIO chip‑selects), `status = "okay"`.
  - `display@0` — `compatible = "ilitek,ili9486"`, `spi-max-frequency =
    <32000000>`, `buswidth 8`, `regwidth 16`, `rotate 90`, `fps 30`,
    `dc-gpios = <&gpioe 7 …>` (PE7), `reset-gpios = <&gpioe 8 …>` (PE8), and the
    Waveshare 3.5"(C) `init` sequence.
  - `touchscreen@1` — `compatible = "ti,ads7846"`, `spi-max-frequency
    <2000000>`, IRQ on `&gpiod 4` (PD4, falling edge), `pendown-gpio`,
    `ti,swap-xy`, `wakeup-source`.

Header pin map is in [`spi-display.md`](spi-display.md).

### 4.2 Config fragment `fragment-90-spi-tft-display.config`

The ST `stm32mp` "cleanup" fragment disables `CONFIG_STAGING` and
`CONFIG_FRAMEBUFFER_CONSOLE`; this fragment re‑enables what `fbtft` needs:

```
CONFIG_STAGING=y
CONFIG_FB_TFT=m
CONFIG_FB_TFT_ILI9486=m
CONFIG_TOUCHSCREEN_ADS7846=m
CONFIG_SPI_STM32=y          # base config has it =m; needed early
CONFIG_SPI_SPIDEV=y
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y
```

Modules autoload from the DT compatibles. Because LTDC/DSI are disabled (§2.3),
the ILI9486 panel is the **only** framebuffer and comes up as **`/dev/fb0`**
(480×320, RGB565). Touch is an `/dev/input/eventN` (`ADS7846 Touchscreen`).

---

## 5. Images  (items 14–15)

### 5.1 `recipes-st/images/st-image-weston.bbappend`

- `IMAGE_INSTALL:append = " fbset evtest libgpiod-tools fbgrab"` — bring‑up tools.
- **sdcard flashlayout shrink.** Stock sdcard layout reserves a 4 GiB rootfs
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
  (§8) — those must be global because `sdcard-raw-tools.bb` also reads them.

### 5.2 `recipes-st/images/odyssey-dashboard.bb` (new image)

```
require recipes-st/images/st-image-core.bb
IMAGE_INSTALL:append = " car-dashboard kernel-modules libgpiod-tools evtest fbset fbgrab"
IMAGE_FEATURES:remove = "package-management"
SYSTEMD_DEFAULT_TARGET = "multi-user.target"
python () { d.setVar('FLASHLAYOUT_PARTITION_SIZE:sdcard:rootfs', '1835008') }
```

Same firmware stack as `st-image-weston` (TF‑A + OP‑TEE + U‑Boot), ~234 MB
rootfs, **no Weston / no display‑manager** — boots straight to the LVGL app on
`/dev/fb0`. Built and verified on hardware.

---

## 6. `car-dashboard` LVGL app  (item 16)

`recipes-hmi/car-dashboard/`:

| File | Role |
|---|---|
| `car-dashboard_1.0.bb` | recipe: vendors LVGL (git, `SRCREV e1c0b21b…` = meta‑oe 9.1.0 pin) into `${S}/lvgl`, cmake‑builds `main.c` + `add_subdirectory(lvgl)`; generates `lv_conf.h` from `lvgl/lv_conf_template.h` at `do_configure` (sed: `LV_COLOR_DEPTH 16`, `LV_USE_LINUX_FBDEV/EVDEV 1`, dark theme, Montserrat 20/28/40); installs a systemd unit. `RDEPENDS` on the `fb_ili9486`/`fbtft`/`ads7846` kernel modules. |
| `files/main.c` | LVGL v9 scaffold: `lv_linux_fbdev_create()` → `/dev/fb0` (or `$LV_VIDEO_CARD`), `lv_evdev_create()` → autodetected ABS touch node (or `$LV_TOUCH_DEV`), a dark `lv_arc` speedometer + animated needle + a live touch read‑out. Replace `build_dashboard()` with the real UI. |
| `files/CMakeLists.txt` | cmake ≥3.12.4, `LV_CONF_INCLUDE_SIMPLE`, links `lvgl m pthread`. |
| `files/car-dashboard.service` | `Type=simple`, `Restart=always`, `WantedBy=multi-user.target`; `ExecStartPre` unbinds vtcon1 and lowers `printk` so the kernel console doesn't scribble on the panel. |
| `files/lv_conf_overlay.h` | documentation‑only — lists the `lv_conf.h` values the recipe sed's in. |

Rendering is 100 % CPU (LVGL software renderer) — the only option on this board
(fbdev panel, no DRM/GPU). SPI at 32 MHz gives ~30 fps full‑screen.

**Known open item:** LVGL v9's evdev driver passes raw ADS7846 coordinates with
no calibration, so touch presses currently don't map to screen space — needs
`lv_evdev_set_calibration()` in `main.c` with the panel's observed min/max.

---

## 7. Not done / postponed

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

## 8. Build‑tree settings (NOT part of the layer)

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

## 9. Boot status (verified on hardware)

```
BootROM → TF-A BL2 → OP-TEE 4.0.0 (BL32) → U-Boot → Linux 6.6.129 → systemd → login
```

Confirmed working from the kernel log:

- SCMI clocks/resets/regulators (OP-TEE)
- STPMIC1 on I2C2 — `stpmic1 1-0033: PMIC Chip Version: 0x21`
- SD‑card + eMMC
- ILI9486 panel on `/dev/fb0` (`fb_ili9486`, 480×320, 32 MHz)
- ADS7846 touch (`/dev/input/eventN`)
- Weston (software / pixman backend) → login, and the `odyssey-dashboard`
  kiosk image → LVGL speedometer

Not working: Ethernet (§7), touch coordinate mapping in the LVGL app (§6).

---

## 10. How to build

```sh
# host too new for scarthgap's own tools -> buildtools-extended wrapper
./bb.sh st-image-weston          # full Weston image
./bb.sh odyssey-dashboard        # minimal LVGL kiosk image

# sdcard raw (buildtools env needed for sgdisk/mkfs.vfat/mcopy):
cd .../deploy/images/stm32mp1
source .../buildtools/environment-setup-x86_64-pokysdk-linux
env SDCARD_SIZE=4096 ./scripts/create_sdcard_from_flashlayout.sh --compress \
    flashlayout_<image>/optee/FlashLayout_sdcard_stm32mp157c-odyssey-optee.tsv

# flash:
sudo dd if=FlashLayout_sdcard_stm32mp157c-odyssey-optee.raw of=/dev/mmcblk0 \
    bs=8M conv=fsync status=progress
```
