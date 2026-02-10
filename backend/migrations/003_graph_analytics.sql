-- Knowledge Graph Analytics Tables
-- Track user interactions with the knowledge graph for learning optimization

-- 1. Graph Interaction Analytics
CREATE TABLE IF NOT EXISTS graph_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    topic TEXT NOT NULL,
    event_type TEXT NOT NULL, -- 'click', 'expand', 'summary_view', 'summary_generate', 'hover'
    duration_ms INTEGER DEFAULT 0, -- Time spent on this interaction
    metadata JSONB DEFAULT '{}', -- Additional event data
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Index for fast queries
    CONSTRAINT valid_event_type CHECK (event_type IN ('click', 'expand', 'summary_view', 'summary_generate', 'hover', 'navigation'))
);

-- 2. Topic Summaries Cache
CREATE TABLE IF NOT EXISTS topic_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    topic TEXT NOT NULL,
    summary TEXT NOT NULL,
    sources JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint for topic per project
    UNIQUE(project_id, topic)
);

-- 3. Learning Sessions (for tracking session-based analytics)
CREATE TABLE IF NOT EXISTS learning_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    topics_visited TEXT[] DEFAULT '{}',
    total_time_ms INTEGER DEFAULT 0,
    suggestions_shown TEXT[] DEFAULT '{}',
    suggestions_followed TEXT[] DEFAULT '{}'
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_graph_analytics_project ON graph_analytics(project_id);
CREATE INDEX IF NOT EXISTS idx_graph_analytics_user ON graph_analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_graph_analytics_topic ON graph_analytics(topic);
CREATE INDEX IF NOT EXISTS idx_graph_analytics_created ON graph_analytics(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_topic_summaries_project ON topic_summaries(project_id);
CREATE INDEX IF NOT EXISTS idx_topic_summaries_topic ON topic_summaries(project_id, topic);
CREATE INDEX IF NOT EXISTS idx_learning_sessions_user ON learning_sessions(user_id);

-- RLS Policies
ALTER TABLE graph_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE topic_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_sessions ENABLE ROW LEVEL SECURITY;

-- Users can only see their own analytics
CREATE POLICY graph_analytics_user_policy ON graph_analytics
    FOR ALL USING (auth.uid() = user_id);

-- Topic summaries are shared within a project
CREATE POLICY topic_summaries_project_policy ON topic_summaries
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM projects p 
            WHERE p.id = topic_summaries.project_id 
            AND p.user_id = auth.uid()
        )
    );

-- Users can only see their own learning sessions
CREATE POLICY learning_sessions_user_policy ON learning_sessions
    FOR ALL USING (auth.uid() = user_id);
