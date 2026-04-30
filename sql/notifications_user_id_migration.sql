-- Compatibility-first migration for the notifications table.
-- Adds user_id for the new app code while keeping recipient_id working
-- during rollout for older clients and existing insert paths.

ALTER TABLE public.notifications
ADD COLUMN IF NOT EXISTS user_id uuid;

UPDATE public.notifications
SET user_id = COALESCE(user_id, recipient_id)
WHERE user_id IS NULL;

ALTER TABLE public.notifications
ALTER COLUMN user_id SET NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_notification_user_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.user_id := COALESCE(NEW.user_id, NEW.recipient_id);
    NEW.recipient_id := COALESCE(NEW.recipient_id, NEW.user_id);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notifications_sync_user_columns ON public.notifications;

CREATE TRIGGER notifications_sync_user_columns
BEFORE INSERT OR UPDATE ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.sync_notification_user_columns();

CREATE INDEX IF NOT EXISTS notifications_user_id_idx
ON public.notifications (user_id);

CREATE INDEX IF NOT EXISTS notifications_created_at_idx
ON public.notifications (created_at DESC);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;

CREATE POLICY "Users can delete own notifications"
ON public.notifications
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);
