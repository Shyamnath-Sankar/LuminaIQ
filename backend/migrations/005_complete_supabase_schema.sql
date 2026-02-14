-- ============================================================
-- LUMINA IQ - Complete Supabase Schema
-- ============================================================
-- Run this in Supabase SQL Editor to ensure ALL tables exist.
-- Safe to run multiple times (uses IF NOT EXISTS / IF NOT EXISTS).
--
-- Tables:
--   Core:       projects, documents, document_chunks, chat_messages,
--               mcq_tests, subjective_tests, answer_evaluations, project_summaries
--   Learning:   user_performance, review_cards, topic_relations
--   Graph:      graph_analytics, topic_summaries, learning_sessions
--   User Data:  user_settings, bookmarks, study_activity, exam_schedules,
--               learning_progress, pomodoro_sessions, recent_searches, study_streaks
-- ============================================================

-- ============================================================
-- SECTION 1: Adaptive Learning (003_adaptive_learning.sql)
-- ============================================================

-- 1.1 User Performance
CREATE TABLE IF NOT EXISTS user_performance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    topic TEXT NOT NULL,
    correct_count INTEGER DEFAULT 0,
    wrong_count INTEGER DEFAULT 0,
    last_attempt TIMESTAMPTZ DEFAULT NOW(),
    history JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_user_project_topic UNIQUE(user_id, project_id, topic)
);

CREATE INDEX IF NOT EXISTS idx_performance_user_project
    ON user_performance(user_id, project_id);
CREATE INDEX IF NOT EXISTS idx_performance_weakness
    ON user_performance(user_id, project_id, wrong_count DESC);

ALTER TABLE user_performance ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "perf_select" ON user_performance FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "perf_insert" ON user_performance FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "perf_update" ON user_performance FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "perf_delete" ON user_performance FOR DELETE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 1.2 Review Cards (SM-2 spaced repetition)
CREATE TABLE IF NOT EXISTS review_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    topic TEXT NOT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    easiness_factor FLOAT DEFAULT 2.5,
    interval_days INTEGER DEFAULT 0,
    repetition INTEGER DEFAULT 0,
    next_review TIMESTAMPTZ DEFAULT NOW(),
    last_reviewed TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_review_cards_due
    ON review_cards(user_id, next_review ASC);
CREATE INDEX IF NOT EXISTS idx_review_cards_project
    ON review_cards(user_id, project_id, next_review ASC);
CREATE INDEX IF NOT EXISTS idx_review_cards_topic
    ON review_cards(user_id, project_id, topic);

ALTER TABLE review_cards ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "cards_select" ON review_cards FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "cards_insert" ON review_cards FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "cards_update" ON review_cards FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "cards_delete" ON review_cards FOR DELETE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 1.3 Topic Relations (Knowledge Graph edges)
CREATE TABLE IF NOT EXISTS topic_relations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    from_topic TEXT NOT NULL,
    to_topic TEXT NOT NULL,
    relation_type TEXT DEFAULT 'related' CHECK (relation_type IN ('prerequisite', 'related', 'subtopic')),
    weight FLOAT DEFAULT 0.5 CHECK (weight >= 0.1 AND weight <= 1.0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_project_edge UNIQUE(project_id, from_topic, to_topic)
);

CREATE INDEX IF NOT EXISTS idx_topic_relations_from
    ON topic_relations(project_id, from_topic);
CREATE INDEX IF NOT EXISTS idx_topic_relations_to
    ON topic_relations(project_id, to_topic);
CREATE INDEX IF NOT EXISTS idx_topic_relations_type
    ON topic_relations(project_id, relation_type);

ALTER TABLE topic_relations ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "relations_select" ON topic_relations FOR SELECT
        USING (EXISTS (SELECT 1 FROM projects WHERE projects.id = topic_relations.project_id AND projects.user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "relations_insert" ON topic_relations FOR INSERT
        WITH CHECK (EXISTS (SELECT 1 FROM projects WHERE projects.id = topic_relations.project_id AND projects.user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "relations_update" ON topic_relations FOR UPDATE
        USING (EXISTS (SELECT 1 FROM projects WHERE projects.id = topic_relations.project_id AND projects.user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "relations_delete" ON topic_relations FOR DELETE
        USING (EXISTS (SELECT 1 FROM projects WHERE projects.id = topic_relations.project_id AND projects.user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ============================================================
-- SECTION 2: Graph Analytics (003_graph_analytics.sql)
-- ============================================================

-- 2.1 Graph Analytics
CREATE TABLE IF NOT EXISTS graph_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    topic TEXT NOT NULL,
    event_type TEXT NOT NULL,
    duration_ms INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_graph_analytics_project ON graph_analytics(project_id);
CREATE INDEX IF NOT EXISTS idx_graph_analytics_user ON graph_analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_graph_analytics_topic ON graph_analytics(topic);
CREATE INDEX IF NOT EXISTS idx_graph_analytics_created ON graph_analytics(created_at DESC);

ALTER TABLE graph_analytics ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "ga_user_policy" ON graph_analytics FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2.2 Topic Summaries Cache
CREATE TABLE IF NOT EXISTS topic_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    topic TEXT NOT NULL,
    summary TEXT NOT NULL,
    sources JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_id, topic)
);

CREATE INDEX IF NOT EXISTS idx_topic_summaries_project ON topic_summaries(project_id);
CREATE INDEX IF NOT EXISTS idx_topic_summaries_topic ON topic_summaries(project_id, topic);

ALTER TABLE topic_summaries ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "ts_project_policy" ON topic_summaries FOR ALL
        USING (EXISTS (SELECT 1 FROM projects p WHERE p.id = topic_summaries.project_id AND p.user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2.3 Learning Sessions
CREATE TABLE IF NOT EXISTS learning_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    topics_visited TEXT[] DEFAULT '{}',
    total_time_ms INTEGER DEFAULT 0,
    suggestions_shown TEXT[] DEFAULT '{}',
    suggestions_followed TEXT[] DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_learning_sessions_user ON learning_sessions(user_id);

ALTER TABLE learning_sessions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "ls_user_policy" ON learning_sessions FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ============================================================
-- SECTION 3: User Data - replaces localStorage (004_localStorage_to_supabase.sql)
-- ============================================================

-- 3.1 User Settings
CREATE TABLE IF NOT EXISTS user_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    settings JSONB NOT NULL DEFAULT '{
        "bookIsolation": false,
        "darkMode": false,
        "pomodoroWork": 25,
        "pomodoroBreak": 5,
        "pomodoroLongBreak": 15,
        "pomodoroAutoStart": false,
        "studyReminders": false,
        "reminderTime": "09:00",
        "soundEnabled": true,
        "showStreaks": true,
        "compactMode": false,
        "tutorStyle": "balanced",
        "quizDifficulty": "medium"
    }',
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_settings_user ON user_settings(user_id);

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "settings_policy" ON user_settings FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3.2 Bookmarks
CREATE TABLE IF NOT EXISTS bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    note TEXT DEFAULT '',
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    type TEXT DEFAULT 'general',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bookmarks_user_project ON bookmarks(user_id, project_id);

ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "bookmarks_policy" ON bookmarks FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3.3 Study Activity (heatmap data)
CREATE TABLE IF NOT EXISTS study_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    activity_date DATE NOT NULL DEFAULT CURRENT_DATE,
    quiz INT DEFAULT 0,
    review INT DEFAULT 0,
    notes INT DEFAULT 0,
    qa INT DEFAULT 0,
    pomodoro INT DEFAULT 0,
    chat INT DEFAULT 0,
    quiz_scores JSONB DEFAULT '[]',
    total INT DEFAULT 0,
    UNIQUE(user_id, project_id, activity_date)
);

CREATE INDEX IF NOT EXISTS idx_study_activity_user_project ON study_activity(user_id, project_id);
CREATE INDEX IF NOT EXISTS idx_study_activity_date ON study_activity(activity_date DESC);

ALTER TABLE study_activity ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "activity_policy" ON study_activity FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3.4 Exam Schedules
CREATE TABLE IF NOT EXISTS exam_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    exam_date TIMESTAMPTZ NOT NULL,
    topics TEXT[] DEFAULT '{}',
    difficulty TEXT DEFAULT 'medium',
    progress JSONB DEFAULT '{"topicsReviewed": 0, "quizzesTaken": 0, "mockExamsTaken": 0, "averageScore": 0}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exam_schedules_user_project ON exam_schedules(user_id, project_id);

ALTER TABLE exam_schedules ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "exams_policy" ON exam_schedules FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3.5 Learning Progress
CREATE TABLE IF NOT EXISTS learning_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    completed_topics TEXT[] DEFAULT '{}',
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, project_id)
);

CREATE INDEX IF NOT EXISTS idx_learning_progress_user_project ON learning_progress(user_id, project_id);

ALTER TABLE learning_progress ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "progress_policy" ON learning_progress FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3.6 Pomodoro Sessions
CREATE TABLE IF NOT EXISTS pomodoro_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    sessions INT DEFAULT 0,
    focus_time_minutes INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_pomodoro_sessions_unique
    ON pomodoro_sessions(user_id, COALESCE(document_id, '00000000-0000-0000-0000-000000000000'::uuid), session_date);

CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_user ON pomodoro_sessions(user_id);

ALTER TABLE pomodoro_sessions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "pomodoro_policy" ON pomodoro_sessions FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3.7 Recent Searches
CREATE TABLE IF NOT EXISTS recent_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recent_searches_user_project ON recent_searches(user_id, project_id);

ALTER TABLE recent_searches ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "searches_policy" ON recent_searches FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3.8 Study Streaks
CREATE TABLE IF NOT EXISTS study_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    current_streak INT DEFAULT 0,
    longest_streak INT DEFAULT 0,
    last_study_date DATE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, project_id)
);

CREATE INDEX IF NOT EXISTS idx_study_streaks_user_project ON study_streaks(user_id, project_id);

ALTER TABLE study_streaks ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "streaks_policy" ON study_streaks FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ============================================================
-- VERIFICATION
-- ============================================================
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
    'user_performance', 'review_cards', 'topic_relations',
    'graph_analytics', 'topic_summaries', 'learning_sessions',
    'user_settings', 'bookmarks', 'study_activity', 'exam_schedules',
    'learning_progress', 'pomodoro_sessions', 'recent_searches', 'study_streaks'
)
ORDER BY table_name;
