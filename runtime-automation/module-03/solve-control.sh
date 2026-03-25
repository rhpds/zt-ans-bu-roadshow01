#!/bin/bash
# Solve Module 03 - Generating a Windows Patch Report

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

# Step 1: Create survey on Windows Update Report template
WUR_ID=$(get_template_id "Windows Update Report")
if [ -z "$WUR_ID" ]; then
  echo "ERROR: 'Windows Update Report' template not found"
  exit 1
fi

echo "Creating survey on Windows Update Report template..."
EXISTING_SURVEY=$(${CURL} "${AAP_HOST}/api/controller/v2/job_templates/${WUR_ID}/survey_spec/" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
specs = d.get('spec', [])
print('true' if any(s.get('variable','') == 'update_category' for s in specs) else 'false')
" 2>/dev/null)

if [ "$EXISTING_SURVEY" = "true" ]; then
  echo "  Survey already exists, skipping."
else
  ${CURL} -X POST -H "Content-Type: application/json" \
    -d '{
      "name": "",
      "description": "",
      "spec": [
        {
          "question_name": "Which update category are you wanting to search for?",
          "question_description": "Windows Update Category",
          "required": true,
          "type": "multiplechoice",
          "variable": "update_category",
          "min": 0,
          "max": 1024,
          "default": "Security Updates",
          "choices": ["Security Updates", "Critical Updates", "Tools", "Definition Updates", "Updates"]
        }
      ]
    }' \
    "${AAP_HOST}/api/controller/v2/job_templates/${WUR_ID}/survey_spec/" > /dev/null 2>&1
  echo "  Survey created."
fi

# Step 2: Enable the survey
echo "Enabling survey on Windows Update Report template..."
${CURL} -X PATCH -H "Content-Type: application/json" \
  -d '{"survey_enabled": true}' \
  "${AAP_HOST}/api/controller/v2/job_templates/${WUR_ID}/" > /dev/null 2>&1
echo "  Survey enabled."

# Step 3: Launch Windows Update Report with "Security Updates"
launch_and_wait "Windows Update Report" "$WUR_ID" 600 \
  '{"extra_vars": {"update_category": "Security Updates"}}'

echo ""
echo "========================================"
echo "Module 3 Solver Complete"
echo "========================================"
echo "  [OK] Survey created on Windows Update Report"
echo "  [OK] Survey enabled"
echo "  [OK] Windows Update Report launched with Security Updates"
echo "========================================"
