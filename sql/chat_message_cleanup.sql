create extension if not exists pg_cron;

select cron.schedule(
  'delete_old_messages',
  '0 * * * *',
  $$ delete from chat_messages
     where created_at < now() - interval '48 hours' $$
);
