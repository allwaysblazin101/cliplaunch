-- tokens table keyed by mint (text now; switch to base58 check later)
create table if not exists tokens (
  mint           text primary key,
  creator_id     uuid not null references creators(id) on delete cascade,
  symbol         text not null,
  decimals       integer not null check (decimals between 0 and 9),
  initial_supply numeric(39,0) not null,  -- store as integer in base units
  curve          text not null default 'linear-stub',
  created_at     timestamptz not null default now()
);

create index if not exists tokens_creator_idx on tokens(creator_id);
