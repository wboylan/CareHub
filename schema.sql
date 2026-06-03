-- CareHub Secure MVP database schema for Supabase PostgreSQL
-- Run this in Supabase SQL Editor, then create a private storage bucket named: care-documents

create extension if not exists pgcrypto;

create type public.family_role as enum ('owner','admin','caregiver','viewer');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  phone text,
  created_at timestamptz default now()
);

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  stripe_customer_id text,
  stripe_subscription_id text,
  subscription_status text default 'free',
  created_at timestamptz default now()
);

create table public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.family_role not null default 'viewer',
  created_at timestamptz default now(),
  unique(family_id, user_id)
);

create table public.parents (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  full_name text not null,
  age text,
  address text,
  emergency_contact text,
  doctor text,
  pharmacy text,
  allergies text,
  care_preferences text,
  created_at timestamptz default now()
);

create table public.medications (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  dosage text,
  frequency text,
  time_of_day text,
  refill_date date,
  notes text,
  created_at timestamptz default now()
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  location text,
  responsible text,
  notes text,
  remind_by_email boolean default false,
  remind_by_sms boolean default false,
  reminder_sent_at timestamptz,
  created_at timestamptz default now()
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null,
  document_type text,
  file_path text,
  original_filename text,
  iv text,
  notes text,
  created_at timestamptz default now()
);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  author_id uuid references auth.users(id) on delete set null,
  body text not null,
  created_at timestamptz default now()
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  email text not null,
  role public.family_role not null default 'viewer',
  token uuid not null unique default gen_random_uuid(),
  invited_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)))
  on conflict (id) do update set email = excluded.email;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_family_member(fid uuid)
returns boolean language sql security definer as $$
  select exists(select 1 from public.family_members where family_id=fid and user_id=auth.uid());
$$;

create or replace function public.has_family_role(fid uuid, allowed public.family_role[])
returns boolean language sql security definer as $$
  select exists(select 1 from public.family_members where family_id=fid and user_id=auth.uid() and role = any(allowed));
$$;

alter table public.profiles enable row level security;
alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.parents enable row level security;
alter table public.medications enable row level security;
alter table public.appointments enable row level security;
alter table public.documents enable row level security;
alter table public.notes enable row level security;
alter table public.invitations enable row level security;

create policy "profiles read by family teammates" on public.profiles for select using (
  id=auth.uid() or exists (
    select 1 from public.family_members mine join public.family_members other on mine.family_id=other.family_id
    where mine.user_id=auth.uid() and other.user_id=profiles.id
  )
);
create policy "profiles update self" on public.profiles for update using (id=auth.uid());

create policy "families read members" on public.families for select using (public.is_family_member(id));
create policy "families insert authenticated" on public.families for insert with check (auth.uid() is not null);
create policy "families update admins" on public.families for update using (public.has_family_role(id, array['owner','admin']::public.family_role[]));

create policy "members read teammates" on public.family_members for select using (public.is_family_member(family_id));
create policy "members insert authenticated" on public.family_members for insert with check (auth.uid() is not null);
create policy "members update owners" on public.family_members for update using (public.has_family_role(family_id, array['owner','admin']::public.family_role[]));
create policy "members delete owners" on public.family_members for delete using (public.has_family_role(family_id, array['owner','admin']::public.family_role[]));

create policy "parents read members" on public.parents for select using (public.is_family_member(family_id));
create policy "parents write editors" on public.parents for all using (public.has_family_role(family_id, array['owner','admin','caregiver']::public.family_role[])) with check (public.has_family_role(family_id, array['owner','admin','caregiver']::public.family_role[]));

create policy "meds read members" on public.medications for select using (public.is_family_member(family_id));
create policy "meds write editors" on public.medications for all using (public.has_family_role(family_id, array['owner','admin','caregiver']::public.family_role[])) with check (public.has_family_role(family_id, array['owner','admin','caregiver']::public.family_role[]));

create policy "appointments read members" on public.appointments for select using (public.is_family_member(family_id));
create policy "appointments write editors" on public.appointments for all using (public.has_family_role(family_id, array['owner','admin','caregiver']::public.family_role[])) with check (public.has_family_role(family_id, array['owner','admin','caregiver']::public.family_role[]));

create policy "documents read members" on public.documents for select using (public.is_family_member(family_id));
create policy "documents write editors" on public.documents for all using (public.has_family_role(family_id, array['owner','admin','caregiver']::public.family_role[])) with check (public.has_family_role(family_id, array['owner','admin','caregiver']::public.family_role[]));

create policy "notes read members" on public.notes for select using (public.is_family_member(family_id));
create policy "notes write members" on public.notes for insert with check (public.is_family_member(family_id));
create policy "notes delete author or admin" on public.notes for delete using (author_id=auth.uid() or public.has_family_role(family_id, array['owner','admin']::public.family_role[]));

create policy "invites read admins or matching email" on public.invitations for select using (
  public.has_family_role(family_id, array['owner','admin']::public.family_role[]) or lower(email)=lower(auth.email())
);
create policy "invites create admins" on public.invitations for insert with check (public.has_family_role(family_id, array['owner','admin']::public.family_role[]));
create policy "invites update admins or invitee" on public.invitations for update using (public.has_family_role(family_id, array['owner','admin']::public.family_role[]) or lower(email)=lower(auth.email()));

-- Storage RLS. Create a private bucket named care-documents first.
create policy "documents object read family" on storage.objects for select using (
  bucket_id='care-documents' and public.is_family_member((storage.foldername(name))[1]::uuid)
);
create policy "documents object insert editors" on storage.objects for insert with check (
  bucket_id='care-documents' and public.has_family_role((storage.foldername(name))[1]::uuid, array['owner','admin','caregiver']::public.family_role[])
);
create policy "documents object delete editors" on storage.objects for delete using (
  bucket_id='care-documents' and public.has_family_role((storage.foldername(name))[1]::uuid, array['owner','admin','caregiver']::public.family_role[])
);
