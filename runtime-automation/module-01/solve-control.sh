#!/bin/bash
# Solve Module 01 - Introspection and System Backups
# Launches all required job templates and creates the VSS schedule

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

  echo "Launching: ${name}..."
  JOB_ID=$(${CURL} -X POST -H "Content-Type: application/json" -d '{}' \
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

# Step 1: Launch "Check RHEL Backup" (shows no backups initially)
TMPL_ID=$(get_template_id "Check RHEL Backup")
if [ -n "$TMPL_ID" ]; then
  launch_and_wait "Check RHEL Backup" "$TMPL_ID"
else
  echo "ERROR: 'Check RHEL Backup' template not found"
  exit 1
fi

# Step 2: Launch "Server Backup - XFS/RHEL" (takes ~6-7 min)
TMPL_ID=$(get_template_id "Server Backup - XFS/RHEL")
if [ -n "$TMPL_ID" ]; then
  launch_and_wait "Server Backup - XFS/RHEL" "$TMPL_ID" 600
else
  echo "ERROR: 'Server Backup - XFS/RHEL' template not found"
  exit 1
fi

# Step 3: Launch "Server Backup - VSS/Windows"
VSS_ID=$(get_template_id "Server Backup - VSS/Windows")
if [ -n "$VSS_ID" ]; then
  launch_and_wait "Server Backup - VSS/Windows" "$VSS_ID"
else
  echo "ERROR: 'Server Backup - VSS/Windows' template not found"
  exit 1
fi

# Step 4: Launch "Check Windows Backups"
TMPL_ID=$(get_template_id "Check Windows Backups")
if [ -n "$TMPL_ID" ]; then
  launch_and_wait "Check Windows Backups" "$TMPL_ID"
else
  echo "ERROR: 'Check Windows Backups' template not found"
  exit 1
fi

# Step 5: Create schedule "2 Min Snappy" on VSS/Windows template
echo "Creating schedule '2 Min Snappy' on Server Backup - VSS/Windows..."
EXISTING=$(${CURL} "${AAP_HOST}/api/controller/v2/job_templates/${VSS_ID}/schedules/" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if any('2 Min Snappy' in s['name'] for s in d['results']) else 'false')" 2>/dev/null)

if [ "$EXISTING" = "true" ]; then
  echo "  Schedule already exists, skipping."
else
  RRULE="DTSTART:$(date -u +%Y%m%dT%H%M%SZ) RRULE:FREQ=MINUTELY;INTERVAL=2"
  RESULT=$(${CURL} -X POST -H "Content-Type: application/json" \
    -d "{\"name\": \"2 Min Snappy\", \"description\": \"Automated VSS Snaps\", \"rrule\": \"${RRULE}\", \"unified_job_template\": ${VSS_ID}}" \
    "${AAP_HOST}/api/controller/v2/schedules/" 2>/dev/null)
  SCHED_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
  if [ -n "$SCHED_ID" ]; then
    echo "  Schedule created (ID: ${SCHED_ID})"
  else
    echo "  FAILED to create schedule"
    echo "  Response: ${RESULT}"
    exit 1
  fi
fi

echo ""
echo "========================================"
echo "Module 1 Solver Complete"
echo "========================================"
echo "  [OK] Check RHEL Backup launched"
echo "  [OK] Server Backup - XFS/RHEL launched"
echo "  [OK] Server Backup - VSS/Windows launched"
echo "  [OK] Check Windows Backups launched"
echo "  [OK] Schedule '2 Min Snappy' created"
echo "========================================"
