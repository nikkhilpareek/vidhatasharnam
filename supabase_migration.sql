-- Migration: Add isApproved column to users table
-- Run this in Supabase SQL Editor

-- Add isApproved column if it doesn't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS "isApproved" BOOLEAN DEFAULT false;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_users_isApproved ON users("isApproved");

-- Update existing users to be approved by default (optional - adjust based on your needs)
-- Uncomment the line below if you want all existing users to be approved
-- UPDATE users SET "isApproved" = true WHERE "isApproved" IS NULL;

-- Verify the column was added
-- SELECT column_name, data_type, column_default 
-- FROM information_schema.columns 
-- WHERE table_name = 'users' AND column_name = 'isApproved';

