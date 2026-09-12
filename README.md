# meta-st-odyssey

OpenSTLinux (scarthgap / Yocto 5.0) board support for the **Seeed Studio
Odyssey-STM32MP157C**. Boots any Odyssey board through the standard
OpenSTLinux secure flow - TF-A → OP-TEE → U-Boot → Linux, with SCMI
clocks/resets/regulators owned by OP-TEE.

This layer is deliberately minimal: OP-TEE board DT + the kernel SCMI
overlay + the local.conf settings the board needs.

Full technical write-up of everything this layer changes and why:
[`docs/scarthgap-port.md`](docs/scarthgap-port.md).

## 1. Clone

```bash
git clone https://gerrit.googlesource.com/git-repo
./git-repo/repo init -u <this-project's-oe-manifest-repo> -b scarthgap
./git-repo/repo sync
```

(Or manually place this layer at `layers/meta-st-odyssey` alongside the
usual `openembedded-core`, `meta-openembedded`, `meta-st` layers for a
scarthgap OpenSTLinux checkout.)

## 2. Set up the build environment

```bash
export READTIMEOUT=0
DISTRO=openstlinux-weston MACHINE=stm32mp1 source layers/meta-st/scripts/envsetup.sh --pkg-update --no-ui
```

If your host toolchain is newer than scarthgap expects (e.g. a very recent
distro), use the buildtools-extended wrapper instead of sourcing envsetup
directly - see `docs/scarthgap-port.md` for details.

## 3. Add the layer

```bash
bitbake-layers add-layer ../meta-st-odyssey
```

## 4. Required local.conf settings

The build uses ST's generic `MACHINE = "stm32mp1"` and selects the board via
`STM32MP_DT_FILES_*`, so there is no board machine/distro conf to carry the
Odyssey-specific settings - they go in `build*/conf/local.conf`. Copy the
tracked block in, or add:

```
require ${TOPDIR}/../layers/meta-st-odyssey/conf/local.conf.append
```

`UBOOT_EXTLINUX_FDT` in there is **boot-critical** (U-Boot only derives
`${fdtfile}` for `st,` compatibles; the Odyssey's is `seeed,...`) - without it
the board boots U-Boot but hangs silently going into Linux.

## 5. Build

```bash
bitbake st-image-weston
```

## 6. Make an sdcard image

```bash
cd tmp-glibc/deploy/images/stm32mp1
./scripts/create_sdcard_from_flashlayout.sh flashlayout_st-image-weston/optee/FlashLayout_sdcard_stm32mp157c-odyssey-optee.tsv
```

Flash the resulting `.raw` (or `.raw.xz` with `--compress`) with `dd`.

## What's in here

| Path | Purpose |
|---|---|
| `recipes-security/optee/` | OP-TEE Odyssey board DT (STPMIC1 on I2C2) + non-secure I2C2 kernel clock |
| `recipes-kernel/linux/` | Kernel SCMI clock/reset overlay for the OP-TEE boot flow |
| `conf/local.conf.append` | Required + optional `local.conf` settings, tracked in-repo |
| `docs/scarthgap-port.md` | Full change log: every patch, why, and what it touches |

See `docs/scarthgap-port.md` for the complete story, including what was
deliberately dropped from the older mickledore-era layer and why.
