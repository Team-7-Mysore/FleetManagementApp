-- Migration: Add id and part_name columns to work_order_parts table
-- This allows storing parts directly without requiring inventory lookup

-- Step 1: Add the new columns
ALTER TABLE public.work_order_parts
ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid(),
ADD COLUMN IF NOT EXISTS part_name character varying;

-- Step 2: Add primary key constraint on id
ALTER TABLE public.work_order_parts
ADD CONSTRAINT work_order_parts_pkey PRIMARY KEY (id);

-- Step 3: Make part_name NOT NULL (after adding the column)
-- Note: If you have existing data, you'll need to populate part_name first
-- UPDATE public.work_order_parts SET part_name = 'Unknown Part' WHERE part_name IS NULL;
ALTER TABLE public.work_order_parts
ALTER COLUMN part_name SET NOT NULL;

-- Step 4: Add foreign key constraint for work_order_id if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'work_order_parts_work_order_id_fkey'
    ) THEN
        ALTER TABLE public.work_order_parts
        ADD CONSTRAINT work_order_parts_work_order_id_fkey 
        FOREIGN KEY (work_order_id) REFERENCES public.work_orders(work_order_id);
    END IF;
END $$;

-- Optional: Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_work_order_parts_work_order_id 
ON public.work_order_parts(work_order_id);

-- Verify the changes
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'work_order_parts'
ORDER BY ordinal_position;
