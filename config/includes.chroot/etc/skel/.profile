export PATH="/usr/local/bin:/usr/bin:/bin"

if [ "$(tty 2>/dev/null)" = "/dev/tty1" ]; then
  export XDG_SESSION_TYPE=wayland
  export WLR_RENDERER_ALLOW_SOFTWARE=1
  export WLR_NO_HARDWARE_CURSORS=1
  exec sway
fi
