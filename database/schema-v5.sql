-- =====================================================
-- HAMPSTEAD CONCIERGE v5.0 COMPLETE SCHEMA
-- Supabase PostgreSQL Database
-- Full-featured with SMS, appointments, analytics, UK compliance
-- =====================================================

-- ===== EXTENSIONS =====
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- ===== LEADS TABLE (Complete) =====
CREATE TABLE IF NOT EXISTS public.leads (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Caller Information
    caller_name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    phone_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    phone_type TEXT CHECK (phone_type IN ('mobile', 'landline', 'unknown')) DEFAULT 'unknown',
    email TEXT,
    address TEXT,
    postcode TEXT,
    area_name TEXT,
    
    -- Project Information
    category TEXT NOT NULL CHECK (category IN ('Renovation', 'Maintenance', 'Emergency', 'Enquiry', 'Other')),
    project_type TEXT,
    summary TEXT NOT NULL,
    notes TEXT,
    estimated_value TEXT,
    timeline TEXT,
    
    -- Quality Metrics
    caller_emotion TEXT CHECK (caller_emotion IN ('Excited', 'Positive', 'Neutral', 'Concerned', 'Stressed', 'Frustrated')),
    call_quality TEXT CHECK (call_quality IN ('Excellent', 'Good', 'Adequate', 'Difficult')),
    quality_warning TEXT,
    data_completeness DECIMAL(3,2) DEFAULT 0.00,
    
    -- Lead Scoring
    sentiment TEXT CHECK (sentiment IN ('High Value', 'Standard', 'Urgent')),
    lead_score_vapi INTEGER CHECK (lead_score_vapi >= 1 AND lead_score_vapi <= 10),
    quality_score INTEGER CHECK (quality_score >= 0 AND quality_score <= 100),
    score_breakdown JSONB,
    lead_temperature TEXT CHECK (lead_temperature IN ('hot', 'warm', 'cool')),
    
    -- Client Status
    is_returning_client BOOLEAN DEFAULT FALSE,
    client_id UUID REFERENCES public.clients(id),
    previous_enquiries INTEGER DEFAULT 0,
    
    -- Time & Hours
    is_after_hours BOOLEAN DEFAULT FALSE,
    call_time TIME,
    call_date DATE DEFAULT CURRENT_DATE,
    call_weekday INTEGER,
    is_bank_holiday BOOLEAN DEFAULT FALSE,
    
    -- Communication Preferences
    sms_consent BOOLEAN DEFAULT FALSE,
    sms_sent BOOLEAN DEFAULT FALSE,
    sms_sent_at TIMESTAMPTZ,
    preferred_callback_time TEXT,
    language_detected TEXT DEFAULT 'en-GB',
    
    -- Appointment
    appointment_interest BOOLEAN DEFAULT FALSE,
    appointment_booked BOOLEAN DEFAULT FALSE,
    appointment_date DATE,
    appointment_time TIME,
    appointment_reminder_sent BOOLEAN DEFAULT FALSE,
    
    -- Priority & Routing
    priority_label TEXT,
    recommended_callback TEXT,
    
    -- Status Tracking
    status TEXT DEFAULT 'new' CHECK (status IN (
        'new', 'calling', 'contacted', 'no_answer', 'voicemail', 
        'qualified', 'appointment_booked', 'quoted', 'quote_followup_sent',
        'won', 'lost', 'declined', 'spam'
    )),
    contacted_at TIMESTAMPTZ,
    callback_attempts INTEGER DEFAULT 0,
    last_callback_attempt TIMESTAMPTZ,
    
    -- Outcome Tracking
    outcome TEXT,
    outcome_notes TEXT,
    quote_amount DECIMAL(10,2),
    quote_sent_at TIMESTAMPTZ,
    quote_followup_sent BOOLEAN DEFAULT FALSE,
    quote_followup_at TIMESTAMPTZ,
    won_amount DECIMAL(10,2),
    won_at TIMESTAMPTZ,
    lost_reason TEXT,
    
    -- Call Recording
    call_id TEXT UNIQUE,
    recording_url TEXT,
    call_duration_seconds INTEGER,
    transcript_url TEXT,
    
    -- Analysis Scores
    call_quality_score INTEGER CHECK (call_quality_score >= 1 AND call_quality_score <= 10),
    empathy_score INTEGER CHECK (empathy_score >= 1 AND empathy_score <= 10),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- System
    source TEXT DEFAULT 'vapi',
    version TEXT DEFAULT '5.0'
);

-- ===== CLIENTS TABLE =====
CREATE TABLE IF NOT EXISTS public.clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Contact Information
    name TEXT NOT NULL,
    phone_number TEXT UNIQUE NOT NULL,
    email TEXT,
    
    -- Address History
    addresses JSONB DEFAULT '[]'::jsonb,
    primary_address TEXT,
    primary_postcode TEXT,
    
    -- Engagement Metrics
    total_enquiries INTEGER DEFAULT 1,
    total_projects INTEGER DEFAULT 0,
    total_value DECIMAL(12,2) DEFAULT 0,
    
    -- Relationship
    first_contact TIMESTAMPTZ DEFAULT NOW(),
    last_contact TIMESTAMPTZ DEFAULT NOW(),
    is_active_client BOOLEAN DEFAULT FALSE,
    client_tier TEXT DEFAULT 'standard' CHECK (client_tier IN ('vip', 'preferred', 'standard', 'new')),
    
    -- Preferences
    preferred_contact_method TEXT DEFAULT 'phone',
    preferred_language TEXT DEFAULT 'en-GB',
    sms_opted_out BOOLEAN DEFAULT FALSE,
    callback_preferences TEXT,
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== APPOINTMENTS TABLE =====
CREATE TABLE IF NOT EXISTS public.appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID REFERENCES public.leads(id),
    client_id UUID REFERENCES public.clients(id),
    
    -- Appointment Details
    appointment_type TEXT DEFAULT 'site_visit' CHECK (appointment_type IN ('site_visit', 'quote_review', 'follow_up', 'other')),
    title TEXT NOT NULL,
    address TEXT NOT NULL,
    postcode TEXT,
    
    -- Scheduling
    scheduled_date DATE NOT NULL,
    scheduled_time TIME NOT NULL,
    duration_minutes INTEGER DEFAULT 60,
    travel_time_minutes INTEGER DEFAULT 0,
    
    -- Google Calendar
    google_event_id TEXT,
    calendar_synced BOOLEAN DEFAULT FALSE,
    
    -- Status
    status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'completed', 'cancelled', 'rescheduled', 'no_show')),
    
    -- Reminders
    reminder_24h_sent BOOLEAN DEFAULT FALSE,
    reminder_24h_at TIMESTAMPTZ,
    reminder_1h_sent BOOLEAN DEFAULT FALSE,
    reminder_1h_at TIMESTAMPTZ,
    
    -- Notes
    notes TEXT,
    outcome_notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    cancelled_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- ===== SMS LOG TABLE =====
CREATE TABLE IF NOT EXISTS public.sms_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID REFERENCES public.leads(id),
    
    -- Message Details
    to_number TEXT NOT NULL,
    from_sender TEXT DEFAULT 'Hampstead',
    template_used TEXT,
    message_body TEXT NOT NULL,
    
    -- Status
    status TEXT DEFAULT 'sent' CHECK (status IN ('queued', 'sent', 'delivered', 'failed', 'undelivered')),
    twilio_sid TEXT,
    error_code TEXT,
    error_message TEXT,
    
    -- Timestamps
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    
    -- Cost (in pence)
    cost_pence INTEGER
);

-- ===== WHATSAPP INTERACTIONS TABLE =====
CREATE TABLE IF NOT EXISTS public.whatsapp_interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID REFERENCES public.leads(id),
    
    -- Message Details
    direction TEXT CHECK (direction IN ('outbound', 'inbound')),
    message_type TEXT CHECK (message_type IN ('text', 'interactive', 'button_reply')),
    message_body TEXT,
    
    -- Interactive Buttons
    buttons_sent JSONB,
    button_clicked TEXT,
    button_clicked_at TIMESTAMPTZ,
    
    -- Status
    status TEXT DEFAULT 'sent',
    twilio_sid TEXT,
    
    -- Timestamps
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

-- ===== DAILY ANALYTICS TABLE =====
CREATE TABLE IF NOT EXISTS public.daily_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE UNIQUE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Volume
    total_calls INTEGER DEFAULT 0,
    total_leads INTEGER DEFAULT 0,
    business_hours_calls INTEGER DEFAULT 0,
    after_hours_calls INTEGER DEFAULT 0,
    
    -- Quality Metrics
    phone_confirmation_rate DECIMAL(5,4),
    avg_data_completeness DECIMAL(5,4),
    avg_call_quality_score DECIMAL(4,2),
    avg_empathy_score DECIMAL(4,2),
    avg_quality_score DECIMAL(5,2),
    
    -- SMS Metrics
    sms_consent_rate DECIMAL(5,4),
    sms_sent_count INTEGER DEFAULT 0,
    sms_delivered_count INTEGER DEFAULT 0,
    
    -- Appointment Metrics
    appointments_booked INTEGER DEFAULT 0,
    appointments_completed INTEGER DEFAULT 0,
    appointments_cancelled INTEGER DEFAULT 0,
    
    -- Emotion Distribution
    emotion_excited INTEGER DEFAULT 0,
    emotion_positive INTEGER DEFAULT 0,
    emotion_neutral INTEGER DEFAULT 0,
    emotion_concerned INTEGER DEFAULT 0,
    emotion_stressed INTEGER DEFAULT 0,
    emotion_frustrated INTEGER DEFAULT 0,
    
    -- Lead Quality
    hot_leads INTEGER DEFAULT 0,
    warm_leads INTEGER DEFAULT 0,
    cool_leads INTEGER DEFAULT 0,
    
    -- Categories
    renovation_leads INTEGER DEFAULT 0,
    maintenance_leads INTEGER DEFAULT 0,
    emergency_leads INTEGER DEFAULT 0,
    
    -- Languages
    english_calls INTEGER DEFAULT 0,
    non_english_calls INTEGER DEFAULT 0,
    
    -- Conversion
    leads_contacted INTEGER DEFAULT 0,
    leads_qualified INTEGER DEFAULT 0,
    quotes_sent INTEGER DEFAULT 0,
    jobs_won INTEGER DEFAULT 0,
    total_value_won DECIMAL(12,2) DEFAULT 0,
    
    -- Issues
    spam_calls INTEGER DEFAULT 0,
    difficult_calls INTEGER DEFAULT 0,
    unconfirmed_phones INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== UK BANK HOLIDAYS TABLE =====
CREATE TABLE IF NOT EXISTS public.uk_bank_holidays (
    date DATE PRIMARY KEY,
    name TEXT NOT NULL,
    region TEXT DEFAULT 'england-wales' CHECK (region IN ('england-wales', 'scotland', 'northern-ireland', 'all'))
);

-- Insert 2025-2026 bank holidays
INSERT INTO public.uk_bank_holidays (date, name, region) VALUES
    ('2025-01-01', 'New Year''s Day', 'all'),
    ('2025-04-18', 'Good Friday', 'all'),
    ('2025-04-21', 'Easter Monday', 'england-wales'),
    ('2025-05-05', 'Early May bank holiday', 'all'),
    ('2025-05-26', 'Spring bank holiday', 'all'),
    ('2025-08-25', 'Summer bank holiday', 'england-wales'),
    ('2025-12-25', 'Christmas Day', 'all'),
    ('2025-12-26', 'Boxing Day', 'all'),
    ('2026-01-01', 'New Year''s Day', 'all'),
    ('2026-04-03', 'Good Friday', 'all'),
    ('2026-04-06', 'Easter Monday', 'england-wales'),
    ('2026-05-04', 'Early May bank holiday', 'all'),
    ('2026-05-25', 'Spring bank holiday', 'all'),
    ('2026-08-31', 'Summer bank holiday', 'england-wales'),
    ('2026-12-25', 'Christmas Day', 'all'),
    ('2026-12-28', 'Boxing Day (substitute)', 'all')
ON CONFLICT (date) DO NOTHING;

-- ===== SPAM LOG TABLE =====
CREATE TABLE IF NOT EXISTS public.spam_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number TEXT,
    caller_name TEXT,
    company_name TEXT,
    spam_type TEXT,
    summary TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== BLOCKED NUMBERS TABLE =====
CREATE TABLE IF NOT EXISTS public.blocked_numbers (
    phone_number TEXT PRIMARY KEY,
    reason TEXT,
    blocked_at TIMESTAMPTZ DEFAULT NOW(),
    auto_blocked BOOLEAN DEFAULT TRUE
);

-- ===== FOLLOW UP QUEUE TABLE =====
CREATE TABLE IF NOT EXISTS public.followup_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID REFERENCES public.leads(id),
    
    -- Follow-up Details
    followup_type TEXT CHECK (followup_type IN ('callback', 'quote_followup', 'cold_reengagement', 'appointment_reminder')),
    scheduled_for TIMESTAMPTZ NOT NULL,
    
    -- Status
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled', 'failed')),
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    
    -- Result
    completed_at TIMESTAMPTZ,
    result TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== INDEXES =====

-- Leads indexes
CREATE INDEX IF NOT EXISTS idx_leads_phone ON public.leads(phone_number);
CREATE INDEX IF NOT EXISTS idx_leads_phone_confirmed ON public.leads(phone_confirmed);
CREATE INDEX IF NOT EXISTS idx_leads_quality_score ON public.leads(quality_score DESC);
CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_created ON public.leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_postcode ON public.leads(postcode);
CREATE INDEX IF NOT EXISTS idx_leads_after_hours ON public.leads(is_after_hours);
CREATE INDEX IF NOT EXISTS idx_leads_sms_consent ON public.leads(sms_consent);
CREATE INDEX IF NOT EXISTS idx_leads_appointment ON public.leads(appointment_booked);
CREATE INDEX IF NOT EXISTS idx_leads_call_date ON public.leads(call_date DESC);

-- Appointments indexes
CREATE INDEX IF NOT EXISTS idx_appointments_date ON public.appointments(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON public.appointments(status);
CREATE INDEX IF NOT EXISTS idx_appointments_reminder ON public.appointments(reminder_24h_sent) WHERE reminder_24h_sent = FALSE;

-- SMS log indexes
CREATE INDEX IF NOT EXISTS idx_sms_lead ON public.sms_log(lead_id);
CREATE INDEX IF NOT EXISTS idx_sms_status ON public.sms_log(status);

-- Follow-up queue indexes
CREATE INDEX IF NOT EXISTS idx_followup_scheduled ON public.followup_queue(scheduled_for) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_followup_lead ON public.followup_queue(lead_id);

-- Full-text search
CREATE INDEX IF NOT EXISTS idx_leads_summary_gin ON public.leads USING gin(to_tsvector('english', summary));

-- ===== FUNCTIONS =====

-- Check if date is UK bank holiday
CREATE OR REPLACE FUNCTION is_uk_bank_holiday(check_date DATE)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM public.uk_bank_holidays WHERE date = check_date);
END;
$$ LANGUAGE plpgsql;

-- Check if within UK business hours
CREATE OR REPLACE FUNCTION is_business_hours(check_time TIMESTAMPTZ DEFAULT NOW())
RETURNS BOOLEAN AS $$
DECLARE
    uk_time TIME;
    uk_weekday INTEGER;
    uk_date DATE;
BEGIN
    uk_time := (check_time AT TIME ZONE 'Europe/London')::TIME;
    uk_weekday := EXTRACT(DOW FROM check_time AT TIME ZONE 'Europe/London');
    uk_date := (check_time AT TIME ZONE 'Europe/London')::DATE;
    
    -- Check bank holidays
    IF is_uk_bank_holiday(uk_date) THEN
        RETURN FALSE;
    END IF;
    
    -- Sunday (0) = closed
    IF uk_weekday = 0 THEN
        RETURN FALSE;
    END IF;
    
    -- Saturday (6) = 9am-2pm
    IF uk_weekday = 6 THEN
        RETURN uk_time >= '09:00' AND uk_time < '14:00';
    END IF;
    
    -- Monday-Friday = 8am-6pm
    RETURN uk_time >= '08:00' AND uk_time < '18:00';
END;
$$ LANGUAGE plpgsql;

-- Get next business day
CREATE OR REPLACE FUNCTION next_business_day(from_date DATE DEFAULT CURRENT_DATE)
RETURNS DATE AS $$
DECLARE
    next_day DATE := from_date + 1;
BEGIN
    WHILE EXTRACT(DOW FROM next_day) IN (0, 6) OR is_uk_bank_holiday(next_day) LOOP
        next_day := next_day + 1;
    END LOOP;
    RETURN next_day;
END;
$$ LANGUAGE plpgsql;

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Calculate data completeness
CREATE OR REPLACE FUNCTION calculate_data_completeness(lead_row public.leads)
RETURNS DECIMAL AS $$
DECLARE
    score DECIMAL := 0;
    max_score DECIMAL := 12;
BEGIN
    IF lead_row.caller_name IS NOT NULL AND lead_row.caller_name != '' THEN score := score + 1; END IF;
    IF lead_row.phone_number IS NOT NULL THEN score := score + 1; END IF;
    IF lead_row.phone_confirmed THEN score := score + 2; END IF;
    IF lead_row.category IS NOT NULL THEN score := score + 1; END IF;
    IF lead_row.summary IS NOT NULL AND lead_row.summary != '' THEN score := score + 1; END IF;
    IF lead_row.address IS NOT NULL AND lead_row.address != '' THEN score := score + 1; END IF;
    IF lead_row.postcode IS NOT NULL AND lead_row.postcode != '' THEN score := score + 1; END IF;
    IF lead_row.project_type IS NOT NULL THEN score := score + 1; END IF;
    IF lead_row.timeline IS NOT NULL THEN score := score + 0.5; END IF;
    IF lead_row.estimated_value IS NOT NULL THEN score := score + 0.5; END IF;
    IF lead_row.notes IS NOT NULL AND lead_row.notes != '' THEN score := score + 0.5; END IF;
    IF lead_row.caller_emotion IS NOT NULL THEN score := score + 0.5; END IF;
    
    RETURN ROUND(score / max_score, 2);
END;
$$ LANGUAGE plpgsql;

-- Auto-calculate completeness and time flags on insert/update
CREATE OR REPLACE FUNCTION auto_enrich_lead()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_completeness := calculate_data_completeness(NEW);
    
    IF NEW.quality_score IS NOT NULL THEN
        IF NEW.quality_score >= 70 THEN
            NEW.lead_temperature := 'hot';
        ELSIF NEW.quality_score >= 40 THEN
            NEW.lead_temperature := 'warm';
        ELSE
            NEW.lead_temperature := 'cool';
        END IF;
    END IF;
    
    -- Set time-related fields
    IF NEW.created_at IS NOT NULL THEN
        NEW.call_time := (NEW.created_at AT TIME ZONE 'Europe/London')::TIME;
        NEW.call_date := (NEW.created_at AT TIME ZONE 'Europe/London')::DATE;
        NEW.call_weekday := EXTRACT(DOW FROM NEW.created_at AT TIME ZONE 'Europe/London');
        NEW.is_after_hours := NOT is_business_hours(NEW.created_at);
        NEW.is_bank_holiday := is_uk_bank_holiday(NEW.call_date);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update daily analytics function
CREATE OR REPLACE FUNCTION update_daily_analytics(target_date DATE DEFAULT CURRENT_DATE)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.daily_analytics (date)
    VALUES (target_date)
    ON CONFLICT (date) DO NOTHING;
    
    UPDATE public.daily_analytics da
    SET 
        total_calls = (SELECT COUNT(*) FROM leads WHERE call_date = target_date),
        total_leads = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND status != 'spam'),
        business_hours_calls = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND is_after_hours = FALSE),
        after_hours_calls = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND is_after_hours = TRUE),
        phone_confirmation_rate = (SELECT AVG(CASE WHEN phone_confirmed THEN 1.0 ELSE 0.0 END) FROM leads WHERE call_date = target_date),
        avg_data_completeness = (SELECT AVG(data_completeness) FROM leads WHERE call_date = target_date),
        avg_quality_score = (SELECT AVG(quality_score) FROM leads WHERE call_date = target_date AND quality_score IS NOT NULL),
        sms_consent_rate = (SELECT AVG(CASE WHEN sms_consent THEN 1.0 ELSE 0.0 END) FROM leads WHERE call_date = target_date),
        sms_sent_count = (SELECT COUNT(*) FROM sms_log WHERE DATE(sent_at AT TIME ZONE 'Europe/London') = target_date),
        hot_leads = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND lead_temperature = 'hot'),
        warm_leads = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND lead_temperature = 'warm'),
        cool_leads = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND lead_temperature = 'cool'),
        renovation_leads = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND category = 'Renovation'),
        maintenance_leads = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND category = 'Maintenance'),
        emergency_leads = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND category = 'Emergency'),
        spam_calls = (SELECT COUNT(*) FROM leads WHERE call_date = target_date AND status = 'spam'),
        updated_at = NOW()
    WHERE da.date = target_date;
END;
$$ LANGUAGE plpgsql;

-- Client lookup by phone
CREATE OR REPLACE FUNCTION lookup_client_by_phone(p_phone TEXT)
RETURNS TABLE (
    id UUID,
    name TEXT,
    phone_number TEXT,
    primary_address TEXT,
    primary_postcode TEXT,
    total_enquiries INTEGER,
    is_returning BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.phone_number,
        c.primary_address,
        c.primary_postcode,
        c.total_enquiries,
        TRUE AS is_returning
    FROM public.clients c
    WHERE c.phone_number = p_phone
       OR c.phone_number = REPLACE(p_phone, '+44', '0')
       OR c.phone_number = '+44' || SUBSTRING(p_phone FROM 2)
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- ===== TRIGGERS =====

-- Updated_at triggers
DROP TRIGGER IF EXISTS trigger_leads_updated ON public.leads;
CREATE TRIGGER trigger_leads_updated
    BEFORE UPDATE ON public.leads
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trigger_clients_updated ON public.clients;
CREATE TRIGGER trigger_clients_updated
    BEFORE UPDATE ON public.clients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trigger_appointments_updated ON public.appointments;
CREATE TRIGGER trigger_appointments_updated
    BEFORE UPDATE ON public.appointments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Auto enrich lead trigger
DROP TRIGGER IF EXISTS trigger_leads_enrich ON public.leads;
CREATE TRIGGER trigger_leads_enrich
    BEFORE INSERT OR UPDATE ON public.leads
    FOR EACH ROW
    EXECUTE FUNCTION auto_enrich_lead();

-- ===== ROW LEVEL SECURITY =====
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sms_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON public.leads FOR ALL USING (true);
CREATE POLICY "Service role full access" ON public.clients FOR ALL USING (true);
CREATE POLICY "Service role full access" ON public.appointments FOR ALL USING (true);
CREATE POLICY "Service role full access" ON public.sms_log FOR ALL USING (true);
CREATE POLICY "Service role full access" ON public.daily_analytics FOR ALL USING (true);

-- ===== VIEWS =====

-- Dashboard overview
CREATE OR REPLACE VIEW public.v_dashboard_overview AS
SELECT 
    date,
    total_calls,
    total_leads,
    business_hours_calls,
    after_hours_calls,
    ROUND(phone_confirmation_rate * 100, 1) AS phone_confirmation_pct,
    ROUND(avg_data_completeness * 100, 1) AS data_completeness_pct,
    ROUND(avg_quality_score, 1) AS avg_lead_score,
    hot_leads,
    warm_leads,
    cool_leads,
    sms_sent_count,
    ROUND(sms_consent_rate * 100, 1) AS sms_consent_pct,
    renovation_leads,
    maintenance_leads,
    emergency_leads,
    spam_calls
FROM public.daily_analytics
ORDER BY date DESC;

-- Today's leads view
CREATE OR REPLACE VIEW public.v_today_leads AS
SELECT 
    l.*,
    c.client_tier,
    c.total_projects AS client_total_projects
FROM public.leads l
LEFT JOIN public.clients c ON l.client_id = c.id
WHERE l.call_date = CURRENT_DATE
ORDER BY l.quality_score DESC NULLS LAST, l.created_at DESC;

-- Pending follow-ups view
CREATE OR REPLACE VIEW public.v_pending_followups AS
SELECT 
    fq.*,
    l.caller_name,
    l.phone_number,
    l.project_type,
    l.quality_score
FROM public.followup_queue fq
JOIN public.leads l ON fq.lead_id = l.id
WHERE fq.status = 'pending'
  AND fq.scheduled_for <= NOW() + INTERVAL '1 hour'
ORDER BY fq.scheduled_for;

-- Upcoming appointments view
CREATE OR REPLACE VIEW public.v_upcoming_appointments AS
SELECT 
    a.*,
    l.caller_name,
    l.phone_number,
    l.project_type,
    l.summary AS project_summary
FROM public.appointments a
LEFT JOIN public.leads l ON a.lead_id = l.id
WHERE a.status IN ('scheduled', 'confirmed')
  AND a.scheduled_date >= CURRENT_DATE
ORDER BY a.scheduled_date, a.scheduled_time;

-- ===== CRON JOBS (requires pg_cron extension) =====

-- Daily analytics update at 23:55 UK time
-- SELECT cron.schedule('update-daily-analytics', '55 23 * * *', 'SELECT update_daily_analytics(CURRENT_DATE)');

-- ===== VERSION MARKER =====
COMMENT ON TABLE public.leads IS 'Hampstead Concierge Leads v5.0 COMPLETE - Full-featured with SMS, appointments, after-hours, multi-language, UK compliance';
