-- Run ONLY this first (unblocks signup diagnosis):
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
