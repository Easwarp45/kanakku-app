-- ============================================================
-- Kanakku — Supabase Auth Trigger Fix
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================
-- WHY this is needed:
--   The "Database error saving new user" error originates in
--   PostgreSQL, not in Flutter. Supabase Auth fires the
--   on_auth_user_created trigger synchronously during signUp().
--   If the trigger function crashes (wrong metadata key, missing
--   SECURITY DEFINER, or a race with the Flutter-side upsert),
--   the entire auth.users INSERT is rolled back and Supabase
--   returns unexpected_failure to the client.
-- ============================================================

-- Step 1: Remove old trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Step 2: Recreate the trigger function with hardened settings
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER                -- Runs as the function owner (postgres superuser),
                                -- bypasses RLS on public.profiles regardless of
                                -- the caller's role. Without this, anon/service_role
                                -- restrictions may block the insert.
SET search_path = public        -- Prevents search_path hijacking attacks.
AS $$
BEGIN
  INSERT INTO public.profiles (
    user_id,
    display_name,
    language,
    currency,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    -- WHY COALESCE: Flutter sends 'full_name' in data: {'full_name': displayName}.
    -- Other providers (Google, Apple) may send 'name' or 'display_name'.
    -- Falling back to the email prefix ensures display_name is NEVER null,
    -- which prevents NOT NULL constraint failures in the trigger.
    COALESCE(
      NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
      NULLIF(TRIM(NEW.raw_user_meta_data->>'display_name'), ''),
      NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
      split_part(NEW.email, '@', 1)
    ),
    COALESCE(NEW.raw_user_meta_data->>'language', 'en'),
    COALESCE(NEW.raw_user_meta_data->>'currency', 'INR'),
    NOW(),
    NOW()
  )
  -- WHY ON CONFLICT DO NOTHING:
  --   Makes the trigger idempotent. If the Flutter client also tries to
  --   upsert a profile row simultaneously (race condition), the second
  --   insert silently succeeds rather than throwing a unique_violation,
  --   which would cascade into a trigger failure and roll back auth.users.
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Step 3: Reattach trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- RLS Policies for profiles table
-- ============================================================
-- Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- Allow the trigger (SECURITY DEFINER) to insert — no explicit INSERT
-- policy needed because SECURITY DEFINER bypasses RLS entirely.
-- However, if the Flutter client also needs to upsert (e.g. for profile
-- updates after signup), we add a scoped INSERT policy:
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- RLS Policies for expenses table
-- ============================================================
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can select own expenses" ON public.expenses;
CREATE POLICY "Users can select own expenses"
  ON public.expenses FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own expenses" ON public.expenses;
CREATE POLICY "Users can insert own expenses"
  ON public.expenses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own expenses" ON public.expenses;
CREATE POLICY "Users can update own expenses"
  ON public.expenses FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own expenses" ON public.expenses;
CREATE POLICY "Users can delete own expenses"
  ON public.expenses FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- Verify: Run these SELECTs to confirm the trigger is attached
-- ============================================================
-- SELECT trigger_name, event_manipulation, event_object_table
-- FROM information_schema.triggers
-- WHERE trigger_name = 'on_auth_user_created';
--
-- SELECT proname, prosecdef FROM pg_proc WHERE proname = 'handle_new_user';
-- (prosecdef = true means SECURITY DEFINER is set)
