-- =====================================================================
-- Sukhi Global CRM — Company Notes table
-- Run this in the Supabase SQL Editor.
--
-- This replaces the earlier single-textarea "notes" column approach
-- (companies.notes, added in 05_add_company_notes.sql) with a proper
-- multi-entry notes system: each note is its own row, timestamped,
-- editable, and deletable independently — matching the new Notes tab.
--
-- The old companies.notes column is left in place (harmless, just
-- unused now) rather than dropped, to avoid any destructive migration.
-- =====================================================================

create table if not exists company_notes (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references companies(id) on delete cascade,
  content      text not null default '',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_company_notes_company_id on company_notes(company_id);

create trigger trg_company_notes_updated_at
  before update on company_notes
  for each row execute function set_updated_at();

alter table company_notes enable row level security;

create policy "company_notes_auth_all" on company_notes
  for all to authenticated using (true) with check (true);
