-- =====================================================================
-- Sukhi Global CRM — Supabase schema
-- Run this first, in the Supabase SQL Editor (or via `supabase db push`).
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Shared trigger: keep updated_at current on every UPDATE
-- ---------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- companies
-- ---------------------------------------------------------------------
create table if not exists companies (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  director       text,
  source_person  text,
  phone          text,
  mobile         text,
  email          text,
  website        text,
  line_id        text,
  country        text,
  location       text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create trigger trg_companies_updated_at
  before update on companies
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- meetings
-- ---------------------------------------------------------------------
create table if not exists meetings (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid references companies(id) on delete cascade,
  title          text not null,
  meeting_date   date not null,
  meeting_time   time,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists idx_meetings_company_id on meetings(company_id);

create trigger trg_meetings_updated_at
  before update on meetings
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- deals  (displayed in the UI as "Deals and Contracts")
-- ---------------------------------------------------------------------
create table if not exists deals (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid references companies(id) on delete cascade,
  visa_type      text check (visa_type in ('Student','Work','Student and Work')),
  stage          text not null default 'active' check (stage in ('active','inactive')),
  fee            text,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists idx_deals_company_id on deals(company_id);

create trigger trg_deals_updated_at
  before update on deals
  for each row execute function set_updated_at();

-- Uploaded agreement files, linked to a deal (metadata only —
-- the actual bytes live in the "deal-agreements" Storage bucket).
create table if not exists deal_files (
  id             uuid primary key default gen_random_uuid(),
  deal_id        uuid not null references deals(id) on delete cascade,
  file_name      text not null,
  storage_path   text not null,
  file_type      text,
  file_size      bigint,
  created_at     timestamptz not null default now()
);

create index if not exists idx_deal_files_deal_id on deal_files(deal_id);

-- ---------------------------------------------------------------------
-- candidates
-- ---------------------------------------------------------------------
create table if not exists candidates (
  id               uuid primary key default gen_random_uuid(),
  company_id       uuid references companies(id) on delete cascade,
  name             text not null,
  phone            text,
  email            text,
  referred_by      text,
  type             text not null default 'student' check (type in ('student','work')),
  school           text,
  interview_date   date,
  interview_time   time,
  country          text,
  ssw_categories   text[] default '{}',
  japanese_cert    text,
  job_category     text,
  sub_category     text,
  notes            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists idx_candidates_company_id on candidates(company_id);

create trigger trg_candidates_updated_at
  before update on candidates
  for each row execute function set_updated_at();

-- Uploaded CV / document files, linked to a candidate (metadata only —
-- the actual bytes live in the "candidate-documents" Storage bucket).
create table if not exists candidate_files (
  id             uuid primary key default gen_random_uuid(),
  candidate_id   uuid not null references candidates(id) on delete cascade,
  file_name      text not null,
  storage_path   text not null,
  file_type      text,
  file_size      bigint,
  created_at     timestamptz not null default now()
);

create index if not exists idx_candidate_files_candidate_id on candidate_files(candidate_id);

-- ---------------------------------------------------------------------
-- interviews
-- ---------------------------------------------------------------------
create table if not exists interviews (
  id                uuid primary key default gen_random_uuid(),
  company_id        uuid references companies(id) on delete cascade,
  candidate_id      uuid references candidates(id) on delete cascade,
  candidate_name    text not null,
  role              text,
  job_category       text,
  job_sub_category   text,
  interview_date    date not null,
  interview_time    time,
  status            text not null default 'scheduled'
                      check (status in ('scheduled','completed','cancelled','transferred','successful','failed')),
  placed_company    text,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists idx_interviews_company_id on interviews(company_id);
create index if not exists idx_interviews_candidate_id on interviews(candidate_id);

create trigger trg_interviews_updated_at
  before update on interviews
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- Notes:
-- * "Deadlines" has NO table — in the UI it is always a computed, read-only
--   rollup of meetings + still-scheduled interviews. Nothing to store.
-- * "Reports" has NO table — it's computed client-side from the tables above.
-- * Google Drive Client ID and GitHub push settings (token/repo/branch/path)
--   are intentionally NOT stored in Supabase — they are per-device
--   integration credentials, not CRM data, and are kept in the browser's
--   localStorage only (see JS section / deployment notes for why).
-- =====================================================================
