#!/bin/bash
# Quick framebuffer health check before the display manager starts.

LOG_FILE="/var/log/lcd35-init.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

log() {
  echo "$(date -Iseconds) [preinit] $1" | tee -a "$LOG_FILE" > /dev/null
}

test_framebuffer() {
  if [ ! -e /dev/fb1 ]; then
    log "Framebuffer /dev/fb1 missing"
    return 1
  fi
  local pattern
  pattern=$(mktemp)
  printf '\x00\x00\xFF\xFF\x00\x00\xFF\xFF' > "$pattern"
  if dd if="$pattern" of=/dev/fb1 bs=8 count=1 conv=fsync status=none 2>/dev/null; then
    rm -f "$pattern"
    log "Framebuffer responded to write test"
    return 0
  fi
  rm -f "$pattern"
  log "Framebuffer write test failed"
  return 1
}

attempt_recover() {
  if command -v /usr/local/bin/LCD35-recover >/dev/null 2>&1; then
    /usr/local/bin/LCD35-recover >> "$LOG_FILE" 2>&1
  elif [ -x /usr/local/bin/lcd35-watchdog.sh ]; then
    /usr/local/bin/lcd35-watchdog.sh --recover-once >> "$LOG_FILE" 2>&1
  fi
}

for attempt in 1 2 3; do
  log "Preinit framebuffer check attempt ${attempt}"
  if test_framebuffer; then
    exit 0
  fi
  attempt_recover
  sleep 1
done

log "Display initialization failed before lightdm; please try a power cycle"
exit 1
