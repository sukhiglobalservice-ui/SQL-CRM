-- =====================================================================
-- Sukhi Global CRM — Add company notes field
-- Run this in the Supabase SQL Editor. Safe to run even if you're not
-- sure whether it's already applied — IF NOT EXISTS makes it a no-op
-- the second time.
--
-- This backs the new "Notes" tab on the company details page: a free-text
-- field for company-specific notes, separate from all other company data.
-- =====================================================================

alter table companies
  add column if not exists notes text;

-- No RLS change needed — the existing companies_auth_all (or
-- companies_select/insert/update/delete) policies already cover every
-- column on this table, including this new one.
