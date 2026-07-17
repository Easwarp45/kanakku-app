-- Supabase Schema Initialization Script for Kanakku App
-- Run this script in the Supabase SQL Editor to set up all tables, enums, constraints, triggers, and RLS policies.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ENUMS CREATION
-- ─────────────────────────────────────────────────────────────────────────────

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'expense_category') THEN
    CREATE TYPE expense_category AS ENUM (
      'food',
      'transport',
      'entertainment',
      'health',
      'shopping',
      'education',
      'travel',
      'bills',
      'other'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method') THEN
    CREATE TYPE payment_method AS ENUM (
      'upi',
      'cash',
      'card',
      'bank_transfer',
      'other'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'income_source') THEN
    CREATE TYPE income_source AS ENUM (
      'salary',
      'freelance',
      'business',
      'investment',
      'gift',
      'refund',
      'other'
    );
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. TABLES CREATION
-- ─────────────────────────────────────────────────────────────────────────────

-- 2.1. Profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  phone_number TEXT,
  avatar_url TEXT,
  language TEXT DEFAULT 'en',
  currency TEXT DEFAULT 'INR',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.2. Groups
CREATE TABLE IF NOT EXISTS public.groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  created_by UUID REFERENCES public.profiles(user_id) ON DELETE SET NULL,
  invite_code VARCHAR(8) UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.3. Group Members
CREATE TABLE IF NOT EXISTS public.group_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  nickname TEXT,
  joined_at TIMESTAMPTZ DEFAULT now(),
  is_admin BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(group_id, user_id)
);

-- 2.4. Group Expenses
CREATE TABLE IF NOT EXISTS public.group_expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  paid_by UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  description TEXT,
  category expense_category NOT NULL DEFAULT 'other',
  expense_date DATE DEFAULT CURRENT_DATE,
  split_type TEXT NOT NULL DEFAULT 'equal' CHECK (split_type IN ('equal', 'custom')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.5. Expense Splits
CREATE TABLE IF NOT EXISTS public.expense_splits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_expense_id UUID NOT NULL REFERENCES public.group_expenses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  is_settled BOOLEAN DEFAULT false,
  settled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(group_expense_id, user_id)
);

-- 2.6. Settlements
CREATE TABLE IF NOT EXISTS public.settlements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  paid_by UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  paid_to UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  note TEXT,
  settled_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2.7. Group Chats
CREATE TABLE IF NOT EXISTS public.group_chats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  client_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.8. Expenses (Personal)
CREATE TABLE IF NOT EXISTS public.expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  category expense_category NOT NULL DEFAULT 'other',
  description TEXT,
  payment_method payment_method NOT NULL DEFAULT 'upi',
  expense_date DATE DEFAULT CURRENT_DATE,
  receipt_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.9. Income (Personal)
CREATE TABLE IF NOT EXISTS public.income (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  source income_source NOT NULL DEFAULT 'other',
  description TEXT,
  income_date DATE DEFAULT CURRENT_DATE,
  is_recurring BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.10. Budgets (Personal)
CREATE TABLE IF NOT EXISTS public.budgets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  period TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, category, period)
);

-- 2.11. Financial Goals (Personal)
CREATE TABLE IF NOT EXISTS public.financial_goals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  target_amount NUMERIC(12, 2) NOT NULL CHECK (target_amount >= 0),
  current_saved NUMERIC(12, 2) DEFAULT 0 CHECK (current_saved >= 0),
  deadline DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. TRIGGERS FOR PROFILES AUTOMATION
-- ─────────────────────────────────────────────────────────────────────────────

-- Automatically create a public profile entry when a new user signs up in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, display_name, language, currency)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'display_name', 'User'),
    'en',
    'INR'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger cleanly
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Automatically update updated_at timestamps on changes
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply timestamp auto-updating triggers to tables that have updated_at
CREATE OR REPLACE TRIGGER update_profiles_modtime BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE OR REPLACE TRIGGER update_groups_modtime BEFORE UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE OR REPLACE TRIGGER update_group_expenses_modtime BEFORE UPDATE ON public.group_expenses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE OR REPLACE TRIGGER update_group_chats_modtime BEFORE UPDATE ON public.group_chats FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE OR REPLACE TRIGGER update_expenses_modtime BEFORE UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE OR REPLACE TRIGGER update_income_modtime BEFORE UPDATE ON public.income FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE OR REPLACE TRIGGER update_budgets_modtime BEFORE UPDATE ON public.budgets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE OR REPLACE TRIGGER update_financial_goals_modtime BEFORE UPDATE ON public.financial_goals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ─────────────────────────────────────────────────────────────────────────────

-- Enable RLS for all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.income ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_goals ENABLE ROW LEVEL SECURITY;

-- 4.1. Profiles policies
DROP POLICY IF EXISTS "Allow authenticated users to read all profiles" ON public.profiles;
CREATE POLICY "Allow authenticated users to read all profiles" ON public.profiles
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow users to update own profile" ON public.profiles;
CREATE POLICY "Allow users to update own profile" ON public.profiles
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow users to insert own profile (recovery)" ON public.profiles;
CREATE POLICY "Allow users to insert own profile (recovery)" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- 4.2. Groups policies
DROP POLICY IF EXISTS "Allow members to view groups they belong to" ON public.groups;
CREATE POLICY "Allow members to view groups they belong to" ON public.groups
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = id AND group_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Allow authenticated users to create a group" ON public.groups;
CREATE POLICY "Allow authenticated users to create a group" ON public.groups
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "Allow creator/admin to update group" ON public.groups;
CREATE POLICY "Allow creator/admin to update group" ON public.groups
  FOR UPDATE TO authenticated USING (
    auth.uid() = created_by OR 
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = id AND group_members.user_id = auth.uid() AND group_members.is_admin = true
    )
  );

DROP POLICY IF EXISTS "Allow creator/admin to delete group" ON public.groups;
CREATE POLICY "Allow creator/admin to delete group" ON public.groups
  FOR DELETE TO authenticated USING (
    auth.uid() = created_by OR 
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = id AND group_members.user_id = auth.uid() AND group_members.is_admin = true
    )
  );

-- 4.3. Group Members policies
DROP POLICY IF EXISTS "Allow group members to view membership lists" ON public.group_members;
CREATE POLICY "Allow group members to view membership lists" ON public.group_members
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow users to join via invite code or admins to add members" ON public.group_members;
CREATE POLICY "Allow users to join via invite code or admins to add members" ON public.group_members
  FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.group_members AS gm 
      WHERE gm.group_id = group_id AND gm.user_id = auth.uid() AND gm.is_admin = true
    )
  );

DROP POLICY IF EXISTS "Allow admins to update member settings" ON public.group_members;
CREATE POLICY "Allow admins to update member settings" ON public.group_members
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.group_members AS gm 
      WHERE gm.group_id = group_id AND gm.user_id = auth.uid() AND gm.is_admin = true
    )
  );

DROP POLICY IF EXISTS "Allow users to leave or admins to remove members" ON public.group_members;
CREATE POLICY "Allow users to leave or admins to remove members" ON public.group_members
  FOR DELETE TO authenticated USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.group_members AS gm 
      WHERE gm.group_id = group_id AND gm.user_id = auth.uid() AND gm.is_admin = true
    )
  );

-- 4.4. Group Expenses policies
DROP POLICY IF EXISTS "Allow members to view group expenses" ON public.group_expenses;
CREATE POLICY "Allow members to view group expenses" ON public.group_expenses
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = group_id AND group_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Allow members to add group expenses" ON public.group_expenses;
CREATE POLICY "Allow members to add group expenses" ON public.group_expenses
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = group_id AND group_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Allow payer or admin to update group expenses" ON public.group_expenses;
CREATE POLICY "Allow payer or admin to update group expenses" ON public.group_expenses
  FOR UPDATE TO authenticated USING (
    auth.uid() = paid_by OR
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = group_id AND group_members.user_id = auth.uid() AND group_members.is_admin = true
    )
  );

DROP POLICY IF EXISTS "Allow payer or admin to delete group expenses" ON public.group_expenses;
CREATE POLICY "Allow payer or admin to delete group expenses" ON public.group_expenses
  FOR DELETE TO authenticated USING (
    auth.uid() = paid_by OR
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = group_id AND group_members.user_id = auth.uid() AND group_members.is_admin = true
    )
  );

-- 4.5. Expense Splits policies
DROP POLICY IF EXISTS "Allow members to view splits" ON public.expense_splits;
CREATE POLICY "Allow members to view splits" ON public.expense_splits
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.group_expenses AS ge
      JOIN public.group_members AS gm ON ge.group_id = gm.group_id
      WHERE ge.id = group_expense_id AND gm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Allow group members to insert/update splits" ON public.expense_splits;
CREATE POLICY "Allow group members to insert/update splits" ON public.expense_splits
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.group_expenses AS ge
      JOIN public.group_members AS gm ON ge.group_id = gm.group_id
      WHERE ge.id = group_expense_id AND gm.user_id = auth.uid()
    )
  );

-- 4.6. Settlements policies
DROP POLICY IF EXISTS "Allow members to view settlements" ON public.settlements;
CREATE POLICY "Allow members to view settlements" ON public.settlements
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = group_id AND group_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Allow members to record settlements" ON public.settlements;
CREATE POLICY "Allow members to record settlements" ON public.settlements
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = group_id AND group_members.user_id = auth.uid()
    )
  );

-- 4.7. Group Chats policies
DROP POLICY IF EXISTS "Allow members to view chats" ON public.group_chats;
CREATE POLICY "Allow members to view chats" ON public.group_chats
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = group_id AND group_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Allow members to send chat messages" ON public.group_chats;
CREATE POLICY "Allow members to send chat messages" ON public.group_chats
  FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM public.group_members 
      WHERE group_members.group_id = group_id AND group_members.user_id = auth.uid()
    )
  );

-- 4.8. Personal Expenses policies
DROP POLICY IF EXISTS "Users can manage own personal expenses" ON public.expenses;
CREATE POLICY "Users can manage own personal expenses" ON public.expenses
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 4.9. Personal Income policies
DROP POLICY IF EXISTS "Users can manage own personal income" ON public.income;
CREATE POLICY "Users can manage own personal income" ON public.income
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 4.10. Budgets policies
DROP POLICY IF EXISTS "Users can manage own budgets" ON public.budgets;
CREATE POLICY "Users can manage own budgets" ON public.budgets
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 4.11. Financial Goals policies
DROP POLICY IF EXISTS "Users can manage own financial goals" ON public.financial_goals;
CREATE POLICY "Users can manage own financial goals" ON public.financial_goals
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 5. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL, -- 'morning_brief', 'evening_summary', 'budget_alert', 'goal_alert', 'group_alert', 'settlement_alert', 'offline_sync', 'monthly_report', 'weekly_summary'
  priority TEXT NOT NULL DEFAULT 'medium', -- 'low', 'medium', 'high'
  payload JSONB,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
  read_at TIMESTAMP WITH TIME ZONE,
  scheduled_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  source TEXT NOT NULL DEFAULT 'local' -- 'local' or 'push'
);

-- Indexing for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own notifications" ON public.notifications;
CREATE POLICY "Users can manage own notifications" ON public.notifications
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Triggers for automatic group activity alerts
CREATE OR REPLACE FUNCTION public.on_group_chat_inserted()
RETURNS TRIGGER AS $$
DECLARE
  member_record RECORD;
  sender_name TEXT;
BEGIN
  SELECT COALESCE(nickname, display_name, 'Someone') INTO sender_name
  FROM public.profiles p
  LEFT JOIN public.group_members gm ON gm.user_id = p.user_id AND gm.group_id = NEW.group_id
  WHERE p.user_id = NEW.user_id;

  FOR member_record IN 
    SELECT user_id FROM public.group_members 
    WHERE group_id = NEW.group_id AND user_id != NEW.user_id
  LOOP
    INSERT INTO public.notifications (user_id, title, body, type, priority, payload, source)
    VALUES (
      member_record.user_id,
      'New Message',
      sender_name || ': ' || substring(NEW.message from 1 for 60),
      'group_alert',
      'low',
      jsonb_build_object('group_id', NEW.group_id, 'chat_id', NEW.id),
      'local'
    );
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_group_chat_inserted ON public.group_chats;
CREATE TRIGGER tr_group_chat_inserted
  AFTER INSERT ON public.group_chats
  FOR EACH ROW EXECUTE FUNCTION public.on_group_chat_inserted();

CREATE OR REPLACE FUNCTION public.on_group_expense_inserted()
RETURNS TRIGGER AS $$
DECLARE
  member_record RECORD;
  payer_name TEXT;
  group_name TEXT;
BEGIN
  SELECT name INTO group_name FROM public.groups WHERE id = NEW.group_id;
  SELECT COALESCE(nickname, display_name, 'Someone') INTO payer_name
  FROM public.profiles p
  LEFT JOIN public.group_members gm ON gm.user_id = p.user_id AND gm.group_id = NEW.group_id
  WHERE p.user_id = NEW.paid_by;

  FOR member_record IN 
    SELECT user_id FROM public.group_members 
    WHERE group_id = NEW.group_id AND user_id != NEW.paid_by
  LOOP
    INSERT INTO public.notifications (user_id, title, body, type, priority, payload, source)
    VALUES (
      member_record.user_id,
      'Group Expense Added',
      payer_name || ' added "' || NEW.description || '" in ' || group_name,
      'group_alert',
      'medium',
      jsonb_build_object('group_id', NEW.group_id, 'expense_id', NEW.id),
      'local'
    );
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_group_expense_inserted ON public.group_expenses;
CREATE TRIGGER tr_group_expense_inserted
  AFTER INSERT ON public.group_expenses
  FOR EACH ROW EXECUTE FUNCTION public.on_group_expense_inserted();

CREATE OR REPLACE FUNCTION public.on_settlement_inserted()
RETURNS TRIGGER AS $$
DECLARE
  payer_name TEXT;
  group_name TEXT;
BEGIN
  SELECT name INTO group_name FROM public.groups WHERE id = NEW.group_id;
  SELECT COALESCE(nickname, display_name, 'Someone') INTO payer_name
  FROM public.profiles p
  LEFT JOIN public.group_members gm ON gm.user_id = p.user_id AND gm.group_id = NEW.group_id
  WHERE p.user_id = NEW.paid_by;

  INSERT INTO public.notifications (user_id, title, body, type, priority, payload, source)
  VALUES (
    NEW.paid_to,
    'Settlement Received',
    payer_name || ' paid you in ' || group_name,
    'settlement_alert',
    'high',
    jsonb_build_object('group_id', NEW.group_id, 'settlement_id', NEW.id),
    'local'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_settlement_inserted ON public.settlements;
CREATE TRIGGER tr_settlement_inserted
  AFTER INSERT ON public.settlements
  FOR EACH ROW EXECUTE FUNCTION public.on_settlement_inserted();
