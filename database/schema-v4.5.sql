-- =====================================================
-- HAMPSTEAD CONCIERGE v4.5 QUALITY SCHEMA
-- Supabase PostgreSQL Database
-- Quality-focused with enhanced tracking columns
-- =====================================================

-- ===== EXTENSIONS =====
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ===== LEADS TABLE (Enhanced for Quality Tracking) =====
CREATE TABLE IF NOT EXISTS public.leads (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Caller Information
    caller_name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    phone_confirmed BOOLEAN NOT NULL DEFAULT FALSE,  -- NEW: Critical for callback success
    address TEXT,
    postcode TEXT,
    area_name TEXT,
    
    -- Project Information
    category TEXT NOT NULL CHECK (category IN ('Renovation', 'Maintenance', 'Emergency', 'Other')),
    project_type TEXT,
    summary TEXT NOT NULL,
    notes TEXT,
    estimated_value TEXT,
    timeline TEXT,
    
    -- Quality Metrics (NEW)
    caller_emotion TEXT CHECK (caller_emotion IN ('Excited', 'Positive', 'Neutral', 'Concerned', 'Stressed', 'Frustrated')),
    call_quality TEXT CHECK (call_quality IN ('Excellent', 'Good', 'Adequate', 'Difficult')),
    quality_warning TEXT,  -- Any data quality issues
    data_completeness DECIMAL(3,2) DEFAULT 0.00,  -- 0.00 to 1.00
    
    -- Lead Scoring (Enhanced)
    sentiment TEXT CHECK (sentiment IN ('High Value', 'Standard', 'Urgent')),
    lead_score_vapi INTEGER CHECK (lead_score_vapi >= 1 AND lead_score_vapi <= 10),  -- From Vapi 1-10
    quality_score INTEGER CHECK (quality_score >= 0 AND quality_score <= 100),  -- Calculated 0-100
    score_breakdown JSONB,  -- Detailed breakdown of score calculation
    lead_temperature TEXT CHECK (lead_temperature IN ('hot', 'warm', 'cool')),
    
    -- Client Status
    is_returning_client BOOLEAN DEFAULT FALSE,
    previous_enquiries INTEGER DEFAULT 0,
    
    -- Priority & Routing
    priority_label TEXT,
    recommended_callback TEXT,
    
    -- Status Tracking
    status TEXT DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'qualified', 'quoted', 'won', 'lost', 'spam')),
    contacted_at TIMESTAMPTZ,
    callback_count INTEGER DEFAULT 0,
    last_callback_attempt TIMESTAMPTZ,
    
    -- Outcome Tracking
    outcome TEXT,
    outcome_notes TEXT,
    quote_amount DECIMAL(10,2),
    won_amount DECIMAL(10,2),
    
    -- Call Recording
    call_id TEXT UNIQUE,
    recording_url TEXT,
    call_duration_seconds INTEGER,
    transcript_url TEXT,
    
    -- Analysis Scores
    call_quality_score INTEGER CHECK (call_quality_score >= 1 AND call_quality_score <= 10),  -- From Vapi analysis
    empathy_score INTEGER CHECK (empathy_score >= 1 AND empathy_score <= 10),  -- From Vapi analysis
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- System
    source TEXT DEFAULT 'vapi',
    version TEXT DEFAULT '4.5'
);

-- ===== CLIENTS TABLE (Returning Client Recognition) =====
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
    callback_preferences TEXT,
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== CALL LOG TABLE (Quality Tracking) =====
CREATE TABLE IF NOT EXISTS public.call_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID REFERENCES public.leads(id),
    
    -- Call Details
    call_id TEXT,
    phone_number TEXT NOT NULL,
    call_direction TEXT DEFAULT 'inbound',
    call_duration_seconds INTEGER,
    recording_url TEXT,
    
    -- Quality Metrics
    phone_confirmed BOOLEAN DEFAULT FALSE,
    data_completeness DECIMAL(3,2),
    caller_emotion TEXT,
    call_quality TEXT,
    
    -- Analysis
    call_quality_score INTEGER,
    empathy_score INTEGER,
    
    -- Outcome
    outcome TEXT CHECK (outcome IN ('lead_captured', 'spam', 'wrong_number', 'disconnected', 'transferred', 'callback_requested')),
    
    -- Timestamps
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);

-- ===== QUALITY METRICS TABLE (Daily Aggregates) =====
CREATE TABLE IF NOT EXISTS public.quality_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE UNIQUE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Volume
    total_calls INTEGER DEFAULT 0,
    total_leads INTEGER DEFAULT 0,
    
    -- Quality Metrics
    phone_confirmation_rate DECIMAL(3,2),  -- 0.00 to 1.00
    avg_data_completeness DECIMAL(3,2),
    avg_call_quality_score DECIMAL(3,1),
    avg_empathy_score DECIMAL(3,1),
    avg_quality_score DECIMAL(4,1),  -- 0-100
    
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
    
    -- Issues
    unconfirmed_phones INTEGER DEFAULT 0,
    missing_addresses INTEGER DEFAULT 0,
    difficult_calls INTEGER DEFAULT 0,
    
    -- Spam
    spam_calls INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

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

-- ===== INDEXES FOR PERFORMANCE =====

-- Leads indexes
CREATE INDEX IF NOT EXISTS idx_leads_phone ON public.leads(phone_number);
CREATE INDEX IF NOT EXISTS idx_leads_phone_confirmed ON public.leads(phone_confirmed);
CREATE INDEX IF NOT EXISTS idx_leads_quality_score ON public.leads(quality_score DESC);
CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_created ON public.leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_postcode ON public.leads(postcode);
CREATE INDEX IF NOT EXISTS idx_leads_caller_emotion ON public.leads(caller_emotion);
CREATE INDEX IF NOT EXISTS idx_leads_call_id ON public.leads(call_id);
CREATE INDEX IF NOT EXISTS idx_leads_temperature ON public.leads(lead_temperature);

-- Full-text search on summary
CREATE INDEX IF NOT EXISTS idx_leads_summary_gin ON public.leads USING gin(to_tsvector('english', summary));

-- Clients indexes
CREATE INDEX IF NOT EXISTS idx_clients_phone ON public.clients(phone_number);
CREATE INDEX IF NOT EXISTS idx_clients_tier ON public.clients(client_tier);

-- Quality metrics index
CREATE INDEX IF NOT EXISTS idx_quality_metrics_date ON public.quality_metrics(date DESC);

-- ===== FUNCTIONS =====

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
    max_score DECIMAL := 10;
BEGIN
    -- Required fields (already have)
    IF lead_row.caller_name IS NOT NULL THEN score := score + 1; END IF;
    IF lead_row.phone_number IS NOT NULL THEN score := score + 1; END IF;
    IF lead_row.category IS NOT NULL THEN score := score + 1; END IF;
    IF lead_row.summary IS NOT NULL THEN score := score + 1; END IF;
    
    -- Quality bonus
    IF lead_row.phone_confirmed THEN score := score + 1.5; END IF;
    
    -- Optional fields
    IF lead_row.address IS NOT NULL AND lead_row.address != '' THEN score := score + 1; END IF;
    IF lead_row.postcode IS NOT NULL AND lead_row.postcode != '' THEN score := score + 1; END IF;
    IF lead_row.timeline IS NOT NULL THEN score := score + 0.5; END IF;
    IF lead_row.estimated_value IS NOT NULL THEN score := score + 0.5; END IF;
    IF lead_row.notes IS NOT NULL AND lead_row.notes != '' THEN score := score + 0.5; END IF;
    IF lead_row.project_type IS NOT NULL THEN score := score + 0.5; END IF;
    IF lead_row.caller_emotion IS NOT NULL THEN score := score + 0.5; END IF;
    
    RETURN ROUND(score / max_score, 2);
END;
$$ LANGUAGE plpgsql;

-- Calculate lead temperature from quality score
CREATE OR REPLACE FUNCTION calculate_lead_temperature(quality_score INTEGER)
RETURNS TEXT AS $$
BEGIN
    IF quality_score >= 70 THEN RETURN 'hot';
    ELSIF quality_score >= 40 THEN RETURN 'warm';
    ELSE RETURN 'cool';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Auto-calculate completeness and temperature on insert/update
CREATE OR REPLACE FUNCTION auto_calculate_quality()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_completeness := calculate_data_completeness(NEW);
    IF NEW.quality_score IS NOT NULL THEN
        NEW.lead_temperature := calculate_lead_temperature(NEW.quality_score);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update daily quality metrics
CREATE OR REPLACE FUNCTION update_daily_quality_metrics()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.quality_metrics (date)
    VALUES (CURRENT_DATE)
    ON CONFLICT (date) DO NOTHING;
    
    UPDATE public.quality_metrics
    SET 
        total_calls = total_calls + 1,
        total_leads = CASE WHEN NEW.status != 'spam' THEN total_leads + 1 ELSE total_leads END,
        unconfirmed_phones = CASE WHEN NOT NEW.phone_confirmed THEN unconfirmed_phones + 1 ELSE unconfirmed_phones END,
        spam_calls = CASE WHEN NEW.status = 'spam' THEN spam_calls + 1 ELSE spam_calls END,
        hot_leads = CASE WHEN NEW.lead_temperature = 'hot' THEN hot_leads + 1 ELSE hot_leads END,
        warm_leads = CASE WHEN NEW.lead_temperature = 'warm' THEN warm_leads + 1 ELSE warm_leads END,
        cool_leads = CASE WHEN NEW.lead_temperature = 'cool' THEN cool_leads + 1 ELSE cool_leads END,
        emotion_excited = CASE WHEN NEW.caller_emotion = 'Excited' THEN emotion_excited + 1 ELSE emotion_excited END,
        emotion_positive = CASE WHEN NEW.caller_emotion = 'Positive' THEN emotion_positive + 1 ELSE emotion_positive END,
        emotion_neutral = CASE WHEN NEW.caller_emotion = 'Neutral' THEN emotion_neutral + 1 ELSE emotion_neutral END,
        emotion_concerned = CASE WHEN NEW.caller_emotion = 'Concerned' THEN emotion_concerned + 1 ELSE emotion_concerned END,
        emotion_stressed = CASE WHEN NEW.caller_emotion = 'Stressed' THEN emotion_stressed + 1 ELSE emotion_stressed END,
        emotion_frustrated = CASE WHEN NEW.caller_emotion = 'Frustrated' THEN emotion_frustrated + 1 ELSE emotion_frustrated END,
        difficult_calls = CASE WHEN NEW.call_quality = 'Difficult' THEN difficult_calls + 1 ELSE difficult_calls END
    WHERE date = CURRENT_DATE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Client lookup by phone (for returning client recognition)
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

-- Auto quality calculation trigger
DROP TRIGGER IF EXISTS trigger_leads_quality ON public.leads;
CREATE TRIGGER trigger_leads_quality
    BEFORE INSERT OR UPDATE ON public.leads
    FOR EACH ROW
    EXECUTE FUNCTION auto_calculate_quality();

-- Daily metrics update trigger
DROP TRIGGER IF EXISTS trigger_leads_daily_metrics ON public.leads;
CREATE TRIGGER trigger_leads_daily_metrics
    AFTER INSERT ON public.leads
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_quality_metrics();

-- ===== ROW LEVEL SECURITY =====
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quality_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spam_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_numbers ENABLE ROW LEVEL SECURITY;

-- Service role has full access
CREATE POLICY "Service role full access" ON public.leads FOR ALL USING (true);
CREATE POLICY "Service role full access" ON public.clients FOR ALL USING (true);
CREATE POLICY "Service role full access" ON public.call_log FOR ALL USING (true);
CREATE POLICY "Service role full access" ON public.quality_metrics FOR ALL USING (true);
CREATE POLICY "Service role full access" ON public.spam_log FOR ALL USING (true);
CREATE POLICY "Service role full access" ON public.blocked_numbers FOR ALL USING (true);

-- ===== QUALITY VIEWS =====

-- Daily quality dashboard
CREATE OR REPLACE VIEW public.v_quality_dashboard AS
SELECT 
    date,
    total_calls,
    total_leads,
    ROUND(phone_confirmation_rate * 100, 1) AS phone_confirmation_pct,
    ROUND(avg_data_completeness * 100, 1) AS data_completeness_pct,
    ROUND(avg_call_quality_score, 1) AS avg_call_quality,
    ROUND(avg_empathy_score, 1) AS avg_empathy,
    ROUND(avg_quality_score, 1) AS avg_lead_score,
    hot_leads,
    warm_leads,
    cool_leads,
    unconfirmed_phones,
    difficult_calls,
    spam_calls,
    -- Calculated ratios
    CASE WHEN total_leads > 0 
        THEN ROUND(hot_leads::DECIMAL / total_leads * 100, 1) 
        ELSE 0 END AS hot_lead_pct
FROM public.quality_metrics
ORDER BY date DESC;

-- Lead quality summary
CREATE OR REPLACE VIEW public.v_lead_quality_summary AS
SELECT 
    lead_temperature,
    COUNT(*) AS count,
    ROUND(AVG(quality_score), 1) AS avg_score,
    ROUND(AVG(data_completeness) * 100, 1) AS avg_completeness_pct,
    ROUND(SUM(CASE WHEN phone_confirmed THEN 1 ELSE 0 END)::DECIMAL / COUNT(*) * 100, 1) AS phone_confirmed_pct,
    ROUND(SUM(CASE WHEN status = 'won' THEN 1 ELSE 0 END)::DECIMAL / NULLIF(COUNT(*), 0) * 100, 1) AS conversion_rate
FROM public.leads
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY lead_temperature
ORDER BY avg_score DESC;

-- ===== VERSION MARKER =====
COMMENT ON TABLE public.leads IS 'Hampstead Concierge Leads v4.5 QUALITY - Quality-focused with phone confirmation, emotion tracking, and comprehensive quality metrics';
