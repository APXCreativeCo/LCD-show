#!/bin/bash
# Watchdog loop that checks LCD35 health and attempts recovery when unresponsive.

set -u
LOG_FILE="/var/log/lcd35-init.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
SLEEP_SECONDS=${LCD35_WATCHDOG_INTERVAL:-60}
MAX_RETRIES=${LCD35_WATCHDOG_MAX_FAILURES:-3}
FAILURES=0

timestamp() {
  date -Iseconds
}

log() {
  local message="$1"
  echo "$(timestamp) [watchdog] $message" | tee -a "$LOG_FILE" > /dev/null
}

framebuffer_healthy() {
  if [ ! -w /dev/fb1 ]; then
    log "Framebuffer missing or not writable"
    return 1
  fi

  if dd if=/dev/fb1 of=/dev/null bs=4 count=1 status=none 2>/dev/null; then
    return 0
  fi

  log "Framebuffer read failed"
  return 1
}

attempt_recovery() {
  local recover_bin="$(dirname "$0")/LCD35-recover"
  if [ ! -x "$recover_bin" ] && command -v LCD35-recover >/dev/null 2>&1; then
    recover_bin=$(command -v LCD35-recover)
  fi

  if [ -x "$recover_bin" ]; then
    log "Starting automatic recovery"
    "$recover_bin" 2>/dev/null || true
  else
    log "No recovery helper available; skipping automatic recovery"
  fi
}

main_loop() {
  log "Watchdog loop started with interval ${SLEEP_SECONDS}s"
  while true; do
    if framebuffer_healthy; then
      FAILURES=0
    else
      FAILURES=$((FAILURES+1))
      log "Health check failed (${FAILURES}/${MAX_RETRIES})"
      attempt_recovery
    fi

    if [ $FAILURES -ge $MAX_RETRIES ]; then
      log "Reached maximum recovery attempts; stopping watchdog"
      exit 1
    fi

    sleep "$SLEEP_SECONDS"
  done
}

main_loop
