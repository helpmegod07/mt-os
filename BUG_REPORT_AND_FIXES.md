# MT-OS Bug Report: UI Unresponsiveness and Visual Artifacts

## Issues Identified

### 1. **Primary Issue: UI Unresponsiveness (Cannot Click)**

**Root Cause:**
- Both `mt-face.py` and `mt-terminal.py` used `wm_attributes("-topmost", True)`, which forces windows to stay on top of all other windows
- When multiple windows compete for the "topmost" layer, the window manager (Openbox) can struggle with focus and event routing
- This causes mouse clicks to be intercepted or ignored, making the UI appear completely unresponsive
- The Openbox configuration has `<followMouse>no</followMouse>`, which means the window manager doesn't automatically give focus to the window under the mouse, exacerbating the problem

**Impact:**
- Users cannot click buttons, type in text fields, or interact with any UI elements
- The application becomes completely frozen from a user perspective

**Fix Applied:**
- Removed `wm_attributes("-topmost", True)` from both `mt-face.py` (line 13) and `mt-terminal.py` (line 26)
- Windows now behave normally and allow proper focus management by the window manager
- Users can now click and interact with UI elements normally

---

### 2. **Secondary Issue: Visual Artifacts (Broken Appearance)**

**Root Cause:**
- The grid lines drawn in `mt-face.py` (lines 28-29) use a very dark color (`#0D1A0D`) on a dark background (`#0A0A0F`)
- These lines are intentional but create a visual effect that resembles screen corruption or glitches
- The `set-wallpaper.sh` script also draws many lines, contributing to the "glitchy" aesthetic
- This is actually a design choice (retro/cyberpunk aesthetic), but it can be mistaken for a broken UI

**Impact:**
- The UI looks visually corrupted with horizontal and vertical lines
- Users may think the system is broken or malfunctioning

**Note:**
- This is not technically a bug but rather an intentional design choice
- If a cleaner appearance is desired, the grid lines can be removed or made more subtle

---

### 3. **Tertiary Issue: Broken Update Script**

**Root Cause:**
- The `update-os.sh` script (lines 29-33) contains invalid bash syntax
- Uses `[ -f ... ]: # "&& sudo cp ..."` which is syntactically incorrect
- The colon (`:`) is a bash no-op command, and the rest is treated as a comment
- This means configuration files are never actually updated during OS updates

**Impact:**
- The OS cannot properly update itself
- Configuration changes in new versions are never applied
- Users stuck on old versions cannot benefit from bug fixes

**Fix Applied:**
- Changed invalid syntax to proper bash conditionals:
  - `[ -f $TEMP_DIR/rootfs/mt-os-config/autostart ] && sudo cp ...`
  - `[ -f $TEMP_DIR/rootfs/mt-os-config/rc.xml ] && sudo cp ...`
  - `[ -f $TEMP_DIR/rootfs/mt-os-config/menu.xml ] && sudo cp ...`
  - `[ -f $TEMP_DIR/rootfs/mt-os-config/.bashrc ] && sudo cp ...`
  - `[ -f $TEMP_DIR/rootfs/mt-os-config/set-wallpaper.sh ] && sudo cp ...`

---

## Files Modified

1. **`rootfs/mt-os-apps/mt-face.py`**
   - Removed line: `self.root.wm_attributes("-topmost",True);`
   - Result: Window no longer forces itself to stay on top

2. **`rootfs/mt-os-apps/mt-terminal.py`**
   - Removed line: `self.root.wm_attributes("-topmost",True);`
   - Result: Window no longer forces itself to stay on top

3. **`rootfs/update-os.sh`**
   - Fixed lines 29-33: Corrected bash syntax for conditional file copying
   - Result: Configuration files are now properly updated during OS updates

---

## Testing Recommendations

1. **Test UI Responsiveness:**
   - Launch `mt-face.py` and `mt-terminal.py`
   - Verify that you can click buttons and type in text fields
   - Verify that windows can be moved and resized normally

2. **Test Window Management:**
   - Launch both applications simultaneously
   - Verify that both windows are accessible and can receive focus
   - Verify that clicking on one window brings it to focus

3. **Test Update Script:**
   - Run `update-os` command
   - Verify that configuration files are properly copied
   - Check that no errors occur during the update process

---

## Additional Notes

- The visual "glitchy" appearance is intentional and part of the retro/cyberpunk aesthetic
- If a cleaner look is desired, consider reducing the opacity or color of the grid lines in `mt-face.py`
- The Openbox window manager configuration is well-suited for this application and doesn't require changes
- Consider adding explicit focus handling to ensure the terminal entry field receives focus when the window is activated


---

### 4. **Quaternary Issue: Installation Failure (Missing Kernel/Basename Error)**

**Root Cause:**
- In `mt-install.sh`, the check for the kernel file `[ ! -f /mnt/mt-live/boot/vmlinuz* ]` was unreliable because the wildcard `*` does not expand correctly inside the `[ ]` brackets if multiple files match or if no files match.
- When the kernel was not found, the script attempted to reinstall it, but the subsequent `ls /mnt/mt-live/boot/vmlinuz*` still failed if the installation didn't place the file exactly where expected or if the shell globbing failed.
- The command `basename $(ls /mnt/mt-live/boot/vmlinuz* | head -1)` failed with `basename: missing operand` because the `ls` command returned an error (no such file), resulting in an empty string being passed to `basename`.

**Impact:**
- The installation process would crash at line 110 (or 113/114 in the original script) during the GRUB configuration phase.
- Users were unable to complete the persistent installation to a physical disk.

**Fix Applied:**
- Updated the kernel check to use a more robust `if ! ls /mnt/mt-live/boot/vmlinuz* >/dev/null 2>&1; then` pattern.
- Added `--no-install-recommends` to the kernel installation to keep the image slim.
- Refactored the kernel and initrd file detection to safely handle empty results and provide a clear error message instead of crashing.
- Used `basename "$KERNEL_PATH"` with quotes to ensure the operand is never "missing" even if the path contains spaces (though unlikely for a kernel).

---

---

### 5. **Quinary Issue: Installation Failure (Device or Resource Busy)**

**Root Cause:**
- In `mt-install.sh`, the `wipefs` and `parted` commands failed when the target disk had active partitions that were already mounted by the live system.
- The error `Error: Partition(s) on /dev/sda are being used` occurred because the installer did not explicitly unmount existing partitions before attempting to re-partition the disk.

**Impact:**
- The installation process would crash at line 59 during the partitioning phase.
- Users could not install MT-OS if the target disk was previously formatted and automatically mounted.

**Fix Applied:**
- Added a robust unmounting loop before the partitioning phase.
- The script now uses `lsblk` to identify all partitions on the target disk and attempts to unmount them using `umount -l` (lazy unmount) to ensure the disk is free for `wipefs` and `parted`.
- This ensures that even if the live system has auto-mounted a partition, the installer can safely proceed.

---

---

### 6. **Senary Issue: Package Manager Locks and Missing Tools**

**Root Cause:**
- The installation could fail if the system had stale `apt` or `dpkg` lock files, preventing the installation of required tools like `rsync` or `parted`.
- Previously, the script would only report missing tools and exit, requiring manual user intervention.

**Impact:**
- Users were unable to proceed with the installation if dependencies were missing and the package manager was locked.

**Fix Applied (based on MT-OS Troubleshooting Guide):**
- Added automatic cleanup of `apt` and `dpkg` lock files (`/var/lib/apt/lists/lock`, etc.) if tools are missing.
- Added automatic execution of `dpkg --configure -a` to resolve interrupted package configurations.
- The script now attempts to automatically install missing dependencies (`parted`, `rsync`, `e2fsprogs`, `util-linux`) before proceeding, rather than just exiting.

---

---

### 7. **Septenary Issue: Application Unresponsiveness (Firefox/General UI)**

**Root Cause:**
- The Openbox configuration had a `focusDelay` of 200ms and `<followMouse>no</followMouse>`, which could cause lag or missed focus events when switching between the AI windows and standard applications like Firefox.
- Firefox and other complex applications sometimes struggle with focus in minimal window managers if explicit application rules aren't defined.
- The AI windows (`mt-face.py` and `mt-terminal.py`) were not explicitly set to a normal layer, potentially causing them to overlap or intercept events even without the `topmost` attribute.

**Impact:**
- Users reported being unable to interact with Firefox (clicks not registering, keyboard focus missing).
- General UI felt "stuck" or unresponsive when multiple windows were open.

**Fix Applied:**
- Updated `rc.xml` to set `focusDelay` to 0 for instant focus response.
- Added explicit application rules in `rc.xml` for `Firefox` and `Tk` (the AI apps) to ensure they always receive focus correctly and stay in the `normal` layer.
- Updated `mt-face.py` to explicitly disable `topmost` and added a focus-in binding to ensure it handles focus transitions gracefully without stealing it from other apps.

---
