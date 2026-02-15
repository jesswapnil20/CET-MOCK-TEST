-- ═══════════════════════════════════════════════════════════════
-- GR Educational Consultancy — Supabase Backend Schema (v2)
-- Run in Supabase SQL Editor (Dashboard → SQL Editor)
-- Updated: Feb 2026 — includes Teachers, Colleges, Permissions,
--   Student Plans, Test Assignment, Approval Workflow, WhatsApp logs
-- ═══════════════════════════════════════════════════════════════


-- ┌─────────────────────────────────────────┐
-- │  1. ENUMS                               │
-- └─────────────────────────────────────────┘

CREATE TYPE user_role AS ENUM ('student', 'admin', 'teacher');
CREATE TYPE difficulty_level AS ENUM ('easy', 'medium', 'hard');
CREATE TYPE test_status AS ENUM ('draft', 'active', 'upcoming', 'archived', 'pending_approval');
CREATE TYPE question_status AS ENUM ('active', 'inactive', 'review');
CREATE TYPE attempt_status AS ENUM ('in_progress', 'completed', 'timed_out');
CREATE TYPE approval_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE student_plan AS ENUM ('free', 'prime');
CREATE TYPE test_access_level AS ENUM ('free', 'prime');
CREATE TYPE assign_type AS ENUM ('all', 'courses', 'streams', 'students');
CREATE TYPE login_provider AS ENUM ('email', 'google', 'phone');
CREATE TYPE teacher_status AS ENUM ('active', 'inactive');


-- ┌─────────────────────────────────────────┐
-- │  2. COLLEGES / INSTITUTIONS             │
-- └─────────────────────────────────────────┘

CREATE TABLE colleges (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  short_name TEXT NOT NULL,               -- FC, SXC, SI, COEP
  city TEXT,
  color TEXT DEFAULT '#2563eb',           -- Hex brand color
  logo_url TEXT,                          -- Storage URL for college logo
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO colleges (name, short_name, city, color) VALUES
  ('Fergusson College', 'FC', 'Pune', '#2563eb'),
  ('St. Xavier''s College', 'SXC', 'Mumbai', '#dc2626'),
  ('Symbiosis Institute', 'SI', 'Pune', '#16a34a'),
  ('COEP Technological University', 'COEP', 'Pune', '#7c3aed');


-- ┌─────────────────────────────────────────┐
-- │  3. CONFIGURABLE LOOKUPS                │
-- │     (Modes, Streams, Courses)           │
-- └─────────────────────────────────────────┘

CREATE TABLE exam_modes (
  id SERIAL PRIMARY KEY,
  value TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  is_default BOOLEAN DEFAULT false,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO exam_modes (value, label, is_default, display_order) VALUES
  ('combined', 'Combined', true, 1),
  ('subject_wise', 'Subject-wise', true, 2),
  ('chapter_wise', 'Chapter-wise', true, 3),
  ('topic_wise', 'Topic-wise', true, 4),
  ('mock_test', 'Mock Test', true, 5),
  ('practice', 'Practice', true, 6),
  ('previous_year', 'Previous Year', true, 7),
  ('custom', 'Custom', true, 8),
  ('sectional', 'Sectional', true, 9),
  ('speed_test', 'Speed Test', true, 10),
  ('revision', 'Revision', true, 11);

CREATE TABLE exam_streams (
  id SERIAL PRIMARY KEY,
  value TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  is_default BOOLEAN DEFAULT false,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO exam_streams (value, label, is_default, display_order) VALUES
  ('PCM', 'PCM', true, 1), ('PCB', 'PCB', true, 2), ('PCMB', 'PCMB', true, 3),
  ('Law', 'Law', true, 4), ('MBA', 'MBA', true, 5), ('Pharmacy', 'Pharmacy', true, 6),
  ('Nursing', 'Nursing', true, 7), ('Agriculture', 'Agriculture', true, 8),
  ('Hotel Management', 'Hotel Management', true, 9), ('Design', 'Design', true, 10),
  ('Education', 'Education', true, 11), ('Arts', 'Arts', true, 12);

CREATE TABLE exam_courses (
  id SERIAL PRIMARY KEY,
  value TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  is_default BOOLEAN DEFAULT false,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO exam_courses (value, label, is_default, display_order) VALUES
  ('CET PCM', 'CET PCM', true, 1), ('CET PCB', 'CET PCB', true, 2),
  ('JEE', 'JEE', true, 3), ('NEET', 'NEET', true, 4),
  ('MBA CET', 'MBA CET', true, 5), ('Law Entrance', 'Law Entrance', true, 6),
  ('B.Pharma', 'B.Pharma', true, 7), ('B.Sc Nursing', 'B.Sc Nursing', true, 8),
  ('Hotel Mgmt', 'Hotel Mgmt', true, 9), ('NID/NIFT', 'NID/NIFT', true, 10),
  ('B.Ed CET', 'B.Ed CET', true, 11);


-- ┌─────────────────────────────────────────┐
-- │  4. PROFILES (extends Supabase auth)    │
-- │     Students & Admins                   │
-- └─────────────────────────────────────────┘

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role user_role DEFAULT 'student',
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  mobile TEXT,
  gender TEXT,
  dob DATE,
  category TEXT,                          -- Open, OBC, SC, ST, NT, SBC, EWS
  stream TEXT,                            -- PCM, PCB, Law, MBA
  course TEXT,                            -- CET PCM, JEE, NEET, etc.
  city TEXT,
  state TEXT,
  district TEXT,
  pin_code TEXT,
  avatar_url TEXT,
  -- Login tracking
  login_provider login_provider DEFAULT 'email',
  last_login TIMESTAMPTZ,
  password_reset_date TIMESTAMPTZ,
  -- Student plan / subscription
  plan student_plan DEFAULT 'free',
  plan_name TEXT,                         -- CET Full Access, NEET Pro Bundle, etc.
  plan_expiry DATE,
  amount_paid NUMERIC DEFAULT 0,
  plan_start_date DATE,
  -- Parent contact (for WhatsApp sharing)
  parent_name TEXT,
  parent_mobile TEXT,
  -- Status
  status TEXT DEFAULT 'active',           -- active, blocked, inactive
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, first_name, last_name, email)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'first_name',
    NEW.raw_user_meta_data->>'last_name',
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();


-- ┌─────────────────────────────────────────┐
-- │  5. TEACHERS                            │
-- └─────────────────────────────────────────┘

CREATE TABLE teachers (
  id SERIAL PRIMARY KEY,
  auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  username TEXT NOT NULL UNIQUE,
  -- College link
  college_id INT REFERENCES colleges(id) ON DELETE SET NULL,
  -- Subject expertise (array of subject IDs)
  subjects INT[],
  -- Page permissions (granular access control by admin)
  -- Possible: question_bank, add_question, csv_upload, create_test, my_tests, view_results
  permissions TEXT[] DEFAULT ARRAY['question_bank','add_question','csv_upload','create_test','my_tests','view_results'],
  -- Stats
  questions_added INT DEFAULT 0,
  -- Status
  status teacher_status DEFAULT 'active',
  last_login TIMESTAMPTZ,
  join_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_teachers_college ON teachers(college_id);
CREATE INDEX idx_teachers_status ON teachers(status);


-- ┌─────────────────────────────────────────┐
-- │  6. SUBJECTS                            │
-- └─────────────────────────────────────────┘

CREATE TABLE subjects (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  code TEXT NOT NULL UNIQUE,
  stream TEXT[],
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO subjects (name, code, stream, display_order) VALUES
  ('Physics', 'PHY', '{PCM,PCB}', 1),
  ('Chemistry', 'CHE', '{PCM,PCB}', 2),
  ('Mathematics', 'MAT', '{PCM}', 3),
  ('Biology', 'BIO', '{PCB}', 4);


-- ┌─────────────────────────────────────────┐
-- │  7. CHAPTERS                            │
-- └─────────────────────────────────────────┘

CREATE TABLE chapters (
  id SERIAL PRIMARY KEY,
  subject_id INT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(subject_id, name)
);

INSERT INTO chapters (subject_id, name, display_order) VALUES
  (1, 'Kinematics', 1), (1, 'Laws of Motion', 2), (1, 'Work Energy Power', 3),
  (1, 'Gravitation', 4), (1, 'Optics', 5), (1, 'Current Electricity', 6),
  (1, 'Electrostatics', 7), (1, 'Magnetism', 8), (1, 'Modern Physics', 9),
  (1, 'Vectors', 10), (1, 'Thermodynamics', 11), (1, 'Waves', 12),
  (2, 'Chemical Reactions', 1), (2, 'Chemical Bonding', 2), (2, 'Ionic Equilibrium', 3),
  (2, 'Mole Concept', 4), (2, 'Periodic Table', 5), (2, 'Organic Chemistry', 6),
  (2, 'Electrochemistry', 7), (2, 'Thermochemistry', 8), (2, 'Solid State', 9),
  (3, 'Differentiation', 1), (3, 'Integration', 2), (3, 'Matrices', 3),
  (3, 'Conic Sections', 4), (3, 'Limits', 5), (3, 'Probability', 6),
  (3, 'Trigonometry', 7), (3, 'Algebra', 8), (3, 'Vectors & 3D', 9);


-- ┌─────────────────────────────────────────┐
-- │  8. TOPICS                              │
-- └─────────────────────────────────────────┘

CREATE TABLE topics (
  id SERIAL PRIMARY KEY,
  chapter_id INT NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(chapter_id, name)
);


-- ┌─────────────────────────────────────────┐
-- │  9. QUESTIONS                           │
-- └─────────────────────────────────────────┘

CREATE TABLE questions (
  id SERIAL PRIMARY KEY,
  subject_id INT NOT NULL REFERENCES subjects(id),
  chapter_id INT NOT NULL REFERENCES chapters(id),
  topic_id INT REFERENCES topics(id),
  difficulty difficulty_level DEFAULT 'medium',
  question_text TEXT NOT NULL,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_option INT NOT NULL CHECK (correct_option BETWEEN 0 AND 3),
  solution TEXT,
  image_url TEXT,
  solution_image_url TEXT,
  marks NUMERIC DEFAULT 1,
  negative_marks NUMERIC DEFAULT 0,
  status question_status DEFAULT 'active',
  tags TEXT[],
  -- Created by admin or teacher
  created_by_role user_role,
  created_by_admin UUID REFERENCES profiles(id),
  created_by_teacher INT REFERENCES teachers(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_questions_subject ON questions(subject_id);
CREATE INDEX idx_questions_chapter ON questions(chapter_id);
CREATE INDEX idx_questions_difficulty ON questions(difficulty);
CREATE INDEX idx_questions_status ON questions(status);
CREATE INDEX idx_questions_subject_chapter ON questions(subject_id, chapter_id);
CREATE INDEX idx_questions_teacher ON questions(created_by_teacher);


-- ┌─────────────────────────────────────────┐
-- │  10. TESTS (assignment + approval)      │
-- └─────────────────────────────────────────┘

CREATE TABLE tests (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  mode TEXT DEFAULT 'combined',
  status test_status DEFAULT 'draft',
  -- Config
  duration_minutes INT NOT NULL DEFAULT 60,
  total_questions INT NOT NULL,
  marks_per_question NUMERIC DEFAULT 1,
  negative_per_question NUMERIC DEFAULT 0,
  -- Question selection rules
  subjects INT[],
  chapters INT[],
  difficulty_mix JSONB,
  questions_per_subject JSONB,
  method TEXT DEFAULT 'auto',             -- auto, upload, manual
  -- Access / Plan gating
  access_level test_access_level DEFAULT 'free',
  is_free BOOLEAN DEFAULT true,
  price NUMERIC DEFAULT 0,
  stream TEXT,
  -- Assignment (who can see/take this test)
  assign_type assign_type DEFAULT 'all',
  assigned_courses TEXT[],
  assigned_streams TEXT[],
  assigned_student_ids UUID[],
  -- Scheduling
  available_from TIMESTAMPTZ,
  available_until TIMESTAMPTZ,
  -- Created by (admin or teacher)
  created_by_role user_role DEFAULT 'admin',
  created_by_admin UUID REFERENCES profiles(id),
  created_by_teacher INT REFERENCES teachers(id),
  -- Approval workflow (teacher-created tests)
  approval_status approval_status DEFAULT 'approved',
  approval_note TEXT,
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  -- Meta
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_tests_status ON tests(status);
CREATE INDEX idx_tests_access ON tests(access_level);
CREATE INDEX idx_tests_approval ON tests(approval_status);
CREATE INDEX idx_tests_teacher ON tests(created_by_teacher);


-- ┌─────────────────────────────────────────┐
-- │  11. TEACHER–TEST ASSIGNMENTS           │
-- └─────────────────────────────────────────┘

CREATE TABLE teacher_test_assignments (
  id SERIAL PRIMARY KEY,
  teacher_id INT NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
  test_id INT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(teacher_id, test_id)
);

CREATE INDEX idx_teacher_tests ON teacher_test_assignments(teacher_id);


-- ┌─────────────────────────────────────────┐
-- │  12. TEST_QUESTIONS (test ↔ questions)  │
-- └─────────────────────────────────────────┘

CREATE TABLE test_questions (
  id SERIAL PRIMARY KEY,
  test_id INT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  question_id INT NOT NULL REFERENCES questions(id),
  question_order INT NOT NULL,
  section TEXT,
  UNIQUE(test_id, question_id),
  UNIQUE(test_id, question_order)
);

CREATE INDEX idx_test_questions_test ON test_questions(test_id);


-- ┌─────────────────────────────────────────┐
-- │  13. TEST_CSV_QUESTIONS                 │
-- │     (CSV-uploaded questions per test,   │
-- │      NOT in global question bank)       │
-- └─────────────────────────────────────────┘

CREATE TABLE test_csv_questions (
  id SERIAL PRIMARY KEY,
  test_id INT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  subject TEXT,
  chapter TEXT,
  difficulty difficulty_level DEFAULT 'medium',
  question_text TEXT NOT NULL,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_option INT NOT NULL CHECK (correct_option BETWEEN 0 AND 3),
  solution TEXT,
  question_order INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_csv_questions_test ON test_csv_questions(test_id);


-- ┌─────────────────────────────────────────┐
-- │  14. TEST ATTEMPTS                      │
-- └─────────────────────────────────────────┘

CREATE TABLE test_attempts (
  id SERIAL PRIMARY KEY,
  test_id INT NOT NULL REFERENCES tests(id),
  student_id UUID NOT NULL REFERENCES profiles(id),
  status attempt_status DEFAULT 'in_progress',
  started_at TIMESTAMPTZ DEFAULT now(),
  finished_at TIMESTAMPTZ,
  time_taken_seconds INT,
  total_questions INT,
  attempted INT DEFAULT 0,
  correct INT DEFAULT 0,
  incorrect INT DEFAULT 0,
  unanswered INT DEFAULT 0,
  score NUMERIC DEFAULT 0,
  max_score NUMERIC,
  percentage NUMERIC,
  question_times JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_attempts_student ON test_attempts(student_id);
CREATE INDEX idx_attempts_test ON test_attempts(test_id);
CREATE INDEX idx_attempts_status ON test_attempts(status);


-- ┌─────────────────────────────────────────┐
-- │  15. ATTEMPT ANSWERS                    │
-- └─────────────────────────────────────────┘

CREATE TABLE attempt_answers (
  id SERIAL PRIMARY KEY,
  attempt_id INT NOT NULL REFERENCES test_attempts(id) ON DELETE CASCADE,
  question_id INT NOT NULL REFERENCES questions(id),
  selected_option INT,
  is_marked BOOLEAN DEFAULT false,
  is_correct BOOLEAN,
  time_spent_seconds NUMERIC DEFAULT 0,
  answered_at TIMESTAMPTZ,
  UNIQUE(attempt_id, question_id)
);

CREATE INDEX idx_answers_attempt ON attempt_answers(attempt_id);


-- ┌─────────────────────────────────────────┐
-- │  16. WHATSAPP SHARE LOG                 │
-- └─────────────────────────────────────────┘

CREATE TABLE whatsapp_share_log (
  id SERIAL PRIMARY KEY,
  attempt_id INT NOT NULL REFERENCES test_attempts(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES profiles(id),
  recipient_type TEXT NOT NULL,           -- 'student' or 'parent'
  recipient_phone TEXT NOT NULL,
  recipient_name TEXT,
  message_preview TEXT,
  shared_by_role user_role,
  shared_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_whatsapp_log_attempt ON whatsapp_share_log(attempt_id);
CREATE INDEX idx_whatsapp_log_student ON whatsapp_share_log(student_id);


-- ┌─────────────────────────────────────────┐
-- │  17. ACTIVITY LOG (audit trail)         │
-- └─────────────────────────────────────────┘

CREATE TABLE activity_log (
  id SERIAL PRIMARY KEY,
  actor_role user_role NOT NULL,
  actor_id TEXT NOT NULL,
  action TEXT NOT NULL,                   -- permission_change, test_approved, test_rejected, etc.
  target_type TEXT,                       -- teacher, test, question, student
  target_id TEXT,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_activity_log_actor ON activity_log(actor_role, actor_id);
CREATE INDEX idx_activity_log_action ON activity_log(action);
CREATE INDEX idx_activity_log_created ON activity_log(created_at DESC);


-- ┌─────────────────────────────────────────┐
-- │  18. HELPER FUNCTIONS                   │
-- └─────────────────────────────────────────┘

-- Auto-generate test questions based on rules
CREATE OR REPLACE FUNCTION generate_test_questions(
  p_test_id INT, p_subjects INT[], p_chapters INT[],
  p_total INT, p_per_subject JSONB, p_difficulty_mix JSONB
)
RETURNS VOID AS $$
DECLARE
  v_subject_id INT; v_count INT; v_easy INT; v_medium INT; v_hard INT;
  v_order INT := 1; v_subject_name TEXT;
BEGIN
  DELETE FROM test_questions WHERE test_id = p_test_id;
  FOREACH v_subject_id IN ARRAY p_subjects LOOP
    v_count := COALESCE((p_per_subject->>v_subject_id::text)::int, p_total / array_length(p_subjects, 1));
    v_easy := ROUND(v_count * COALESCE((p_difficulty_mix->>'easy')::numeric, 33) / 100);
    v_hard := ROUND(v_count * COALESCE((p_difficulty_mix->>'hard')::numeric, 33) / 100);
    v_medium := v_count - v_easy - v_hard;
    SELECT name INTO v_subject_name FROM subjects WHERE id = v_subject_id;

    INSERT INTO test_questions (test_id, question_id, question_order, section)
    SELECT p_test_id, q.id, v_order + row_number() OVER () - 1, v_subject_name
    FROM questions q WHERE q.subject_id = v_subject_id AND q.difficulty = 'easy' AND q.status = 'active'
      AND (p_chapters IS NULL OR q.chapter_id = ANY(p_chapters))
    ORDER BY random() LIMIT v_easy;
    v_order := v_order + v_easy;

    INSERT INTO test_questions (test_id, question_id, question_order, section)
    SELECT p_test_id, q.id, v_order + row_number() OVER () - 1, v_subject_name
    FROM questions q WHERE q.subject_id = v_subject_id AND q.difficulty = 'medium' AND q.status = 'active'
      AND (p_chapters IS NULL OR q.chapter_id = ANY(p_chapters))
      AND q.id NOT IN (SELECT question_id FROM test_questions WHERE test_id = p_test_id)
    ORDER BY random() LIMIT v_medium;
    v_order := v_order + v_medium;

    INSERT INTO test_questions (test_id, question_id, question_order, section)
    SELECT p_test_id, q.id, v_order + row_number() OVER () - 1, v_subject_name
    FROM questions q WHERE q.subject_id = v_subject_id AND q.difficulty = 'hard' AND q.status = 'active'
      AND (p_chapters IS NULL OR q.chapter_id = ANY(p_chapters))
      AND q.id NOT IN (SELECT question_id FROM test_questions WHERE test_id = p_test_id)
    ORDER BY random() LIMIT v_hard;
    v_order := v_order + v_hard;
  END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Submit test attempt & calculate results
CREATE OR REPLACE FUNCTION submit_test_attempt(p_attempt_id INT)
RETURNS JSONB AS $$
DECLARE v_result JSONB;
BEGIN
  UPDATE attempt_answers aa SET is_correct = (aa.selected_option = q.correct_option)
  FROM questions q
  WHERE aa.question_id = q.id AND aa.attempt_id = p_attempt_id AND aa.selected_option IS NOT NULL;

  UPDATE test_attempts ta SET
    status = 'completed', finished_at = now(),
    time_taken_seconds = EXTRACT(EPOCH FROM (now() - ta.started_at)),
    total_questions = (SELECT COUNT(*) FROM attempt_answers WHERE attempt_id = p_attempt_id),
    attempted = (SELECT COUNT(*) FROM attempt_answers WHERE attempt_id = p_attempt_id AND selected_option IS NOT NULL),
    correct = (SELECT COUNT(*) FROM attempt_answers WHERE attempt_id = p_attempt_id AND is_correct = true),
    incorrect = (SELECT COUNT(*) FROM attempt_answers WHERE attempt_id = p_attempt_id AND selected_option IS NOT NULL AND is_correct = false),
    unanswered = (SELECT COUNT(*) FROM attempt_answers WHERE attempt_id = p_attempt_id AND selected_option IS NULL),
    score = (
      SELECT COALESCE(SUM(CASE WHEN aa.is_correct THEN t.marks_per_question ELSE -t.negative_per_question END), 0)
      FROM attempt_answers aa JOIN test_attempts ta2 ON ta2.id = aa.attempt_id JOIN tests t ON t.id = ta2.test_id
      WHERE aa.attempt_id = p_attempt_id AND aa.selected_option IS NOT NULL
    ),
    max_score = (SELECT t.total_questions * t.marks_per_question FROM tests t WHERE t.id = ta.test_id)
  WHERE ta.id = p_attempt_id;

  UPDATE test_attempts SET percentage = ROUND((score / NULLIF(max_score, 0)) * 100, 1) WHERE id = p_attempt_id;

  SELECT jsonb_build_object(
    'attempt_id', id, 'score', score, 'max_score', max_score, 'percentage', percentage,
    'correct', correct, 'incorrect', incorrect, 'unanswered', unanswered, 'time_taken', time_taken_seconds
  ) INTO v_result FROM test_attempts WHERE id = p_attempt_id;
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;


-- Approve a teacher-created test
CREATE OR REPLACE FUNCTION approve_test(p_test_id INT, p_admin_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE tests SET approval_status = 'approved', status = 'draft',
    approved_by = p_admin_id, approved_at = now(), updated_at = now()
  WHERE id = p_test_id AND approval_status = 'pending';

  INSERT INTO activity_log (actor_role, actor_id, action, target_type, target_id, details)
  VALUES ('admin', p_admin_id::text, 'test_approved', 'test', p_test_id::text, jsonb_build_object('test_id', p_test_id));
END;
$$ LANGUAGE plpgsql;


-- Reject a teacher-created test
CREATE OR REPLACE FUNCTION reject_test(p_test_id INT, p_admin_id UUID, p_note TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE tests SET approval_status = 'rejected', approval_note = p_note,
    approved_by = p_admin_id, approved_at = now(), updated_at = now()
  WHERE id = p_test_id AND approval_status = 'pending';

  INSERT INTO activity_log (actor_role, actor_id, action, target_type, target_id, details)
  VALUES ('admin', p_admin_id::text, 'test_rejected', 'test', p_test_id::text,
    jsonb_build_object('test_id', p_test_id, 'note', p_note));
END;
$$ LANGUAGE plpgsql;


-- Update teacher permissions (with audit)
CREATE OR REPLACE FUNCTION update_teacher_permissions(p_teacher_id INT, p_new_permissions TEXT[], p_admin_id UUID)
RETURNS VOID AS $$
DECLARE v_old TEXT[];
BEGIN
  SELECT permissions INTO v_old FROM teachers WHERE id = p_teacher_id;
  UPDATE teachers SET permissions = p_new_permissions, updated_at = now() WHERE id = p_teacher_id;
  INSERT INTO activity_log (actor_role, actor_id, action, target_type, target_id, details)
  VALUES ('admin', p_admin_id::text, 'permission_change', 'teacher', p_teacher_id::text,
    jsonb_build_object('old_permissions', v_old, 'new_permissions', p_new_permissions));
END;
$$ LANGUAGE plpgsql;


-- Upgrade student to Prime plan
CREATE OR REPLACE FUNCTION upgrade_student_plan(p_student_id UUID, p_plan_name TEXT, p_amount NUMERIC, p_expiry DATE)
RETURNS VOID AS $$
BEGIN
  UPDATE profiles SET plan = 'prime', plan_name = p_plan_name, amount_paid = p_amount,
    plan_start_date = CURRENT_DATE, plan_expiry = p_expiry, updated_at = now()
  WHERE id = p_student_id;
END;
$$ LANGUAGE plpgsql;


-- Check if student can access a test (plan + assignment)
CREATE OR REPLACE FUNCTION can_student_access_test(p_student_id UUID, p_test_id INT)
RETURNS BOOLEAN AS $$
DECLARE v_test tests; v_student profiles;
BEGIN
  SELECT * INTO v_test FROM tests WHERE id = p_test_id;
  SELECT * INTO v_student FROM profiles WHERE id = p_student_id;
  IF v_test.status != 'active' OR v_test.approval_status != 'approved' THEN RETURN false; END IF;
  IF v_test.access_level = 'prime' AND v_student.plan != 'prime' THEN RETURN false; END IF;
  CASE v_test.assign_type
    WHEN 'all' THEN RETURN true;
    WHEN 'courses' THEN RETURN v_student.course = ANY(v_test.assigned_courses);
    WHEN 'streams' THEN RETURN v_student.stream = ANY(v_test.assigned_streams);
    WHEN 'students' THEN RETURN p_student_id = ANY(v_test.assigned_student_ids);
    ELSE RETURN true;
  END CASE;
END;
$$ LANGUAGE plpgsql;


-- ┌─────────────────────────────────────────┐
-- │  19. ROW LEVEL SECURITY                 │
-- └─────────────────────────────────────────┘

-- Helpers
CREATE OR REPLACE FUNCTION is_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin');
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_teacher() RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM teachers WHERE auth_user_id = auth.uid() AND status = 'active');
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION current_teacher_id() RETURNS INT AS $$
  SELECT id FROM teachers WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins view all profiles" ON profiles FOR SELECT USING (is_admin());
CREATE POLICY "Admins manage all profiles" ON profiles FOR ALL USING (is_admin());

-- Colleges
ALTER TABLE colleges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone reads colleges" ON colleges FOR SELECT USING (true);
CREATE POLICY "Admins manage colleges" ON colleges FOR ALL USING (is_admin());

-- Teachers
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage teachers" ON teachers FOR ALL USING (is_admin());
CREATE POLICY "Teachers view own record" ON teachers FOR SELECT USING (auth_user_id = auth.uid());
CREATE POLICY "Teachers update own record" ON teachers FOR UPDATE USING (auth_user_id = auth.uid());

-- Subjects / Chapters / Topics
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone reads subjects" ON subjects FOR SELECT USING (true);
CREATE POLICY "Anyone reads chapters" ON chapters FOR SELECT USING (true);
CREATE POLICY "Anyone reads topics" ON topics FOR SELECT USING (true);
CREATE POLICY "Admins manage subjects" ON subjects FOR ALL USING (is_admin());
CREATE POLICY "Admins manage chapters" ON chapters FOR ALL USING (is_admin());
CREATE POLICY "Admins manage topics" ON topics FOR ALL USING (is_admin());

-- Questions
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone reads active questions" ON questions FOR SELECT USING (status = 'active');
CREATE POLICY "Admins manage questions" ON questions FOR ALL USING (is_admin());
CREATE POLICY "Teachers with perm insert questions" ON questions FOR INSERT WITH CHECK (
  is_teacher() AND 'add_question' = ANY((SELECT permissions FROM teachers WHERE id = current_teacher_id()))
);
CREATE POLICY "Teachers read own questions" ON questions FOR SELECT USING (created_by_teacher = current_teacher_id());

-- Tests
ALTER TABLE tests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view accessible tests" ON tests FOR SELECT USING (
  status = 'active' AND approval_status = 'approved' AND can_student_access_test(auth.uid(), id)
);
CREATE POLICY "Admins manage tests" ON tests FOR ALL USING (is_admin());
CREATE POLICY "Teachers with perm create tests" ON tests FOR INSERT WITH CHECK (
  is_teacher() AND 'create_test' = ANY((SELECT permissions FROM teachers WHERE id = current_teacher_id()))
);
CREATE POLICY "Teachers view own tests" ON tests FOR SELECT USING (created_by_teacher = current_teacher_id());

-- Test Questions
ALTER TABLE test_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone reads test questions" ON test_questions FOR SELECT USING (true);
CREATE POLICY "Admins manage test questions" ON test_questions FOR ALL USING (is_admin());

-- CSV Questions
ALTER TABLE test_csv_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage csv questions" ON test_csv_questions FOR ALL USING (is_admin());
CREATE POLICY "Teachers insert csv questions" ON test_csv_questions FOR INSERT WITH CHECK (is_teacher());
CREATE POLICY "Anyone reads csv questions" ON test_csv_questions FOR SELECT USING (true);

-- Attempts
ALTER TABLE test_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students own attempts" ON test_attempts FOR ALL USING (student_id = auth.uid());
CREATE POLICY "Admins view all attempts" ON test_attempts FOR SELECT USING (is_admin());
CREATE POLICY "Teachers with results perm view" ON test_attempts FOR SELECT USING (
  is_teacher() AND 'view_results' = ANY((SELECT permissions FROM teachers WHERE id = current_teacher_id()))
);

-- Answers
ALTER TABLE attempt_answers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students own answers" ON attempt_answers FOR ALL USING (
  EXISTS (SELECT 1 FROM test_attempts WHERE id = attempt_id AND student_id = auth.uid())
);
CREATE POLICY "Admins view all answers" ON attempt_answers FOR SELECT USING (is_admin());

-- Lookup tables
ALTER TABLE exam_modes ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_courses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone reads modes" ON exam_modes FOR SELECT USING (true);
CREATE POLICY "Anyone reads streams" ON exam_streams FOR SELECT USING (true);
CREATE POLICY "Anyone reads courses" ON exam_courses FOR SELECT USING (true);
CREATE POLICY "Admins manage modes" ON exam_modes FOR ALL USING (is_admin());
CREATE POLICY "Admins manage streams" ON exam_streams FOR ALL USING (is_admin());
CREATE POLICY "Admins manage courses" ON exam_courses FOR ALL USING (is_admin());

-- WhatsApp Log
ALTER TABLE whatsapp_share_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins view share log" ON whatsapp_share_log FOR SELECT USING (is_admin());
CREATE POLICY "Anyone inserts share log" ON whatsapp_share_log FOR INSERT WITH CHECK (true);

-- Activity Log
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins view activity log" ON activity_log FOR SELECT USING (is_admin());

-- Teacher Test Assignments
ALTER TABLE teacher_test_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage teacher assignments" ON teacher_test_assignments FOR ALL USING (is_admin());
CREATE POLICY "Teachers view own assignments" ON teacher_test_assignments FOR SELECT USING (teacher_id = current_teacher_id());


-- ┌─────────────────────────────────────────┐
-- │  20. VIEWS                              │
-- └─────────────────────────────────────────┘

CREATE OR REPLACE VIEW question_bank_stats AS
SELECT s.name AS subject, c.name AS chapter, q.difficulty, COUNT(*) AS count
FROM questions q JOIN subjects s ON s.id = q.subject_id JOIN chapters c ON c.id = q.chapter_id
WHERE q.status = 'active' GROUP BY s.name, c.name, q.difficulty ORDER BY s.name, c.name, q.difficulty;

CREATE OR REPLACE VIEW test_leaderboard AS
SELECT ta.test_id, t.name AS test_name, p.first_name || ' ' || p.last_name AS student_name,
  ta.score, ta.percentage, ta.correct, ta.time_taken_seconds,
  RANK() OVER (PARTITION BY ta.test_id ORDER BY ta.score DESC, ta.time_taken_seconds ASC) AS rank
FROM test_attempts ta JOIN tests t ON t.id = ta.test_id JOIN profiles p ON p.id = ta.student_id
WHERE ta.status = 'completed';

CREATE OR REPLACE VIEW teacher_dashboard_stats AS
SELECT t.id AS teacher_id, t.name AS teacher_name, c.name AS college_name, c.short_name AS college_short,
  t.questions_added,
  (SELECT COUNT(*) FROM teacher_test_assignments tta WHERE tta.teacher_id = t.id) AS assigned_tests,
  (SELECT COUNT(*) FROM tests WHERE created_by_teacher = t.id) AS created_tests,
  (SELECT COUNT(*) FROM tests WHERE created_by_teacher = t.id AND approval_status = 'pending') AS pending_tests,
  (SELECT COUNT(*) FROM tests WHERE created_by_teacher = t.id AND approval_status = 'approved') AS approved_tests,
  (SELECT COUNT(*) FROM tests WHERE created_by_teacher = t.id AND approval_status = 'rejected') AS rejected_tests
FROM teachers t LEFT JOIN colleges c ON c.id = t.college_id;

CREATE OR REPLACE VIEW admin_dashboard_overview AS
SELECT
  (SELECT COUNT(*) FROM profiles WHERE role = 'student') AS total_students,
  (SELECT COUNT(*) FROM profiles WHERE role = 'student' AND status = 'active') AS active_students,
  (SELECT COUNT(*) FROM profiles WHERE role = 'student' AND plan = 'prime') AS prime_students,
  (SELECT COALESCE(SUM(amount_paid), 0) FROM profiles WHERE plan = 'prime') AS total_revenue,
  (SELECT COUNT(*) FROM questions WHERE status = 'active') AS total_questions,
  (SELECT COUNT(*) FROM tests) AS total_tests,
  (SELECT COUNT(*) FROM tests WHERE approval_status = 'pending') AS pending_approvals,
  (SELECT COUNT(*) FROM teachers WHERE status = 'active') AS active_teachers,
  (SELECT COUNT(*) FROM test_attempts WHERE status = 'completed') AS total_attempts;

CREATE OR REPLACE VIEW pending_approval_tests AS
SELECT t.id, t.name, t.total_questions, t.duration_minutes, t.mode, t.created_at, t.approval_note,
  tea.name AS created_by_name, c.name AS college_name
FROM tests t JOIN teachers tea ON tea.id = t.created_by_teacher LEFT JOIN colleges c ON c.id = tea.college_id
WHERE t.approval_status = 'pending' ORDER BY t.created_at DESC;


-- ┌─────────────────────────────────────────┐
-- │  21. STORAGE BUCKETS                    │
-- └─────────────────────────────────────────┘

INSERT INTO storage.buckets (id, name, public) VALUES ('question-images', 'question-images', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('college-logos', 'college-logos', true) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Admins upload question images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'question-images' AND is_admin());
CREATE POLICY "Teachers upload question images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'question-images' AND is_teacher());
CREATE POLICY "Anyone views question images" ON storage.objects FOR SELECT USING (bucket_id = 'question-images');
CREATE POLICY "Admins delete question images" ON storage.objects FOR DELETE USING (bucket_id = 'question-images' AND is_admin());
CREATE POLICY "Admins upload college logos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'college-logos' AND is_admin());
CREATE POLICY "Anyone views college logos" ON storage.objects FOR SELECT USING (bucket_id = 'college-logos');
CREATE POLICY "Admins delete college logos" ON storage.objects FOR DELETE USING (bucket_id = 'college-logos' AND is_admin());


-- ┌─────────────────────────────────────────┐
-- │  22. TRIGGERS                           │
-- └─────────────────────────────────────────┘

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_teachers_updated BEFORE UPDATE ON teachers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_questions_updated BEFORE UPDATE ON questions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_tests_updated BEFORE UPDATE ON tests FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_colleges_updated BEFORE UPDATE ON colleges FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-increment teacher question count
CREATE OR REPLACE FUNCTION increment_teacher_question_count() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.created_by_teacher IS NOT NULL THEN
    UPDATE teachers SET questions_added = questions_added + 1 WHERE id = NEW.created_by_teacher;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_question_count AFTER INSERT ON questions FOR EACH ROW EXECUTE FUNCTION increment_teacher_question_count();

-- Log when teacher submits test for approval
CREATE OR REPLACE FUNCTION notify_test_pending() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.approval_status = 'pending' AND NEW.created_by_role = 'teacher' THEN
    INSERT INTO activity_log (actor_role, actor_id, action, target_type, target_id, details)
    VALUES ('teacher', NEW.created_by_teacher::text, 'test_submitted', 'test', NEW.id::text,
      jsonb_build_object('test_name', NEW.name, 'questions', NEW.total_questions));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_test_pending_notify AFTER INSERT ON tests FOR EACH ROW EXECUTE FUNCTION notify_test_pending();


-- ═══════════════════════════════════════════════════════════════
-- SCHEMA SUMMARY (v2)
-- ═══════════════════════════════════════════════════════════════
--
-- Tables (18):
--   colleges, exam_modes, exam_streams, exam_courses,
--   profiles, teachers, subjects, chapters, topics,
--   questions, tests, teacher_test_assignments,
--   test_questions, test_csv_questions,
--   test_attempts, attempt_answers,
--   whatsapp_share_log, activity_log
--
-- Enums (11):
--   user_role, difficulty_level, test_status, question_status,
--   attempt_status, approval_status, student_plan, test_access_level,
--   assign_type, login_provider, teacher_status
--
-- Functions (8):
--   handle_new_user, generate_test_questions, submit_test_attempt,
--   approve_test, reject_test, update_teacher_permissions,
--   upgrade_student_plan, can_student_access_test
--
-- Helper Functions (3):
--   is_admin, is_teacher, current_teacher_id
--
-- Views (5):
--   question_bank_stats, test_leaderboard, teacher_dashboard_stats,
--   admin_dashboard_overview, pending_approval_tests
--
-- Storage Buckets (2):
--   question-images, college-logos
--
-- Triggers (7):
--   on_auth_user_created, trg_profiles_updated, trg_teachers_updated,
--   trg_questions_updated, trg_tests_updated, trg_colleges_updated,
--   trg_question_count, trg_test_pending_notify
-- ═══════════════════════════════════════════════════════════════
