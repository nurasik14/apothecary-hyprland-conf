# Steps that need sudo (user runs these)

```
sudo dnf install -y kvantum papirus-icon-theme google-noto-serif-cjk-fonts
```

## SDDM login theme (hyprland-engineer)

Preview first (no sudo):
`scripts/install-sddm.sh prepare light && sddm-greeter-qt6 --test-mode --theme ~/Projects/apothecary-hyprland/sddm/apothecary`

```
sudo ~/Projects/apothecary-hyprland/scripts/install-sddm.sh light     # or: dark
```

Copies the theme (fonts + Maomao backgrounds baked in) to `/usr/share/sddm/themes/apothecary`, backs up
`/etc/sddm.conf` to `/etc/sddm.conf.pre-apothecary` and sets `[Theme] Current=apothecary`.
Revert: `sudo ~/Projects/apothecary-hyprland/scripts/install-sddm.sh revert` (the silent theme comes back).

## Screen brightness (Acer Nitro AN515-58, hybrid Intel + NVIDIA)

`/sys/class/backlight/` is empty, so brightness keys, `brightnessctl` and the Apothecary OSD have nothing to
drive. Cause: the kernel parameter `acpi_backlight=vendor` makes i915 skip `intel_backlight`
("Skipping intel_backlight registration" in `journalctl -k`), and the vendor driver (`nvidia_wmi_ec_backlight`)
only registers in dGPU-only MUX mode — in hybrid mode the panel (eDP-1) hangs off the Intel iGPU.

```
sudo -S -p '' grubby --update-kernel=ALL --remove-args="acpi_backlight=vendor"
# reboot, then check:  ls /sys/class/backlight   ->  intel_backlight
```
If you ever switch the MUX to discrete-only in the BIOS and brightness stops again, add
`acpi_backlight=nvidia_wmi_ec` instead:  `sudo grubby --update-kernel=ALL --args="acpi_backlight=nvidia_wmi_ec"`.
Undo: `sudo grubby --update-kernel=ALL --args="acpi_backlight=vendor"`.
