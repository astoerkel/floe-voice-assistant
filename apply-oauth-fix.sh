#!/bin/bash

# Update voice.controller.js - Line 26
sed -i.bak 's/const { text, context = {}, platform = '\''ios'\'' } = req.body;/const { text, context = {}, platform = '\''ios'\'', integrations = {} } = req.body;/' src/controllers/voice.controller.js

# Update voice.controller.js - Line 71-72 (add integrations to context)
sed -i 's/startTime$/startTime,/' src/controllers/voice.controller.js
sed -i '/startTime,$/a\        integrations \/\/ Pass OAuth integration status from iOS app' src/controllers/voice.controller.js

echo "OAuth fix applied successfully"