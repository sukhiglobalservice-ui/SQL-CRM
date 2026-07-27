-- =====================================================================
-- Sukhi Global CRM — Row Level Security policies
-- Run this AFTER 01_schema.sql.
-- =====================================================================
--
-- IMPORTANT SECURITY NOTE (read before running):
-- The existing app has no login screen — per your instructions, the UI is
-- not being redesigned to add one. That means the browser talks to Supabase
-- using only the public "anon" (publishable) key, with no signed-in user.
-- For the app to keep working exactly as it does today, these policies
-- grant the "anon" role full read/write access to every CRM table.
--
-- In practice this means: anyone who has your Supabase URL + publishable
-- key (which is visible in your page's source code to any visitor) can
-- read and modify every record. That is fine for a private/internal tool
-- that only trusted staff can reach, but it is NOT safe to put behind a
-- public URL with real candidate data unless you also add a login screen
-- later (Supabase Auth) and tighten these policies to `to authenticated`
-- with a `created_by = auth.uid()` check. That is a larger change than
-- "swap storage for Supabase," so it's flagged here rather than done
-- silently — happy to build it if/when you want it.
-- =====================================================================

alter table companies       enable row level security;
alter table meetings        enable row level security;
alter table deals           enable row level security;
alter table deal_files      enable row level security;
alter table candidates      enable row level security;
alter table candidate_files enable row level security;
alter table interviews      enable row level security;

-- companies
create policy "companies_select" on companies for select to anon, authenticated using (true);
create policy "companies_insert" on companies for insert to anon, authenticated with check (true);
create policy "companies_update" on companies for update to anon, authenticated using (true) with check (true);
create policy "companies_delete" on companies for delete to anon, authenticated using (true);

-- meetings
create policy "meetings_select" on meetings for select to anon, authenticated using (true);
create policy "meetings_insert" on meetings for insert to anon, authenticated with check (true);
create policy "meetings_update" on meetings for update to anon, authenticated using (true) with check (true);
create policy "meetings_delete" on meetings for delete to anon, authenticated using (true);

-- deals
create policy "deals_select" on deals for select to anon, authenticated using (true);
create policy "deals_insert" on deals for insert to anon, authenticated with check (true);
create policy "deals_update" on deals for update to anon, authenticated using (true) with check (true);
create policy "deals_delete" on deals for delete to anon, authenticated using (true);

-- deal_files
create policy "deal_files_select" on deal_files for select to anon, authenticated using (true);
create policy "deal_files_insert" on deal_files for insert to anon, authenticated with check (true);
create policy "deal_files_update" on deal_files for update to anon, authenticated using (true) with check (true);
create policy "deal_files_delete" on deal_files for delete to anon, authenticated using (true);

-- candidates
create policy "candidates_select" on candidates for select to anon, authenticated using (true);
create policy "candidates_insert" on candidates for insert to anon, authenticated with check (true);
create policy "candidates_update" on candidates for update to anon, authenticated using (true) with check (true);
create policy "candidates_delete" on candidates for delete to anon, authenticated using (true);

-- candidate_files
create policy "candidate_files_select" on candidate_files for select to anon, authenticated using (true);
create policy "candidate_files_insert" on candidate_files for insert to anon, authenticated with check (true);
create policy "candidate_files_update" on candidate_files for update to anon, authenticated using (true) with check (true);
create policy "candidate_files_delete" on candidate_files for delete to anon, authenticated using (true);

-- interviews
create policy "interviews_select" on interviews for select to anon, authenticated using (true);
create policy "interviews_insert" on interviews for insert to anon, authenticated with check (true);
create policy "interviews_update" on interviews for update to anon, authenticated using (true) with check (true);
create policy "interviews_delete" on interviews for delete to anon, authenticated using (true);

-- =====================================================================
-- OPTIONAL, FOR LATER: if you add a login screen and want to lock this
-- down to signed-in staff only, drop the policies above and use this
-- pattern instead for each table (shown once here for "companies"):
--
--   drop policy "companies_select" on companies;
--   drop policy "companies_insert" on companies;
--   drop policy "companies_update" on companies;
--   drop policy "companies_delete" on companies;
--
--   create policy "companies_select_auth" on companies
--     for select to authenticated using (true);
--   create policy "companies_write_auth" on companies
--     for all to authenticated using (true) with check (true);
--
-- This removes the "anon" role entirely, so only requests carrying a
-- valid logged-in user's session token would be allowed.
-- =====================================================================
