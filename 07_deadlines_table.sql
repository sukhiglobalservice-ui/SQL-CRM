-- =====================================================================
-- Sukhi Global CRM — Manual deadlines table
-- Run this in the Supabase SQL Editor.
--
-- The Deadlines tab already showed an automatic, read-only rollup of
-- Meeting dates and still-scheduled Interview dates — that behavior is
-- unchanged and needs no table (it's computed live in the browser).
-- This table adds the other half: deadlines you enter directly, with
-- full create/edit/delete, that persist like every other record type.
-- =====================================================================

create table if not exists deadlines (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid references companies(id) on delete cascade,
  title        text not null,
  due_date     date not null,
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_deadlines_company_id on deadlines(company_id);

create trigger trg_deadlines_updated_at
  before update on deadlines
  for each row execute function set_updated_at();

alter table deadlines enable row level security;

create policy "deadlines_auth_all" on deadlines
  for all to authenticated using (true) with check (true);
