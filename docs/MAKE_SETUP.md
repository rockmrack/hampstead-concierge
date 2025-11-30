# Make.com Setup Guide for Hampstead Concierge

This guide walks you through configuring Make.com to route leads to WhatsApp, email, and your database.

## Prerequisites

- Make.com account ([make.com](https://www.make.com))
- Vapi assistant configured (see VAPI_SETUP.md)
- WhatsApp Business API access
- Ross's WhatsApp number: +447459345456

---

## Step 1: Create Make.com Account

1. Go to [make.com](https://www.make.com)
2. Sign up for an account
3. Choose **Core Plan** or higher (for multiple scenarios)
4. Verify your email

---

## Step 2: Create Main Scenario

### 2.1 New Scenario

1. Click **Create a new scenario**
2. Name it: `Hampstead Concierge - Lead Router`

### 2.2 Add Webhook Trigger

1. Click the **+** to add first module
2. Search for **Webhooks**
3. Select **Custom webhook**
4. Click **Add** to create new webhook
5. Name: `Vapi Lead Webhook`
6. Click **Save**
7. **Copy the webhook URL** - you'll need this for Vapi!

The URL looks like:
```
https://hook.eu1.make.com/abc123xyz789
```

---

## Step 3: Test Webhook Data Structure

### 3.1 Send Test Data

Before building the scenario, determine the data structure:

1. Click **Run once** on the scenario
2. Go to Vapi dashboard
3. Make a test call and provide details
4. The webhook will receive the payload

### 3.2 Expected Payload Structure

```json
{
  "message": {
    "type": "function-call",
    "functionCall": {
      "name": "log_lead_details",
      "parameters": {
        "caller_name": "John Smith",
        "phone_number": "+447700900123",
        "category": "Renovation",
        "address": "42 Elm Row, NW3",
        "summary": "Complete house renovation including loft conversion",
        "sentiment": "High Value",
        "project_type": "Full Refurbishment",
        "timeline": "3-6 months",
        "is_returning_client": false
      }
    }
  },
  "call": {
    "id": "call_abc123",
    "createdAt": "2025-11-30T10:30:00Z",
    "phoneNumber": "+447700900123"
  }
}
```

---

## Step 4: Add Router Module

### 4.1 Add Router

1. Click **+** after the webhook
2. Search for **Router**
3. Add the Router module

### 4.2 Configure Routes

Create 4 routes by clicking the router and adding paths:

| Route | Name | Purpose |
|-------|------|---------|
| A | High Value Renovation | Immediate WhatsApp |
| B | Emergency | WhatsApp + Email |
| C | Maintenance | WhatsApp + Database |
| D | Other/Low Priority | Database only |

---

## Step 5: Configure Route A - High Value Renovation

### 5.1 Set Filter

Click the route line and set filter:
- **Label**: High Value Renovation
- **Condition**: 
  ```
  {{message.functionCall.parameters.category}} = "Renovation"
  OR
  {{message.functionCall.parameters.sentiment}} = "High Value"
  ```

### 5.2 Add WhatsApp Module

1. Click **+** on Route A
2. Search for **WhatsApp Business Cloud**
3. Select **Send a Message**
4. Connect your WhatsApp Business account

### 5.3 Configure WhatsApp Message

| Field | Value |
|-------|-------|
| **To** | `+447459345456` |
| **Type** | Text |
| **Body** | See template below |

**Message Template:**
```
🚨 *NEW LEAD: RENOVATION*

👤 *Name:* {{message.functionCall.parameters.caller_name}}
📍 *Address:* {{message.functionCall.parameters.address}}
📝 *Note:* {{message.functionCall.parameters.summary}}
📞 *Callback:* {{message.functionCall.parameters.phone_number}}
🏷️ *Type:* {{message.functionCall.parameters.project_type}}
⏰ *Timeline:* {{message.functionCall.parameters.timeline}}
📊 *AI Sentiment:* {{message.functionCall.parameters.sentiment}}

_Received: {{call.createdAt}}_
```

---

## Step 6: Configure Route B - Emergency

### 6.1 Set Filter

- **Label**: Emergency
- **Condition**:
  ```
  {{message.functionCall.parameters.category}} = "Emergency"
  OR
  {{message.functionCall.parameters.sentiment}} = "Angry/Urgent"
  ```

### 6.2 Add WhatsApp Module (Urgent)

**Message Template:**
```
🔴🔴🔴 *EMERGENCY CALL* 🔴🔴🔴

👤 *Name:* {{message.functionCall.parameters.caller_name}}
📍 *Address:* {{message.functionCall.parameters.address}}
📝 *Issue:* {{message.functionCall.parameters.summary}}
📞 *CALL NOW:* {{message.functionCall.parameters.phone_number}}

⚠️ *URGENT - Callback within 15 mins*

_Received: {{call.createdAt}}_
```

### 6.3 Add Email Module

1. Add **Email** module after WhatsApp
2. Configure:

| Field | Value |
|-------|-------|
| **To** | `office@hampsteadrenovations.com` |
| **CC** | `ross@hampsteadrenovations.com` |
| **Subject** | `🚨 EMERGENCY: {{message.functionCall.parameters.caller_name}}` |
| **Content** | See below |

**Email Template:**
```
EMERGENCY CALL RECEIVED
========================

Caller: {{message.functionCall.parameters.caller_name}}
Phone: {{message.functionCall.parameters.phone_number}}
Address: {{message.functionCall.parameters.address}}

Issue:
{{message.functionCall.parameters.summary}}

------------------------
Sentiment: {{message.functionCall.parameters.sentiment}}
Timestamp: {{call.createdAt}}
Call ID: {{call.id}}

------------------------
This is an automated message from Hampstead Concierge AI.
```

---

## Step 7: Configure Route C - Maintenance

### 7.1 Set Filter

- **Label**: Maintenance
- **Condition**:
  ```
  {{message.functionCall.parameters.category}} = "Maintenance"
  ```

### 7.2 Add WhatsApp Module

**Message Template:**
```
🔧 *MAINTENANCE REQUEST*

👤 *Name:* {{message.functionCall.parameters.caller_name}}
📍 *Address:* {{message.functionCall.parameters.address}}
📝 *Issue:* {{message.functionCall.parameters.summary}}
📞 *Callback:* {{message.functionCall.parameters.phone_number}}
🏷️ *Type:* {{message.functionCall.parameters.project_type}}

_Received: {{call.createdAt}}_
```

---

## Step 8: Configure Route D - Other

### 8.1 Set Filter

- **Label**: Other/General
- **Condition**:
  ```
  {{message.functionCall.parameters.category}} = "Other"
  ```

### 8.2 Add Conditional WhatsApp (Optional)

Only send WhatsApp if high sentiment:

1. Add **Filter** module
2. Condition: `{{message.functionCall.parameters.sentiment}} = "High Value"`
3. If true, send WhatsApp

---

## Step 9: Add Database Logging (All Routes)

### 9.1 Supabase Setup

1. Create Supabase account at [supabase.com](https://supabase.com)
2. Create new project
3. Create `leads` table (see SQL in README)
4. Get API URL and keys

### 9.2 Add Supabase Module to Each Route

1. Search for **Supabase** or use **HTTP** module
2. Add after WhatsApp on each route
3. Configure:

| Field | Value |
|-------|-------|
| **Method** | POST |
| **URL** | `https://YOUR_PROJECT.supabase.co/rest/v1/leads` |
| **Headers** | `apikey: YOUR_ANON_KEY` |
| | `Authorization: Bearer YOUR_ANON_KEY` |
| | `Content-Type: application/json` |
| | `Prefer: return=minimal` |

**Body:**
```json
{
  "caller_name": "{{message.functionCall.parameters.caller_name}}",
  "phone_number": "{{message.functionCall.parameters.phone_number}}",
  "category": "{{message.functionCall.parameters.category}}",
  "address": "{{message.functionCall.parameters.address}}",
  "summary": "{{message.functionCall.parameters.summary}}",
  "sentiment": "{{message.functionCall.parameters.sentiment}}",
  "project_type": "{{message.functionCall.parameters.project_type}}",
  "timeline": "{{message.functionCall.parameters.timeline}}",
  "call_id": "{{call.id}}",
  "status": "new",
  "priority": "{{IF(message.functionCall.parameters.sentiment = 'High Value'; 'high'; IF(message.functionCall.parameters.category = 'Emergency'; 'critical'; 'medium'))}}"
}
```

---

## Step 10: Create Spam Logging Scenario (Optional)

### 10.1 New Scenario

1. Create new scenario: `Hampstead Concierge - Spam Logger`
2. Add Webhook trigger
3. Name: `Vapi Spam Webhook`
4. Copy this webhook URL for Vapi spam function

### 10.2 Add Google Sheets Module

1. Add **Google Sheets** → **Add a Row**
2. Connect Google account
3. Create spreadsheet: "Hampstead Concierge - Spam Log"
4. Configure columns:

| Column | Value |
|--------|-------|
| A: Date | `{{call.createdAt}}` |
| B: Spam Type | `{{message.functionCall.parameters.spam_type}}` |
| C: Company | `{{message.functionCall.parameters.company_name}}` |
| D: Caller Number | `{{call.phoneNumber}}` |

---

## Step 11: Error Handling

### 11.1 Add Error Handler

1. Click on any module
2. Select **Add error handler**
3. Choose **Resume** or **Ignore**

### 11.2 SMS Fallback (If WhatsApp Fails)

1. Add error handler to WhatsApp module
2. Add **Twilio** → **Send SMS**
3. Configure:

| Field | Value |
|-------|-------|
| **To** | `+447459345456` |
| **Body** | `New lead: {{message.functionCall.parameters.caller_name}} - {{message.functionCall.parameters.phone_number}}` |

---

## Step 12: Activate Scenarios

### 12.1 Turn On Scheduling

1. Click the toggle to activate scenario
2. Set scheduling to **Immediately** (real-time)

### 12.2 Test Full Flow

1. Make a test call to Twilio number
2. Provide name, phone, address, project details
3. Wait for Sarah to end the call
4. Check:
   - [ ] WhatsApp received on +447459345456
   - [ ] Database entry created
   - [ ] Make.com logs show success

---

## Complete Scenario Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    MAKE.COM SCENARIO                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Webhook] ──▶ [Router]                                        │
│                   │                                             │
│      ┌───────────┼───────────┬───────────┐                     │
│      │           │           │           │                     │
│      ▼           ▼           ▼           ▼                     │
│  [Route A]   [Route B]   [Route C]   [Route D]                 │
│  High Value  Emergency   Maintenance  Other                    │
│      │           │           │           │                     │
│      ▼           ▼           ▼           ▼                     │
│  [WhatsApp]  [WhatsApp]  [WhatsApp]  [Filter]                  │
│      │           │           │           │                     │
│      │           ▼           │      [WhatsApp]                 │
│      │       [Email]        │      (if high)                   │
│      │           │           │           │                     │
│      ▼           ▼           ▼           ▼                     │
│  [Supabase]  [Supabase]  [Supabase]  [Supabase]               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Webhook URLs Summary

After setup, you'll have these URLs to configure in Vapi:

| Function | Webhook URL |
|----------|-------------|
| log_lead_details | `https://hook.eu1.make.com/xxx` (Main scenario) |
| log_spam_call | `https://hook.eu1.make.com/yyy` (Spam scenario) |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Webhook not receiving | Verify URL in Vapi is correct |
| WhatsApp not sending | Check Business API connection |
| Wrong data mapping | Test webhook and check field names |
| Scenario not running | Ensure scenario is ON and scheduled |
| Database errors | Check Supabase API key and URL |

---

## Cost Considerations

| Make.com Plan | Operations/Month | Cost | Suitable For |
|---------------|------------------|------|--------------|
| Free | 1,000 | £0 | Testing only |
| Core | 10,000 | £9/mo | Low volume |
| Pro | 40,000 | £16/mo | Medium volume |
| Teams | 150,000 | £29/mo | High volume |

Average: 1 call = ~5 operations (webhook + router + WhatsApp + database)

---

## Next Steps

- [ ] Copy webhook URLs to Vapi assistant
- [ ] Test all routes with sample calls
- [ ] Verify WhatsApp delivery to Ross's phone
- [ ] Set up Supabase dashboard for lead viewing

---

*For Make.com support: [help.make.com](https://help.make.com)*
