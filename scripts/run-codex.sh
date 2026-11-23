#!/usr/bin/env bash
set -euo pipefail

SPEC_FILE=""
SUMMARY_FILE=""
WORK_DIR="$(pwd)"
SANDBOX="workspace-write"
MODEL=""
REASONING_EFFORT=""
RESUME_LAST=0
SKIP_GIT_CHECK=0
IMAGES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec-file)        SPEC_FILE="$2"; shift 2 ;;
    --summary-file)     SUMMARY_FILE="$2"; shift 2 ;;
    --work-dir)         WORK_DIR="$2"; shift 2 ;;
    --sandbox)          SANDBOX="$2"; shift 2 ;;
    --model)            MODEL="$2"; shift 2 ;;
    --reasoning-effort) REASONING_EFFORT="$2"; shift 2 ;;
    --resume-last)      RESUME_LAST=1; shift ;;
    --skip-git-check)   SKIP_GIT_CHECK=1; shift ;;
    --image)            IMAGES+=("$2"); shift 2 ;;
    *)
      echo "[CODEX-WORKER] Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$SPEC_FILE" || -z "$SUMMARY_FILE" ]]; then
  echo "[CODEX-WORKER] --spec-file and --summary-file are required." >&2
  exit 2
fi

if command -v codex >/dev/null 2>&1; then
  CODEX_BIN="$(command -v codex)"
elif [[ -x "$HOME/.codex/packages/standalone/current/bin/codex" ]]; then
  CODEX_BIN="$HOME/.codex/packages/standalone/current/bin/codex"
else
  echo "[CODEX-WORKER] Could not locate codex executable in PATH." >&2
  exit 127
fi

if [[ ! -d "$WORK_DIR" ]]; then
  echo "[CODEX-WORKER] Work directory does not exist: $WORK_DIR" >&2
  exit 2
fi
if [[ ! -s "$SPEC_FILE" ]]; then
  echo "[CODEX-WORKER] Spec file missing or empty: $SPEC_FILE" >&2
  exit 2
fi

WORK_DIR="$(cd "$WORK_DIR" && pwd)"
SPEC_FILE="$(cd "$(dirname "$SPEC_FILE")" && pwd)/$(basename "$SPEC_FILE")"

mkdir -p "$(dirname "$SUMMARY_FILE")"
SUMMARY_FILE="$(cd "$(dirname "$SUMMARY_FILE")" && pwd)/$(basename "$SUMMARY_FILE")"
rm -f "$SUMMARY_FILE"

if command -v git >/dev/null 2>&1; then
  EXCLUDE_FILE="$(git -C "$WORK_DIR" rev-parse --git-path info/exclude 2>/dev/null || true)"
  if [[ -n "$EXCLUDE_FILE" ]]; then
    [[ "$EXCLUDE_FILE" = /* ]] || EXCLUDE_FILE="$WORK_DIR/$EXCLUDE_FILE"
    if [[ -f "$EXCLUDE_FILE" ]] && ! grep -qxF ".codex-tasks/" "$EXCLUDE_FILE"; then
      printf "\n# Antigravity codex-worker task artifacts\n.codex-tasks/\n" >> "$EXCLUDE_FILE"
    fi
  fi
fi

ARGS=("exec" "--cd" "$WORK_DIR" "--sandbox" "$SANDBOX" "--color" "never")
if [[ "$RESUME_LAST" -eq 1 ]]; then
  ARGS+=("resume" "--last")
fi
if [[ "$SKIP_GIT_CHECK" -eq 1 ]]; then
  ARGS+=("--skip-git-repo-check")
fi
if [[ -n "$MODEL" ]]; then
  ARGS+=("--model" "$MODEL")
fi
if [[ -n "$REASONING_EFFORT" ]]; then
  ARGS+=("-c" "model_reasoning_effort=\"$REASONING_EFFORT\"")
fi
for img in "${IMAGES[@]}"; do
  ARGS+=("--image" "$img")
done
ARGS+=("--output-last-message" "$SUMMARY_FILE" "-")

echo "[CODEX-WORKER] Binary  : $CODEX_BIN"
echo "[CODEX-WORKER] WorkDir : $WORK_DIR"
echo "[CODEX-WORKER] Sandbox : $SANDBOX | ResumeLast: $RESUME_LAST | Model: ${MODEL:-(default)} | Effort: ${REASONING_EFFORT:-(default)}"
echo "[CODEX-WORKER] Spec    : $SPEC_FILE"
echo "[CODEX-WORKER] Summary : $SUMMARY_FILE"
echo "------------------------------------------------------------"

(
  cd "$WORK_DIR"
  "$CODEX_BIN" "${ARGS[@]}" < "$SPEC_FILE"
)

echo "------------------------------------------------------------"
if [[ ! -f "$SUMMARY_FILE" ]]; then
  echo "[CODEX-WORKER] Warning: Codex exited 0, but summary file was not created at: $SUMMARY_FILE" >&2
else
  echo "[CODEX-WORKER] Completed successfully. Final summary saved to: $SUMMARY_FILE"
fi
