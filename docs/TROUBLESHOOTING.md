# Troubleshooting Guide for Hampstead Concierge

Common issues and solutions for the AI Voice Assistant system.

---

## 🔴 Call Issues

### Issue: Calls Not Connecting

**Symptoms:**
- Phone rings but no answer
- "Application error" message
- Call disconnects immediately

**Solutions:**

1. **Check Twilio Configuration**
   - Log into Twilio Console
   - Verify phone number is active
   - Check Voice URL points to Vapi
   - Test with Twilio's built-in test feature

2. **Check Vapi Assistant**
   - Ensure assistant is **Published**
   - Verify phone number is assigned to assistant
   - Check Vapi dashboard for errors

3. **Check API Keys**
   - Verify OpenAI key is valid and has credits
   - Verify ElevenLabs key is valid
   - Check Vapi API key status

---

### Issue: High Latency (>800ms Response)

**Symptoms:**
- Long pauses before Sarah speaks
- Conversation feels sluggish
- Caller hangs up due to silence

**Solutions:**

1. **Switch Vapi Region**
   - Go to Vapi Settings → Organization
   - Change region to `eu-west-1` (Europe)
   - Republish assistant

2. **Optimize Voice Settings**
   - Use ElevenLabs Turbo v2 model
   - Enable streaming latency optimization
   - Reduce max tokens to 300-500

3. **Check Internet Connection**
   - Ensure stable connection for all services
   - Test during off-peak hours

---

### Issue: Sarah Interrupts Caller

**Symptoms:**
- AI talks over the caller
- Doesn't wait for complete sentences
- Choppy conversation flow

**Solutions:**

1. **Adjust Endpointing Settings**
   ```json
   "startSpeakingPlan": {
     "waitSeconds": 0.5,
     "smartEndpointingEnabled": true,
     "transcriptionEndpointingPlan": {
       "onPunctuationSeconds": 0.2,
       "onNoPunctuationSeconds": 1.8,
       "onNumberSeconds": 0.7
     }
   }
   ```

2. **Increase Wait Time**
   - Set `waitSeconds` to 0.6-0.8
   - Increase `onNoPunctuationSeconds` to 2.0

---

### Issue: Sarah Doesn't Stop When Interrupted

**Symptoms:**
- AI continues talking when caller speaks
- Feels unnatural and robotic

**Solutions:**

1. **Check Stop Speaking Plan**
   ```json
   "stopSpeakingPlan": {
     "numWords": 0,
     "voiceSeconds": 0.2,
     "backoffSeconds": 1
   }
   ```

2. **Reduce voiceSeconds**
   - Try 0.1 for faster interruption detection

---

## 🎤 Voice & Audio Issues

### Issue: Robotic or Unnatural Voice

**Symptoms:**
- Sarah sounds mechanical
- Pronunciation is awkward
- Lacks natural variation

**Solutions:**

1. **Adjust ElevenLabs Settings**
   | Setting | Recommended Value |
   |---------|------------------|
   | Stability | 0.4 - 0.5 |
   | Similarity | 0.70 - 0.75 |
   | Style | 0.0 - 0.1 |
   | Speaker Boost | Enabled |

2. **Try Different Voice**
   - Switch to "Alice" or "Charlotte"
   - Consider custom voice cloning

3. **Check Text-to-Speech Model**
   - Use `eleven_turbo_v2` for best quality/latency balance

---

### Issue: Wrong Accent (Not British)

**Symptoms:**
- American pronunciation
- Wrong intonation patterns

**Solutions:**

1. **Verify Voice Selection**
   - Ensure British voice is selected in ElevenLabs
   - Recommended: Alice, Charlotte, or British-cloned voice

2. **Add Pronunciation Hints in Prompt**
   - "Pronounce 'schedule' as SHED-yool"
   - "Use British spellings and terms"

---

### Issue: Poor Transcription Accuracy

**Symptoms:**
- Sarah misunderstands words
- Phone numbers captured incorrectly
- Names garbled

**Solutions:**

1. **Verify Transcriber Settings**
   - Provider: Deepgram
   - Model: Nova-2
   - Language: en-GB (not en-US)

2. **Add Keyword Boosting**
   ```json
   "keywords": [
     "Hampstead:5",
     "NW3:3",
     "renovation:3",
     "Ross:5"
   ]
   ```

3. **Enable Smart Formatting**
   - Turn on punctuation
   - Turn on smart format

---

## 📱 Notification Issues

### Issue: WhatsApp Not Received

**Symptoms:**
- Call completes but no WhatsApp message
- Database updated but WhatsApp missing

**Solutions:**

1. **Check Make.com Scenario**
   - Verify scenario is **ON**
   - Check scenario execution history
   - Look for error messages

2. **Verify Webhook URL**
   - Copy Make.com webhook URL
   - Paste exactly into Vapi Server URL
   - Include full URL with https://

3. **Check WhatsApp Connection**
   - Verify WhatsApp Business API connection
   - Check phone number format: `+447459345456`
   - Ensure WhatsApp module is active

4. **Test Webhook Manually**
   - Use Postman or curl to send test payload
   - Verify Make.com receives it

---

### Issue: Function Call Not Firing

**Symptoms:**
- Call ends but log_lead_details never called
- No data sent to Make.com

**Solutions:**

1. **Verify Function Configuration**
   - Check function is enabled in Vapi
   - Verify server URL is set
   - Check function name matches prompt

2. **Review System Prompt**
   - Ensure prompt explicitly tells AI to call function
   - Add: "You MUST call log_lead_details before ending"

3. **Check Required Fields**
   - Ensure AI collects all required fields
   - Required: caller_name, phone_number, category, summary, sentiment

4. **Test with Simpler Scenario**
   - Create test call that provides all info clearly
   - Check Vapi call logs for function call attempts

---

### Issue: Delayed Notifications (>30 seconds)

**Symptoms:**
- WhatsApp arrives but very late
- Make.com shows queued execution

**Solutions:**

1. **Upgrade Make.com Plan**
   - Free tier has execution delays
   - Core/Pro plans process immediately

2. **Check Make.com Queue**
   - View scenario queue status
   - Clear any stuck executions

3. **Simplify Scenario**
   - Reduce number of modules
   - Parallelize independent operations

---

## 🗄️ Database Issues

### Issue: Leads Not Saving to Supabase

**Symptoms:**
- WhatsApp works but database empty
- Make.com shows HTTP error

**Solutions:**

1. **Verify Supabase Configuration**
   - Check API URL is correct
   - Verify anon key is valid
   - Test direct API call with Postman

2. **Check Table Schema**
   - Ensure `leads` table exists
   - Verify all columns match expected fields
   - Check column types (string, boolean, etc.)

3. **Review Headers**
   ```
   apikey: YOUR_ANON_KEY
   Authorization: Bearer YOUR_ANON_KEY
   Content-Type: application/json
   Prefer: return=minimal
   ```

4. **Check Row Level Security**
   - Supabase may block inserts by default
   - Add policy: `ENABLE INSERT FOR ALL`

---

## 🛡️ Spam Handling Issues

### Issue: Legitimate Calls Marked as Spam

**Symptoms:**
- Real clients being hung up on
- False positive spam detection

**Solutions:**

1. **Review Spam Keywords in Prompt**
   - Make detection more specific
   - Add: "Only terminate if clearly selling services"

2. **Add Confirmation Step**
   - Have Sarah ask: "Just to confirm, you're calling about..."
   - Only terminate after confirmation

---

### Issue: Spam Calls Getting Through

**Symptoms:**
- Sales calls reaching WhatsApp
- Time wasted on fake leads

**Solutions:**

1. **Expand Spam Detection**
   - Add more keywords: SEO, marketing, recruitment, leads, PPI, insurance
   - Add pattern: "I'm calling about your Google listing"

2. **Add Company Blocklist**
   - Log spam company names
   - Update prompt with known spammers

---

## 🔧 Quick Diagnostic Commands

### Test Webhook

```powershell
# Test Make.com webhook
$body = @{
    message = @{
        type = "function-call"
        functionCall = @{
            name = "log_lead_details"
            parameters = @{
                caller_name = "Test User"
                phone_number = "+447700900123"
                category = "Renovation"
                summary = "Test call"
                sentiment = "Standard"
            }
        }
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "YOUR_WEBHOOK_URL" -Method Post -Body $body -ContentType "application/json"
```

### Check Vapi Status

1. Go to [status.vapi.ai](https://status.vapi.ai)
2. Check for any incidents

### Check Twilio Status

1. Go to [status.twilio.com](https://status.twilio.com)
2. Verify Voice services operational

---

## 📞 Getting Help

### Vapi Support
- Docs: [docs.vapi.ai](https://docs.vapi.ai)
- Discord: [discord.gg/vapi](https://discord.gg/vapi)

### Twilio Support
- Docs: [twilio.com/docs](https://twilio.com/docs)
- Console: [console.twilio.com](https://console.twilio.com)

### Make.com Support
- Help: [help.make.com](https://help.make.com)
- Community: [community.make.com](https://community.make.com)

---

## 🆘 Emergency Procedures

### If System Completely Down

1. **Immediate**: Forward Twilio number to Ross's mobile
   - Twilio Console → Phone Number → Forward to +447459345456

2. **Investigate**: Check each service status page

3. **Restore**: Fix issue and re-enable Vapi webhook

### If WhatsApp Blocked

1. **Enable SMS Fallback** in Make.com
2. **Check WhatsApp Business** account status
3. **Contact WhatsApp** support if suspended

---

*Last updated: November 2025*
