# --- Shrink the sdcard flashlayout so the raw image fits a small (<=3.5 GB) card ---
# Stock sdcard layout reserves a 4 GiB rootfs slot, so userfs starts at ~4.09 GiB and
# the raw .img is ~4.9 GiB even though the rootfs only uses ~530 MiB. Trimming the
# rootfs slot -> userfs slides up, raw image ~1.9 GiB, still >1 GiB free on-target.
#
# STM32MP_ROOTFS_SIZE / STM32MP_USERFS_SIZE are set in conf/local.conf.append (plain
# vars with weak ?= defaults, and sdcard-raw-tools.bb reads STM32MP_ROOTFS_SIZE too, so
# they must be global). FLASHLAYOUT_PARTITION_SIZE:sdcard:rootfs cannot be set the normal
# way: flashlayout-stm32mp.bbclass require's st-machine-flashlayout-stm32mp.inc during
# recipe parse, and bb.data.expandKeys() renames its ...:${STM32MP_ROOTFS_LABEL} key to
# ...:rootfs *after* any assignment here (plain, :append, or :forcevariable), clobbering
# it back to 4194304. An anonymous python function runs after expandKeys, so it wins.
python () {
    d.setVar('FLASHLAYOUT_PARTITION_SIZE:sdcard:rootfs', '1835008')
}
