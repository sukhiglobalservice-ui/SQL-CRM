-- =====================================================================
-- Sukhi Global CRM — Authenticated-only RLS policies
-- Run this AFTER 01_schema.sql, instead of the old anon-friendly
-- 02_rls_policies.sql (or after it, to replace those policies).
--
-- Now that the app has a real login screen (Supabase Auth), there is no
-- reason to keep letting the public "anon" key read/write your data.
-- This file drops every "anon, authenticated" policy from
-- 02_rls_policies.sql and replaces it with "authenticated" only —
-- meaning a valid, signed-in user session is required for every
-- database and Storage operation. Anyone without an account (or who
-- hasn't signed in) gets nothing.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Drop the old anon-friendly policies
-- ---------------------------------------------------------------------
drop policy if exists "companies_select" on companies;
drop policy if exists "companies_insert" on companies;
drop policy if exists "companies_update" on companies;
drop policy if exists "companies_delete" on companies;

drop policy if exists "meetings_select" on meetings;
drop policy if exists "meetings_insert" on meetings;
drop policy if exists "meetings_update" on meetings;
drop policy if exists "meetings_delete" on meetings;

drop policy if exists "deals_select" on deals;
drop policy if exists "deals_insert" on deals;
drop policy if exists "deals_update" on deals;
drop policy if exists "deals_delete" on deals;

drop policy if exists "deal_files_select" on deal_files;
drop policy if exists "deal_files_insert" on deal_files;
drop policy if exists "deal_files_update" on deal_files;
drop policy if exists "deal_files_delete" on deal_files;

drop policy if exists "candidates_select" on candidates;
drop policy if exists "candidates_insert" on candidates;
drop policy if exists "candidates_update" on candidates;
drop policy if exists "candidates_delete" on candidates;

drop policy if exists "candidate_files_select" on candidate_files;
drop policy if exists "candidate_files_insert" on candidate_files;
drop policy if exists "candidate_files_update" on candidate_files;
drop policy if exists "candidate_files_delete" on candidate_files;

drop policy if exists "interviews_select" on interviews;
drop policy if exists "interviews_insert" on interviews;
drop policy if exists "interviews_update" on interviews;
drop policy if exists "interviews_delete" on interviews;

drop policy if exists "candidate_documents_select" on storage.objects;
drop policy if exists "candidate_documents_insert" on storage.objects;
drop policy if exists "candidate_documents_update" on storage.objects;
drop policy if exists "candidate_documents_delete" on storage.objects;

drop policy if exists "deal_agreements_select" on storage.objects;
drop policy if exists "deal_agreements_insert" on storage.objects;
drop policy if exists "deal_agreements_update" on storage.objects;
drop policy if exists "deal_agreements_delete" on storage.objects;

-- ---------------------------------------------------------------------
-- Authenticated-only replacements
-- ---------------------------------------------------------------------
create policy "companies_all_auth" on companies for all to authenticated using (true) with check (true);
create policy "meetings_all_auth" on meetings for all to authenticated using (true) with check (true);
create policy "deals_all_auth" on deals for all to authenticated using (true) with check (true);
create policy "deal_files_all_auth" on deal_files for all to authenticated using (true) with check (true);
create policy "candidates_all_auth" on candidates for all to authenticated using (true) with check (true);
create policy "candidate_files_all_auth" on candidate_files for all to authenticated using (true) with check (true);
create policy "interviews_all_auth" on interviews for all to authenticated using (true) with check (true);

create policy "candidate_documents_all_auth" on storage.objects for all to authenticated
  using (bucket_id = 'candidate-documents') with check (bucket_id = 'candidate-documents');
create policy "deal_agreements_all_auth" on storage.objects for all to authenticated
  using (bucket_id = 'deal-agreements') with check (bucket_id = 'deal-agreements');

-- ---------------------------------------------------------------------
-- Creating user accounts
-- ---------------------------------------------------------------------
-- There is no public sign-up form in the app on purpose — accounts are
-- created by you, the administrator, so only people you've explicitly
-- given access can sign in:
--
--   Supabase Dashboard → Authentication → Users → Add user
--
-- Set an email + password (or "send invite" for the user to set their
-- own password). That's it — they can then sign in through the app's
-- login screen immediately, no further setup needed.
-- =====================================================================
