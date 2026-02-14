-- ============================================================
-- Migration: Move ALL localStorage data to Supabase
-- Keys migrated: settings, bookmarks, study_activity, exams,
--   learning_progress, pomodoro_sessions, recent_searches, streaks
-- Keys kept in localStorage: token, user (auth only)
-- ============================================================

-- 1. User Settings (replaces lumina_settings localStorage key)
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

-- 2. Bookmarks (replaces bookmarks_${projectId} localStorage key)
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

-- 3. Study Activity (replaces study_activity_${projectId} localStorage key)
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

-- 4. Exam Schedules (replaces exams_${projectId} localStorage key)
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

-- 5. Learning Progress (replaces lumina_path_progress_${projectId} localStorage key)
CREATE TABLE IF NOT EXISTS learning_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    completed_topics TEXT[] DEFAULT '{}',
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, project_id)
);

-- 6. Pomodoro Sessions (replaces pomodoro_${docId} / pomodoro_global localStorage keys)
CREATE TABLE IF NOT EXISTS pomodoro_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    sessions INT DEFAULT 0,
    focus_time_minutes INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, COALESCE(document_id, '00000000-0000-0000-0000-000000000000'::uuid), session_date)
);

-- 7. Recent Searches (replaces recent_searches_${projectId} localStorage key)
CREATE TABLE IF NOT EXISTS recent_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Study Streaks (replaces streak_${projectId} localStorage key - was never written!)
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

-- ============== Indexes ==============
CREATE INDEX IF NOT EXISTS idx_user_settings_user ON user_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_project ON bookmarks(user_id, project_id);
CREATE INDEX IF NOT EXISTS idx_study_activity_user_project ON study_activity(user_id, project_id);
CREATE INDEX IF NOT EXISTS idx_study_activity_date ON study_activity(activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_exam_schedules_user_project ON exam_schedules(user_id, project_id);
CREATE INDEX IF NOT EXISTS idx_learning_progress_user_project ON learning_progress(user_id, project_id);
CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_user ON pomodoro_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_recent_searches_user_project ON recent_searches(user_id, project_id);
CREATE INDEX IF NOT EXISTS idx_study_streaks_user_project ON study_streaks(user_id, project_id);

-- ============== RLS Policies ==============
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE pomodoro_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE recent_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_streaks ENABLE ROW LEVEL SECURITY;

-- Users can only access their own data
CREATE POLICY settings_user_policy ON user_settings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY bookmarks_user_policy ON bookmarks FOR ALL USING (auth.uid() = user_id);
CREATE POLICY activity_user_policy ON study_activity FOR ALL USING (auth.uid() = user_id);
CREATE POLICY exams_user_policy ON exam_schedules FOR ALL USING (auth.uid() = user_id);
CREATE POLICY progress_user_policy ON learning_progress FOR ALL USING (auth.uid() = user_id);
CREATE POLICY pomodoro_user_policy ON pomodoro_sessions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY searches_user_policy ON recent_searches FOR ALL USING (auth.uid() = user_id);
CREATE POLICY streaks_user_policy ON study_streaks FOR ALL USING (auth.uid() = user_id);
