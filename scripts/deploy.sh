#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/infra"
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
    echo "Loaded environment from $ENV_FILE"
else
    echo "No .env file found at $ENV_FILE, using defaults/environment."
fi

if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform not found" >&2
    exit 1
fi

cmd="${1:-}"
shift || true

if [ -n "${TF_WORKSPACE:-}" ]; then
    if ! terraform -chdir="$TF_DIR" workspace list >/dev/null 2>&1; then
        terraform -chdir="$TF_DIR" init -input=false
    fi
    if ! terraform -chdir="$TF_DIR" workspace list | grep -q "[[:space:]]${TF_WORKSPACE}$"; then
        terraform -chdir="$TF_DIR" workspace new "$TF_WORKSPACE"
    fi
    terraform -chdir="$TF_DIR" workspace select "$TF_WORKSPACE"
fi

echo "Running terraform $cmd in $TF_DIR"

case "$cmd" in
    init)
        terraform -chdir="$TF_DIR" init "$@"
        ;;
    plan)
        terraform -chdir="$TF_DIR" plan "$@"
        ;;
    apply)
        terraform -chdir="$TF_DIR" apply "$@"
        ;;
    destroy)
        terraform -chdir="$TF_DIR" destroy "$@"
        
        # Clean up auto-created Network Watcher if exists (User Request)
        # Note: This assumes standard naming and RG. Ignoring errors if not found.
        if command -v az >/dev/null 2>&1; then
             echo "Attempting to delete Network Watcher resources..."
             # Try to delete for current location
             # Convention is usually NetworkWatcher_<location> in NetworkWatcherRG
             
             # Specific cleanup for previous region as requested
             az network watcher delete --name NetworkWatcher_canadaeast --resource-group NetworkWatcherRG --yes --no-wait 2>/dev/null || true
             
             # Cleanup for current region (if different)
             if [ -n "${TF_VAR_location:-}" ]; then
                 nw_name="NetworkWatcher_${TF_VAR_location}"
                 az network watcher delete --name "$nw_name" --resource-group NetworkWatcherRG --yes --no-wait 2>/dev/null || true
             fi
        else
             echo "Azure CLI (az) not found, skipping Network Watcher cleanup."
        fi
        ;;
    fmt)
        terraform -chdir="$TF_DIR" fmt -recursive
        ;;
    validate)
        terraform -chdir="$TF_DIR" validate
        ;;
    *)
        echo "Usage: $0 {init|plan|apply|destroy|fmt|validate} [extra args]" >&2
        exit 1
        ;;
esac
