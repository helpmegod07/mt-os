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

