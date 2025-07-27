#!/bin/bash
cd /opt/voice-assistant

# First, find the getEmails function and update it
sed -i '/async getEmails(userId, filter = .all., limit = 10)/s/)/) {/' src/services/agents/emailAgent.js
sed -i '/async getEmails(userId, filter = .all., limit = 10)/s/)/, context = {})/' src/services/agents/emailAgent.js

# Create a temporary file with the OAuth check logic
cat > /tmp/oauth-check.txt << 'EOF'
      // Check if Gmail integration is active from iOS app context first
      const isActiveFromContext = context?.integrations?.google?.connected === true;
      
      // Only check database if context doesn't provide integration status
      let isActive = isActiveFromContext;
      if (!context?.integrations) {
        isActive = await this.gmailService.isIntegrationActive(userId);
      }
      
      if (!isActive) {
        logger.warn(\`Gmail integration not active for user \${userId} (context: \${isActiveFromContext}, db check: \${!context?.integrations})\`);
        // Return a special indicator that Google isn't connected
        return { notConnected: true };
      }
EOF

# Now replace the old check with the new one
# This is complex, so let's do it with a Python script
python3 << 'PYTHON_EOF'
import re

# Read the file
with open('src/services/agents/emailAgent.js', 'r') as f:
    content = f.read()

# Find and replace the OAuth check
old_pattern = r'// Check if Gmail integration is active\s*\n\s*const isActive = await this\.gmailService\.isIntegrationActive\(userId\);\s*\n\s*if \(!isActive\) \{\s*\n\s*logger\.warn\(`Gmail integration not active for user \$\{userId\}`\);\s*\n\s*return \[\];\s*\n\s*\}'

new_check = '''// Check if Gmail integration is active from iOS app context first
      const isActiveFromContext = context?.integrations?.google?.connected === true;
      
      // Only check database if context doesn't provide integration status
      let isActive = isActiveFromContext;
      if (!context?.integrations) {
        isActive = await this.gmailService.isIntegrationActive(userId);
      }
      
      if (!isActive) {
        logger.warn(\`Gmail integration not active for user \${userId} (context: \${isActiveFromContext}, db check: \${!context?.integrations})\`);
        // Return a special indicator that Google isn't connected
        return { notConnected: true };
      }'''

content = re.sub(old_pattern, new_check, content, flags=re.MULTILINE | re.DOTALL)

# Write back
with open('src/services/agents/emailAgent.js', 'w') as f:
    f.write(content)
PYTHON_EOF

# Update handleGetEmails to pass context
sed -i 's/await this\.getEmails(userId, intent\.filter, limit);/await this.getEmails(userId, intent.filter, limit, context);/' src/services/agents/emailAgent.js

# Add the notConnected check in handleGetEmails
python3 << 'PYTHON_EOF'
import re

with open('src/services/agents/emailAgent.js', 'r') as f:
    content = f.read()

# Find the handleGetEmails function and add the notConnected check
pattern = r'(const emails = await this\.getEmails\(userId, intent\.filter, limit, context\);)\s*\n\s*(if \(emails\.length === 0\) \{)'

replacement = r'''\1
      
      // Check if Google isn't connected
      if (emails.notConnected) {
        return {
          text: "I can see your Google account is connected, but I'm having trouble accessing your emails. Let me check your connection status.",
          actions: [],
          suggestions: ['Check connection status', 'Try again', 'Reconnect Google']
        };
      }
      
      \2'''

content = re.sub(pattern, replacement, content)

with open('src/services/agents/emailAgent.js', 'w') as f:
    f.write(content)
PYTHON_EOF

echo "Email agent OAuth fix applied"