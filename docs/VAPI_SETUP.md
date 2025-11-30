# Vapi.ai Setup Guide for Hampstead Concierge

This guide walks you through configuring the Vapi.ai Voice AI platform for your Sarah assistant.

## Prerequisites

- Vapi.ai account ([dashboard.vapi.ai](https://dashboard.vapi.ai))
- OpenAI API key with GPT-4o access
- ElevenLabs API key
- Completed Twilio setup (see TWILIO_SETUP.md)

---

## Step 1: Create Your Vapi Account

1. Go to [dashboard.vapi.ai](https://dashboard.vapi.ai)
2. Sign up with email or Google
3. Choose **Pro Plan** (recommended for European servers)
4. Add payment method

---

## Step 2: Connect API Providers

### 2.1 OpenAI Connection

1. Go to **Settings** → **API Keys**
2. Click **Add Key** next to OpenAI
3. Paste your OpenAI API key (`sk-...`)
4. Click **Save**

### 2.2 ElevenLabs Connection

1. In the same API Keys section
2. Click **Add Key** next to ElevenLabs
3. Paste your ElevenLabs API key
4. Click **Save**

### 2.3 Deepgram Connection (Optional)

Vapi includes Deepgram, but for custom config:
1. Add Deepgram API key if you have one
2. Otherwise, use Vapi's built-in Deepgram

---

## Step 3: Create the Assistant

### 3.1 New Assistant

1. Go to **Assistants** → **Create Assistant**
2. Name: `Hampstead Receptionist - Sarah`
3. Click **Create**

### 3.2 Model Configuration

Navigate to the **Model** tab:

| Setting | Value |
|---------|-------|
| **Provider** | OpenAI |
| **Model** | gpt-4o |
| **Temperature** | 0.7 |
| **Max Tokens** | 500 |

### 3.3 System Prompt

Copy the **entire contents** of `config/vapi-system-prompt.md` into the System Prompt field.

Key sections:
- IDENTITY: Who Sarah is
- PERSONA: How she sounds and behaves
- CONVERSATION FLOW: Step-by-step call handling
- GUARDRAILS: What she must never do
- TOOL USAGE: When to call functions

---

## Step 4: Configure Voice

Navigate to the **Voice** tab:

### 4.1 Provider Selection

| Setting | Value |
|---------|-------|
| **Provider** | ElevenLabs |
| **Model** | eleven_turbo_v2 |

### 4.2 Voice Selection

Click **Select Voice** and choose a British female voice:
- Recommended: **Alice** (British, professional)
- Alternative: **Charlotte** (British, warm)
- Or clone a custom voice

### 4.3 Voice Settings

| Setting | Value | Notes |
|---------|-------|-------|
| **Stability** | 0.5 | Natural variation |
| **Similarity Boost** | 0.75 | Clear but warm |
| **Style** | 0.0 | Neutral (natural) |
| **Speaker Boost** | ✅ Enabled | Clearer audio |

---

## Step 5: Configure Transcriber

Navigate to the **Transcriber** tab:

| Setting | Value |
|---------|-------|
| **Provider** | Deepgram |
| **Model** | nova-2 |
| **Language** | en-GB |
| **Smart Format** | ✅ Enabled |
| **Punctuate** | ✅ Enabled |

### 5.1 Add Keywords (Boost Recognition)

Under Keywords, add:
```
Hampstead:5
NW3:3
NW6:3
NW8:3
renovation:3
extension:3
loft:3
basement:3
Ross:5
Finchley Road:3
```

---

## Step 6: Configure Functions (Tools)

Navigate to the **Functions** tab:

### 6.1 Add log_lead_details Function

Click **Add Function** and configure:

**Basic Settings:**
- Name: `log_lead_details`
- Description: `MUST be called when the caller has provided their details and the call is concluding. This sends lead information directly to Ross's WhatsApp.`

**Parameters (JSON Schema):**

```json
{
  "type": "object",
  "properties": {
    "caller_name": {
      "type": "string",
      "description": "The full name of the caller"
    },
    "phone_number": {
      "type": "string",
      "description": "The mobile phone number, format: +447XXXXXXXXX or 07XXXXXXXXX"
    },
    "category": {
      "type": "string",
      "enum": ["Renovation", "Maintenance", "Emergency", "Other"],
      "description": "The category of the enquiry"
    },
    "address": {
      "type": "string",
      "description": "Property address or postcode"
    },
    "summary": {
      "type": "string",
      "description": "1-2 sentence summary of the project or issue"
    },
    "sentiment": {
      "type": "string",
      "enum": ["High Value", "Standard", "Angry/Urgent"],
      "description": "Lead quality assessment"
    },
    "project_type": {
      "type": "string",
      "description": "Specific type of work"
    },
    "timeline": {
      "type": "string",
      "description": "When work is needed"
    },
    "is_returning_client": {
      "type": "boolean",
      "description": "Has worked with Hampstead Renovations before"
    }
  },
  "required": ["caller_name", "phone_number", "category", "summary", "sentiment"]
}
```

**Server Settings:**
- URL: Your Make.com webhook URL
- Timeout: 20 seconds

**Response Messages:**
- On Success: "I've logged your details with Ross."
- On Failure: "I've made a note of your details."

### 6.2 Add log_spam_call Function (Optional)

For tracking spam patterns:

```json
{
  "type": "object",
  "properties": {
    "spam_type": {
      "type": "string",
      "enum": ["SEO/Marketing", "Recruitment", "Lead Generation", "Other"],
      "description": "Category of spam"
    },
    "company_name": {
      "type": "string",
      "description": "Company if mentioned"
    }
  },
  "required": ["spam_type"]
}
```

---

## Step 7: Advanced Settings

Navigate to the **Advanced** tab:

### 7.1 Call Settings

| Setting | Value | Notes |
|---------|-------|-------|
| **First Message** | `Good morning, Hampstead Renovations. Sarah speaking, how may I help you?` | Greeting |
| **First Message Mode** | Assistant Speaks First | Don't wait for caller |
| **Silence Timeout** | 30 seconds | Before ending silent calls |
| **Max Duration** | 600 seconds | 10 minute limit |

### 7.2 Server Configuration

| Setting | Value |
|---------|-------|
| **Server URL** | `https://hook.eu1.make.com/YOUR_WEBHOOK_ID` |
| **Server URL Secret** | Generate a secure random string |

### 7.3 Speech Settings

| Setting | Value | Notes |
|---------|-------|-------|
| **Background Denoising** | ✅ Enabled | Cleaner audio |
| **Backchanneling** | ✅ Enabled | Natural "mm-hmm" responses |
| **Smart Endpointing** | ✅ Enabled | Better pause detection |

### 7.4 End Call Settings

| Setting | Value |
|---------|-------|
| **End Call Function** | ✅ Enabled |
| **End Call Message** | "Thank you for calling Hampstead Renovations. Goodbye." |

---

## Step 8: Regional Settings

For lowest latency in the UK:

1. Go to **Settings** → **Organization**
2. Server Region: **eu-west-1** (Europe)

---

## Step 9: Connect Phone Number

### 9.1 Import Twilio Number

1. Go to **Phone Numbers** tab
2. Click **Import Phone Number**
3. Select **Twilio**
4. Enter your Twilio credentials
5. Select your London number
6. Assign to **Hampstead Receptionist - Sarah**

### 9.2 Alternative: Use Vapi's Webhook

If using Twilio webhook method:
1. Copy the Vapi inbound webhook URL
2. Paste into Twilio phone number configuration

---

## Step 10: Publish & Test

### 10.1 Publish Assistant

1. Review all settings
2. Click **Publish** in top right
3. Status should show "Active"

### 10.2 Test Call

1. Call your Twilio number
2. Verify Sarah answers
3. Test conversation flow
4. Verify function calls fire

### 10.3 Monitor Calls

1. Go to **Calls** tab
2. View recent calls
3. Check transcripts
4. Review function call logs

---

## Configuration Checklist

- [ ] OpenAI API key connected
- [ ] ElevenLabs API key connected
- [ ] Assistant created with correct name
- [ ] System prompt copied in full
- [ ] Voice set to British female (Alice)
- [ ] Voice settings: Stability 0.5, Similarity 0.75
- [ ] Transcriber set to Deepgram Nova-2, en-GB
- [ ] Keywords added for local terms
- [ ] log_lead_details function configured
- [ ] Server URL set to Make.com webhook
- [ ] First message configured
- [ ] Region set to eu-west-1
- [ ] Phone number imported and assigned
- [ ] Assistant published

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Assistant doesn't respond | Check assistant is published |
| Wrong voice accent | Verify ElevenLabs voice is British |
| Function not calling | Check function is enabled and URL is correct |
| High latency | Switch to eu-west-1 region |
| Poor transcription | Verify Nova-2 with en-GB selected |
| Cuts off caller | Increase silence timeout |
| Robotic responses | Adjust temperature to 0.7 |

---

## Next Steps

- [ ] Complete [MAKE_SETUP.md](./MAKE_SETUP.md) to configure notifications
- [ ] Run full test checklist
- [ ] Monitor first week of calls

---

*For Vapi support: [docs.vapi.ai](https://docs.vapi.ai)*
