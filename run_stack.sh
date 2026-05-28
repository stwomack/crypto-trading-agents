#!/usr/bin/env bash
#
# run_stack.sh – prepare a fresh local dev run and print commands for each terminal
#
# Usage:
#   ./run_stack.sh                              # default $1000 portfolio balance
#   ./run_stack.sh --initial-balance 250000     # custom starting balance
#
# Prereqs:
#   • Python venv at .venv/ with deps installed (uv sync)
#   • temporal CLI on PATH (brew install temporal)
#   • env vars from README (OPENAI_API_KEY, Coinbase keys, etc.)
#
# Open one terminal tab/window per step below (Ghostty, iTerm, etc.).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

INITIAL_BALANCE="1000"

while [[ $# -gt 0 ]]; do
  case $1 in
    --initial-balance)
      INITIAL_BALANCE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option $1"
      echo "Usage: $0 [--initial-balance AMOUNT]"
      exit 1
      ;;
  esac
done

echo "Clearing log files for fresh start..."
if [[ -d logs ]]; then
  rm -f logs/*.log logs/*.jsonl
  echo "Cleared all log files in logs/"
else
  echo "No logs/ directory yet (agents will create it)"
fi

divider() { printf '\n%s\n' "────────────────────────────────────────────────────────"; }

print_step() {
  local n="$1" title="$2" extra="${3:-}"
  divider
  printf 'Terminal %s – %s\n' "$n" "$title"
  [[ -n "$extra" ]] && printf '%s\n\n' "$extra"
  printf '  cd %q\n' "$ROOT"
  printf '  source .venv/bin/activate\n'
}

echo ""
echo "Local stack – run each block in its own terminal (in order)."
echo "Initial portfolio balance (worker only): \$${INITIAL_BALANCE}"
echo "Shutdown: Ctrl+C in each terminal (Temporal last)."

print_step 1 "Temporal dev server" \
  "Wait until the server is listening before starting the worker."
printf '  temporal server start-dev\n'

print_step 2 "Temporal worker" \
  "Must see Temporal ready; ledger uses INITIAL_PORTFOLIO_BALANCE."
printf '  export INITIAL_PORTFOLIO_BALANCE=%q\n' "$INITIAL_BALANCE"
printf '  python worker/main.py\n'

print_step 3 "MCP server"
printf '  PYTHONPATH="$PWD" python mcp_server/app.py\n'

print_step 4 "Broker agent" \
  "Start after worker + MCP are up."
printf '  PYTHONPATH="$PWD" python agents/broker_agent_client.py\n'

print_step 5 "Execution agent"
printf '  PYTHONPATH="$PWD" python agents/execution_agent_client.py\n'

print_step 6 "Judge agent"
printf '  PYTHONPATH="$PWD" python agents/judge_agent_client.py\n'

print_step 7 "Ticker UI (optional)"
printf '  PYTHONPATH="$PWD" python ticker_ui_service.py\n'

divider
echo "MCP health: http://localhost:8080/healthz"
echo ""
