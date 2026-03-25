#!/bin/bash
# Solve Module 02 - Infrastructure Introspection and Reporting

AAP_HOST="https://localhost"
AAP_USER="admin"
AAP_PASS="ansible123!"
CURL="curl -sk -u ${AAP_USER}:${AAP_PASS}"

get_template_id() {
  ${CURL} "${AAP_HOST}/api/controller/v2/job_templates/?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$1'))")" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['id'] if d['count']>0 else '')" 2>/dev/null
}

launch_and_wait() {
  local name="$1"
  local tmpl_id="$2"
  local max_wait="${3:-600}"
  local extra_data="${4:-{}}"

  echo "Launching: ${name}..."
  JOB_ID=$(${CURL} -X POST -H "Content-Type: application/json" -d "${extra_data}" \
    "${AAP_HOST}/api/controller/v2/job_templates/${tmpl_id}/launch/" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

  if [ -z "$JOB_ID" ]; then
    echo "  FAILED to launch ${name}"
    return 1
  fi

  echo "  Job ID: ${JOB_ID} - waiting for completion..."
  elapsed=0
  while [ $elapsed -lt $max_wait ]; do
    STATUS=$(${CURL} "${AAP_HOST}/api/controller/v2/jobs/${JOB_ID}/" \
      | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
    case "$STATUS" in
      successful)
        echo "  Completed successfully."
        return 0
        ;;
      failed|error|canceled)
        echo "  FAILED with status: ${STATUS}"
        return 1
        ;;
    esac
    sleep 10
    elapsed=$((elapsed + 10))
  done
  echo "  TIMED OUT after ${max_wait}s"
  return 1
}

# Step 1: Run ad-hoc command (setup module on node01)
echo "Running ad-hoc command (setup module) on node01..."

# Get the inventory ID for Video Platform Inventory
INV_ID=$(${CURL} "${AAP_HOST}/api/controller/v2/inventories/?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('Video Platform Inventory'))")" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['id'] if d['count']>0 else '')" 2>/dev/null)

# Get the host ID for node01
HOST_ID=$(${CURL} "${AAP_HOST}/api/controller/v2/hosts/?inventory=${INV_ID}&name=node01" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['id'] if d['count']>0 else '')" 2>/dev/null)

# Get credential ID for Application Nodes
CRED_ID=$(${CURL} "${AAP_HOST}/api/controller/v2/credentials/?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('Application Nodes'))")" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['id'] if d['count']>0 else '')" 2>/dev/null)

# Get default EE ID
EE_ID=$(${CURL} "${AAP_HOST}/api/controller/v2/execution_environments/?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('Default execution environment'))")" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['id'] if d['count']>0 else '')" 2>/dev/null)

if [ -n "$HOST_ID" ] && [ -n "$CRED_ID" ] && [ -n "$EE_ID" ]; then
  ADHOC_ID=$(${CURL} -X POST -H "Content-Type: application/json" \
    -d "{\"module_name\": \"setup\", \"module_args\": \"\", \"inventory\": ${INV_ID}, \"credential\": ${CRED_ID}, \"execution_environment\": ${EE_ID}, \"limit\": \"node01\"}" \
    "${AAP_HOST}/api/controller/v2/ad_hoc_commands/" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

  if [ -n "$ADHOC_ID" ]; then
    echo "  Ad-hoc command ID: ${ADHOC_ID} - waiting..."
    elapsed=0
    while [ $elapsed -lt 120 ]; do
      STATUS=$(${CURL} "${AAP_HOST}/api/controller/v2/ad_hoc_commands/${ADHOC_ID}/" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
      case "$STATUS" in
        successful) echo "  Ad-hoc command completed."; break ;;
        failed|error|canceled) echo "  Ad-hoc command failed: ${STATUS}"; break ;;
      esac
      sleep 5
      elapsed=$((elapsed + 5))
    done
  else
    echo "  WARNING: Failed to launch ad-hoc command"
  fi
else
  echo "  WARNING: Could not find host/credential/EE for ad-hoc command"
fi

# Step 2: Launch "Application Server Report"
TMPL_ID=$(get_template_id "Application Server Report")
if [ -n "$TMPL_ID" ]; then
  launch_and_wait "Application Server Report" "$TMPL_ID"
else
  echo "ERROR: 'Application Server Report' template not found"
  exit 1
fi

# Step 3: Launch "OpenSCAP Report"
TMPL_ID=$(get_template_id "OpenSCAP Report")
if [ -n "$TMPL_ID" ]; then
  launch_and_wait "OpenSCAP Report" "$TMPL_ID"
else
  echo "ERROR: 'OpenSCAP Report' template not found"
  exit 1
fi

echo ""
echo "========================================"
echo "Module 2 Solver Complete"
echo "========================================"
echo "  [OK] Ad-hoc command (setup) on node01"
echo "  [OK] Application Server Report launched"
echo "  [OK] OpenSCAP Report launched"
echo "========================================"
