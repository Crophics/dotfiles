# Read by the sign-in screen (SDDM) before Hyprland starts.
# Keep Hyprland off the NVIDIA dGPU completely: it holding the NVIDIA card open froze the screen after suspend.
# Only apps started with `prime-run` use NVIDIA (~/.local/bin/prime-run undoes the EGL line for them).
export AQ_DRM_DEVICES=/dev/dri/igpu
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
