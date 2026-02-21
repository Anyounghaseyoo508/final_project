# SQL สำหรับสร้างตารางใหม่ที่จำเป็น

-- ตาราง game_scores สำหรับเก็บคะแนนเกม
CREATE TABLE IF NOT EXISTS game_scores (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  game_type TEXT NOT NULL, -- 'matching', 'sentence_completion', 'word_search'
  score INTEGER NOT NULL DEFAULT 0,
  moves INTEGER, -- สำหรับเกม matching
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ตาราง user_settings สำหรับเก็บการตั้งค่าผู้ใช้
CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  notifications_enabled BOOLEAN DEFAULT TRUE,
  sound_enabled BOOLEAN DEFAULT TRUE,
  dark_mode BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ตาราง user_issues สำหรับเก็บปัญหาที่รายงาน
CREATE TABLE IF NOT EXISTS user_issues (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  status TEXT DEFAULT 'pending', -- 'pending', 'resolved'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

-- เพิ่มคอลัมน์ใน users table (ถ้ายังไม่มี)
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_sign_in_at TIMESTAMPTZ;

-- สร้าง storage bucket สำหรับ avatars
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Policy สำหรับ avatars bucket
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Indexes สำหรับ performance
CREATE INDEX IF NOT EXISTS idx_game_scores_user_id ON game_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_game_scores_created_at ON game_scores(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_issues_user_id ON user_issues(user_id);
CREATE INDEX IF NOT EXISTS idx_user_issues_status ON user_issues(status);

-- RLS Policies
ALTER TABLE game_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_issues ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own game scores"
ON game_scores FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own game scores"
ON game_scores FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own settings"
ON user_settings FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings"
ON user_settings FOR ALL
USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own issues"
ON user_issues FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own issues"
ON user_issues FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Admin policies
CREATE POLICY "Admins can view all game scores"
ON game_scores FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid() AND users.role = 'admin'
  )
);

CREATE POLICY "Admins can view all issues"
ON user_issues FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid() AND users.role = 'admin'
  )
);
