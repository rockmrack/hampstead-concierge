-- ============================================
-- HAMPSTEAD CONCIERGE v4.0 ULTRA
-- Database Schema - Supabase/PostgreSQL
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- LEADS TABLE (Enhanced for v4)
-- ============================================
CREATE TABLE IF NOT EXISTS leads (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Core Contact Info
    caller_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    address TEXT,
    postcode VARCHAR(10),
    
    -- Categorization
    category VARCHAR(20) NOT NULL CHECK (category IN ('Renovation', 'Maintenance', 'Emergency', 'Other')),
    project_type VARCHAR(30),
    summary TEXT,
    sentiment VARCHAR(20),
    
    -- Timeline & Value
    timeline VARCHAR(20),
    estimated_value VARCHAR(20),
    
    -- Lead Scoring (v4 ULTRA)
    ai_lead_score INTEGER CHECK (ai_lead_score BETWEEN 1 AND 10),
    ml_lead_score INTEGER CHECK (ml_lead_score BETWEEN 0 AND 100),
    conversion_probability DECIMAL(3,2) CHECK (conversion_probability BETWEEN 0 AND 1),
    recommended_response VARCHAR(20),
    route_priority VARCHAR(20),
    
    -- Client Status
    returning_client BOOLEAN DEFAULT FALSE,
    
    -- Notes & Details
    notes TEXT,
    
    -- Call Metadata
    call_id VARCHAR(100),
    call_duration INTEGER,
    caller_phone VARCHAR(20),
    
    -- Status Tracking
    status VARCHAR(20) DEFAULT 'new' CHECK (status IN ('new', 'urgent', 'contacted', 'quoted', 'won', 'lost', 'spam')),
    notification_sent BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    contacted_at TIMESTAMPTZ,
    
    -- Data Quality
    data_completeness DECIMAL(3,2) DEFAULT 0,
    
    -- Constraints
    CONSTRAINT unique_call UNIQUE (call_id)
);

-- ============================================
-- CLIENTS TABLE (Returning Client Lookup)
-- ============================================
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Contact Info
    name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(100),
    address TEXT,
    postcode VARCHAR(10),
    
    -- Relationship
    first_contact_date DATE,
    last_contact_date DATE,
    total_calls INTEGER DEFAULT 1,
    total_projects INTEGER DEFAULT 0,
    lifetime_value DECIMAL(10,2) DEFAULT 0,
    
    -- Classification
    client_type VARCHAR(20) DEFAULT 'prospect' CHECK (client_type IN ('prospect', 'one-time', 'repeat', 'vip')),
    preferred_contact VARCHAR(20) DEFAULT 'phone',
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- BLOCKED NUMBERS TABLE (Spam Prevention)
-- ============================================
CREATE TABLE IF NOT EXISTS blocked_numbers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    reason VARCHAR(50),
    spam_type VARCHAR(30),
    company VARCHAR(100),
    blocked_at TIMESTAMPTZ DEFAULT NOW(),
    blocked_by VARCHAR(50) DEFAULT 'system'
);

-- ============================================
-- CALL LOGS TABLE (Analytics)
-- ============================================
CREATE TABLE IF NOT EXISTS call_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Call Info
    call_id VARCHAR(100) NOT NULL UNIQUE,
    caller_phone VARCHAR(20),
    
    -- Timing
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    
    -- Outcome
    outcome VARCHAR(30),
    lead_captured BOOLEAN DEFAULT FALSE,
    lead_id UUID REFERENCES leads(id),
    
    -- Quality Metrics
    first_response_ms INTEGER,
    avg_turn_latency_ms INTEGER,
    data_completeness DECIMAL(3,2),
    ai_success_score INTEGER,
    
    -- Categorization
    category VARCHAR(20),
    is_spam BOOLEAN DEFAULT FALSE,
    
    -- Recording
    recording_url TEXT,
    transcript TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ANALYTICS TABLE (Aggregated Metrics)
-- ============================================
CREATE TABLE IF NOT EXISTS analytics_daily (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE NOT NULL UNIQUE,
    
    -- Volume
    total_calls INTEGER DEFAULT 0,
    total_leads INTEGER DEFAULT 0,
    total_spam INTEGER DEFAULT 0,
    
    -- Categories
    renovation_calls INTEGER DEFAULT 0,
    maintenance_calls INTEGER DEFAULT 0,
    emergency_calls INTEGER DEFAULT 0,
    other_calls INTEGER DEFAULT 0,
    
    -- Quality
    avg_call_duration_s DECIMAL(5,1),
    avg_lead_score DECIMAL(4,1),
    avg_data_completeness DECIMAL(3,2),
    avg_ai_success_score DECIMAL(3,1),
    
    -- Performance
    avg_first_response_ms INTEGER,
    avg_turn_latency_ms INTEGER,
    p95_response_ms INTEGER,
    
    -- Conversion
    leads_contacted INTEGER DEFAULT 0,
    leads_converted INTEGER DEFAULT 0,
    conversion_rate DECIMAL(3,2),
    
    -- Value
    total_estimated_value DECIMAL(12,2),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

-- Leads indexes
CREATE INDEX idx_leads_phone ON leads(phone_number);
CREATE INDEX idx_leads_category ON leads(category);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_ml_score ON leads(ml_lead_score DESC);
CREATE INDEX idx_leads_route ON leads(route_priority);
CREATE INDEX idx_leads_created ON leads(created_at DESC);
CREATE INDEX idx_leads_postcode ON leads(postcode);

-- Clients indexes
CREATE INDEX idx_clients_phone ON clients(phone_number);
CREATE INDEX idx_clients_type ON clients(client_type);

-- Call logs indexes
CREATE INDEX idx_call_logs_call_id ON call_logs(call_id);
CREATE INDEX idx_call_logs_date ON call_logs(started_at DESC);

-- Blocked numbers index
CREATE INDEX idx_blocked_phone ON blocked_numbers(phone_number);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER trigger_leads_updated
    BEFORE UPDATE ON leads
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_clients_updated
    BEFORE UPDATE ON clients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Function to check if number is blocked
CREATE OR REPLACE FUNCTION is_number_blocked(check_phone VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM blocked_numbers WHERE phone_number = check_phone);
END;
$$ LANGUAGE plpgsql;

-- Function to get or create client
CREATE OR REPLACE FUNCTION get_or_create_client(
    p_phone VARCHAR,
    p_name VARCHAR,
    p_address TEXT DEFAULT NULL,
    p_postcode VARCHAR DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_client_id UUID;
BEGIN
    -- Try to find existing client
    SELECT id INTO v_client_id FROM clients WHERE phone_number = p_phone;
    
    IF v_client_id IS NULL THEN
        -- Create new client
        INSERT INTO clients (name, phone_number, address, postcode, first_contact_date, last_contact_date)
        VALUES (p_name, p_phone, p_address, p_postcode, CURRENT_DATE, CURRENT_DATE)
        RETURNING id INTO v_client_id;
    ELSE
        -- Update existing client
        UPDATE clients 
        SET last_contact_date = CURRENT_DATE,
            total_calls = total_calls + 1,
            name = COALESCE(p_name, name),
            address = COALESCE(p_address, address),
            postcode = COALESCE(p_postcode, postcode)
        WHERE id = v_client_id;
    END IF;
    
    RETURN v_client_id;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate ML lead score
CREATE OR REPLACE FUNCTION calculate_ml_score(
    p_ai_score INTEGER,
    p_category VARCHAR,
    p_project_type VARCHAR,
    p_estimated_value VARCHAR,
    p_postcode VARCHAR,
    p_timeline VARCHAR,
    p_sentiment VARCHAR,
    p_returning BOOLEAN
)
RETURNS INTEGER AS $$
DECLARE
    v_score INTEGER := 0;
BEGIN
    -- Base score from AI
    v_score := COALESCE(p_ai_score, 5) * 10;
    
    -- Project type boost
    v_score := v_score + CASE p_project_type
        WHEN 'Extension' THEN 15
        WHEN 'Loft Conversion' THEN 15
        WHEN 'Basement' THEN 15
        WHEN 'Full Refurbishment' THEN 12
        WHEN 'Kitchen' THEN 8
        WHEN 'Bathroom' THEN 6
        ELSE 0
    END;
    
    -- Value boost
    v_score := v_score + CASE p_estimated_value
        WHEN '100k+' THEN 20
        WHEN '50k-100k' THEN 15
        WHEN '20k-50k' THEN 10
        WHEN '5k-20k' THEN 5
        ELSE 0
    END;
    
    -- Postcode boost
    IF p_postcode IN ('NW3', 'NW8') THEN
        v_score := v_score + 10;
    ELSIF p_postcode IN ('NW6', 'NW11') THEN
        v_score := v_score + 5;
    END IF;
    
    -- Urgency boost
    IF p_category = 'Emergency' THEN
        v_score := v_score + 20;
    ELSIF p_timeline = 'ASAP' THEN
        v_score := v_score + 10;
    END IF;
    
    -- Sentiment boost
    v_score := v_score + CASE p_sentiment
        WHEN 'High Value' THEN 10
        WHEN 'Urgent' THEN 5
        ELSE 0
    END;
    
    -- Returning client boost
    IF p_returning THEN
        v_score := v_score + 15;
    END IF;
    
    -- Cap at 100
    RETURN LEAST(v_score, 100);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (Optional)
-- ============================================

-- Enable RLS
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE call_logs ENABLE ROW LEVEL SECURITY;

-- Policies (adjust based on your auth setup)
CREATE POLICY "Service role full access on leads"
    ON leads FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access on clients"
    ON clients FOR ALL
    USING (true)
    WITH CHECK (true);

-- ============================================
-- VIEWS
-- ============================================

-- Hot leads view
CREATE OR REPLACE VIEW hot_leads AS
SELECT 
    l.*,
    c.client_type,
    c.total_projects,
    c.lifetime_value
FROM leads l
LEFT JOIN clients c ON l.phone_number = c.phone_number
WHERE l.ml_lead_score >= 70
AND l.status IN ('new', 'urgent')
ORDER BY l.ml_lead_score DESC, l.created_at DESC;

-- Today's metrics view
CREATE OR REPLACE VIEW today_metrics AS
SELECT
    COUNT(*) as total_calls,
    COUNT(*) FILTER (WHERE category != 'Other' OR status != 'spam') as total_leads,
    COUNT(*) FILTER (WHERE status = 'spam') as spam_calls,
    ROUND(AVG(ml_lead_score), 1) as avg_lead_score,
    ROUND(AVG(call_duration), 1) as avg_call_duration,
    COUNT(*) FILTER (WHERE category = 'Emergency') as emergencies,
    COUNT(*) FILTER (WHERE ml_lead_score >= 70) as hot_leads
FROM leads
WHERE DATE(created_at) = CURRENT_DATE;

-- ============================================
-- SAMPLE DATA (Remove in production)
-- ============================================

-- Uncomment to insert test data
/*
INSERT INTO leads (caller_name, phone_number, category, address, postcode, summary, sentiment, project_type, ai_lead_score, ml_lead_score, status)
VALUES 
    ('James Mitchell', '+447700900001', 'Renovation', '42 Elm Row, NW3', 'NW3', 'Complete loft conversion with ensuite', 'High Value', 'Loft Conversion', 9, 95, 'new'),
    ('Sarah Thompson', '+447700900002', 'Maintenance', '15 Oak Avenue, NW6', 'NW6', 'Boiler replacement needed', 'Standard', 'Boiler', 5, 45, 'new'),
    ('Emergency Test', '+447700900003', 'Emergency', '8 Pine Street, NW8', 'NW8', 'Water leak from upstairs flat', 'Urgent', 'Leak', 8, 85, 'urgent');
*/
