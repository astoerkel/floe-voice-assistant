#!/bin/bash
cd /opt/voice-assistant

# Update handleGetEmails to check OAuth status from context
cat > /tmp/email-oauth-patch.txt << 'EOF'
  async handleGetEmails(userId, intent, context) {
    try {
      // Check if Gmail integration is active from iOS app context
      const isGoogleConnected = context?.integrations?.google?.connected === true;
      
      if (!isGoogleConnected) {
        logger.info(`Gmail not connected for user ${userId} - integration status from context: ${JSON.stringify(context?.integrations)}`);
        return {
          text: "I'd be happy to help with your emails, but you'll need to connect your Gmail account first. Would you like me to guide you through setting that up?",
          actions: [],
          suggestions: ['Connect Gmail', 'Settings', 'Help']
        };
      }
      
      const limit = intent.filter === 'recent' ? 5 : 10;
      const emails = await this.getEmails(userId, intent.filter, limit);
      
      if (emails.length === 0) {
        const filterText = intent.filter === 'unread' ? 'unread emails' : 
                          intent.filter === 'important' ? 'important emails' : 'emails';
        return {
          text: `You have no ${filterText}.`,
          actions: [],
          suggestions: ['Send an email', 'Search emails', 'Check different folder']
        };
      }
      
      const emailList = emails.map(email => 
        `${email.subject} from ${email.sender}`
      ).join(', ');
      
      const filterText = intent.filter === 'unread' ? 'unread emails' : 
                        intent.filter === 'important' ? 'important emails' : 'recent emails';
      
      return {
        text: `Here are your ${filterText}: ${emailList}`,
        actions: emails.map(email => ({
          type: 'view_email',
          emailId: email.id,
          subject: email.subject
        })),
        suggestions: ['Read email', 'Reply to email', 'Search emails']
      };
    } catch (error) {
      logger.error('Handle get emails failed:', error);
      return {
        text: "I couldn't retrieve your emails. Please try again.",
        actions: [],
        suggestions: ['Try again', 'Check connection']
      };
    }
  }
EOF

# Replace the handleGetEmails method
python3 << 'PYTHON_EOF'
import re

# Read the file
with open('src/services/agents/emailAgent.js', 'r') as f:
    content = f.read()

# Read the new method
with open('/tmp/email-oauth-patch.txt', 'r') as f:
    new_method = f.read()

# Find and replace the handleGetEmails method
pattern = r'async handleGetEmails\(userId, intent, context\) \{[\s\S]*?\n  \}'
content = re.sub(pattern, new_method.strip(), content)

# Write back
with open('src/services/agents/emailAgent.js', 'w') as f:
    f.write(content)

print("Email agent OAuth fix applied")
PYTHON_EOF