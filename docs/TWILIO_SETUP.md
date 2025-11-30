# Twilio Setup Guide for Hampstead Concierge

This guide walks you through setting up Twilio as the telephony provider for your AI Voice Assistant.

## Prerequisites

- Twilio account (sign up at [twilio.com](https://www.twilio.com))
- Payment method added (required for UK phone numbers)
- Vapi.ai account (you'll need the SIP endpoint)

---

## Step 1: Purchase a London Phone Number

### 1.1 Navigate to Phone Numbers

1. Log into [Twilio Console](https://console.twilio.com)
2. Go to **Phone Numbers** → **Manage** → **Buy a Number**

### 1.2 Search for a London Number

1. Country: **United Kingdom**
2. Search by: **Location**
3. Location: **London** (or search for "020")
4. Capabilities: ✅ Voice

### 1.3 Choose Your Number

For a professional appearance, prioritize:
- **020 8XXX XXXX** - Outer London (Hampstead area)
- **020 7XXX XXXX** - Central London (prestigious)

Click **Buy** on your chosen number.

> **Cost**: ~£1/month + usage charges (~1p/minute inbound)

---

## Step 2: Configure the Phone Number

### 2.1 Access Number Configuration

1. Go to **Phone Numbers** → **Manage** → **Active Numbers**
2. Click on your newly purchased number

### 2.2 Voice Configuration

Under **Voice Configuration**, set:

| Setting | Value |
|---------|-------|
| **Configure with** | Webhook |
| **A call comes in** | Webhook |
| **URL** | `https://api.vapi.ai/twilio/inbound_call` |
| **HTTP Method** | POST |

### 2.3 Alternative: SIP Trunk Setup (Recommended)

For lowest latency, use SIP trunking:

1. Go to **Elastic SIP Trunking** → **Trunks**
2. Click **Create new SIP Trunk**
3. Name: `Hampstead-Vapi-Trunk`
4. Under **Origination**:
   - Add Origination SIP URI: `sip:YOUR_VAPI_ENDPOINT@sip.vapi.ai`
5. Under **Termination**:
   - Create Termination SIP URI
6. Go back to your phone number and configure:
   - **Configure with**: SIP Trunk
   - **SIP Trunk**: Select `Hampstead-Vapi-Trunk`

---

## Step 3: Get Your Credentials

### 3.1 Account Credentials

1. Go to **Account** → **API keys & tokens**
2. Note your:
   - **Account SID**: `AC...`
   - **Auth Token**: `...`

### 3.2 Add to Environment

Update your `config/.env`:

```env
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_PHONE_NUMBER=+442081234567
```

---

## Step 4: Test the Configuration

### 4.1 Make a Test Call

1. Call your Twilio number from any phone
2. You should hear Sarah answer: "Good morning/afternoon, Hampstead Renovations..."

### 4.2 Check Twilio Logs

1. Go to **Monitor** → **Logs** → **Calls**
2. Verify your test call appears
3. Check status is "Completed"

### 4.3 Troubleshoot Common Issues

| Issue | Solution |
|-------|----------|
| Call doesn't connect | Verify webhook URL is correct |
| "Application error" | Check Vapi assistant is published |
| One-way audio | Ensure SIP trunk is configured correctly |
| High latency | Switch to SIP trunking |

---

## Step 5: Geographic Permissions

Ensure UK calling is enabled:

1. Go to **Voice** → **Settings** → **Geo Permissions**
2. Verify **United Kingdom** is enabled for inbound

---

## Step 6: Caller ID Setup (Optional)

To display a friendly caller ID when Ross calls back:

1. Go to **Phone Numbers** → **Manage** → **Verified Caller IDs**
2. Add your Twilio number as a verified caller ID
3. This allows outbound calls to show your London number

---

## Cost Optimization Tips

1. **Use Pay-As-You-Go**: No monthly commitment beyond number rental
2. **Monitor Usage**: Set up billing alerts at £50, £100, £200
3. **Volume Discounts**: Available at 10,000+ minutes/month
4. **Reserved Pricing**: Consider if consistent high volume

### Expected Costs

| Item | Cost |
|------|------|
| London Number | £1.00/month |
| Inbound Calls | £0.0085/minute |
| Average 3-min Call | £0.03 |

---

## Security Best Practices

1. **Rotate Auth Token** quarterly
2. **Use API Keys** instead of Auth Token for production
3. **Enable 2FA** on your Twilio account
4. **Set Geographic Permissions** to UK only (unless needed elsewhere)
5. **Monitor for fraud**: Set up usage triggers and alerts

---

## Next Steps

- [ ] Complete [VAPI_SETUP.md](./VAPI_SETUP.md) to configure the AI assistant
- [ ] Complete [MAKE_SETUP.md](./MAKE_SETUP.md) to set up notifications
- [ ] Run the test checklist

---

*For Twilio support: [support.twilio.com](https://support.twilio.com)*
