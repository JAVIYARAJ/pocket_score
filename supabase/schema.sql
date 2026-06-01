-- ============================================================
--  Pocket Score – Supabase Database Schema
--  Run this in the Supabase SQL Editor (one-shot)
-- ============================================================

-- ── 1. Profiles (mirrors auth.users) ───────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT,
  full_name   TEXT,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create a profile row whenever a user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_own" ON public.profiles
  FOR ALL USING (auth.uid() = id);


-- ── 2. Players ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.players (
  id          TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'batsman',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
CREATE POLICY "players_own" ON public.players
  FOR ALL USING (auth.uid() = user_id);


-- ── 3. Matches ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.matches (
  id               TEXT PRIMARY KEY,
  user_id          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  team_a_name      TEXT NOT NULL,
  team_b_name      TEXT NOT NULL,
  team_a           JSONB,
  team_b           JSONB,
  total_overs      INTEGER NOT NULL DEFAULT 5,
  status           TEXT NOT NULL DEFAULT 'setup',
  result           TEXT,
  team_a_score     INTEGER,
  team_a_wickets   INTEGER,
  team_a_overs     TEXT,
  team_b_score     INTEGER,
  team_b_wickets   INTEGER,
  team_b_overs     TEXT,
  score_data       JSONB,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- Users manage their own; everyone can read (public scorecard sharing)
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "matches_read_all"  ON public.matches FOR SELECT USING (true);
CREATE POLICY "matches_write_own" ON public.matches FOR ALL    USING (auth.uid() = user_id);


-- ── 4. Live Scores (realtime channel) ──────────────────────
-- One row per live match – updated on every ball delivery
CREATE TABLE IF NOT EXISTS public.live_scores (
  match_id     TEXT PRIMARY KEY REFERENCES public.matches(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score_state  JSONB NOT NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.live_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "live_scores_read_all"  ON public.live_scores FOR SELECT USING (true);
CREATE POLICY "live_scores_write_own" ON public.live_scores FOR ALL    USING (auth.uid() = user_id);


-- ── 5. Player Match Stats (relational per-player-per-innings stats) ─
-- One row per player per innings. Avoids storing all stats in JSONB blobs.
-- player_id is TEXT (matches the timestamp-based IDs used by the app).
CREATE TABLE IF NOT EXISTS public.player_match_stats (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id      TEXT    NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  player_id     TEXT    NOT NULL,          -- references players.id (TEXT); no FK so deleting a player keeps history
  player_name   TEXT,                      -- denormalised for display without extra joins
  user_id       UUID    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  innings_num   INTEGER NOT NULL CHECK (innings_num IN (1, 2)),
  -- Batting
  runs          INTEGER NOT NULL DEFAULT 0,
  balls_faced   INTEGER NOT NULL DEFAULT 0,
  fours         INTEGER NOT NULL DEFAULT 0,
  sixes         INTEGER NOT NULL DEFAULT 0,
  is_out        BOOLEAN NOT NULL DEFAULT false,
  wicket_type   TEXT,
  -- Bowling
  balls_bowled  INTEGER NOT NULL DEFAULT 0,
  runs_conceded INTEGER NOT NULL DEFAULT 0,
  wickets_taken INTEGER NOT NULL DEFAULT 0,
  wides         INTEGER NOT NULL DEFAULT 0,
  no_balls      INTEGER NOT NULL DEFAULT 0,
  dot_balls     INTEGER NOT NULL DEFAULT 0,
  -- Fielding
  catches       INTEGER NOT NULL DEFAULT 0,
  run_outs      INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (match_id, player_id, innings_num)
);

ALTER TABLE public.player_match_stats ENABLE ROW LEVEL SECURITY;
-- Owner can manage; everyone can read (public scorecard sharing)
CREATE POLICY "pms_write_own" ON public.player_match_stats
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "pms_read_all"  ON public.player_match_stats
  FOR SELECT USING (true);

CREATE TRIGGER pms_updated_at
  BEFORE UPDATE ON public.player_match_stats
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── 6. Enable Realtime on live_scores + matches ─────────────
-- Run AFTER creating the tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.live_scores;
ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;


-- ── 6. Handy auto-update for updated_at ────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER matches_updated_at
  BEFORE UPDATE ON public.matches
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER live_scores_updated_at
  BEFORE UPDATE ON public.live_scores
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ═══════════════════════════════════════════════════════════
-- GROUP FEATURE  (added 2026-05)
-- ═══════════════════════════════════════════════════════════

-- ── 7. groups ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.groups (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,
  invite_code  TEXT NOT NULL UNIQUE,
  created_by   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE TRIGGER groups_updated_at BEFORE UPDATE ON public.groups
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "groups_read_auth"  ON public.groups FOR SELECT  USING (auth.role() = 'authenticated');
CREATE POLICY "groups_write_own"  ON public.groups FOR ALL     USING (auth.uid() = created_by);
CREATE POLICY "groups_insert"     ON public.groups FOR INSERT  WITH CHECK (auth.uid() = created_by);
ALTER PUBLICATION supabase_realtime ADD TABLE public.groups;

-- ── 8. group_members ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.group_members (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role       TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (group_id, user_id)
);
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "group_members_read" ON public.group_members FOR SELECT USING (
  auth.uid() = user_id OR
  EXISTS (SELECT 1 FROM public.group_members gm2
          WHERE gm2.group_id = group_members.group_id AND gm2.user_id = auth.uid())
);
CREATE POLICY "group_members_insert"     ON public.group_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "group_members_delete_own" ON public.group_members FOR DELETE USING  (auth.uid() = user_id);

-- ── 9. group_id column on matches ───────────────────────────
ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS matches_group_id_idx ON public.matches (group_id);

-- ── 10. Max Overs Per Bowler (added 2026-06) ────────────────
ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS max_overs_per_bowler INTEGER;
