#!/bin/bash

# --- CONFIGURATION ---
WEBHOOK_URL="DISCORD WEBHOOK"
ABUSE_IPDB_KEY="API KEY GOES HERE"

LOG_FILE="/var/log/asterisk/freepbx_security.log"
# ---------------------

# Regex pattern to capture: 1=Date, 2=Type(success/fail), 3=User, 4=IP
REGEX="^\[(.*?)\] .* Authentication (successful|failure) for (.*) from ([^ ]+)"

# Watch the log file
tail -Fn0 "$LOG_FILE" | while read line; do

    # Check if the line matches our pattern
    if [[ $line =~ $REGEX ]]; then

        # Extract variables from the Regex match
        LOG_DATE="${BASH_REMATCH[1]}"
        STATUS="${BASH_REMATCH[2]}"
        USER="${BASH_REMATCH[3]}"
        IP_ADDRESS="${BASH_REMATCH[4]}"

        # Determine Colors and Titles based on status
        if [ "$STATUS" == "successful" ]; then
            COLOR="5763719"  # Green
            TITLE="✅ Access Granted"
            DESC="User logged in successfully."
        else
            COLOR="15548997" # Red
            TITLE="⛔ Access Denied"
            DESC="Failed login attempt detected."

            # --- REPORT TO ABUSEIPDB (API v2) ---
            # Runs in background (&) to prevent lag
            # Categories 18 = "Brute-Force"
            curl -s "https://api.abuseipdb.com/api/v2/report" \
                 -H "Key: ${ABUSE_IPDB_KEY}" \
                 -H "Accept: application/json" \
                 --data-urlencode "ip=${IP_ADDRESS}" \
                 --data-urlencode "categories=18" \
                 --data-urlencode "comment=Asterisk/FreePBX Auth Failure for user: ${USER}" \
                 > /dev/null &
        fi

        # Construct JSON Payload with Fields
        PAYLOAD=$(cat <<EOF
{
  "embeds": [
    {
      "title": "$TITLE",
      "description": "$DESC",
      "color": $COLOR,
      "fields": [
        {
          "name": "User",
          "value": "\`$USER\`",
          "inline": true
        },
        {
          "name": "Source IP",
          "value": "\`$IP_ADDRESS\`",
          "inline": true
        },
        {
          "name": "Time",
          "value": "$LOG_DATE",
          "inline": false
        }
      ],
      "footer": {
        "text": "CSP Texas Security Alerts"
      }
    }
  ]
}
EOF
)

        # Send to Discord
        curl -s -H "Content-Type: application/json" \
             -X POST \
             -d "$PAYLOAD" \
             "$WEBHOOK_URL" > /dev/null
    fi

done
