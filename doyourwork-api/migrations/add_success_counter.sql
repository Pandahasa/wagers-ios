-- Add successful wagers count column to Users table
-- Run this migration to add the success counter feature

ALTER TABLE Users 
ADD COLUMN successful_wagers_count INT DEFAULT 0 NOT NULL;

-- Optional: Update existing users to have accurate counts based on historical data
UPDATE Users u
SET successful_wagers_count = (
    SELECT COUNT(*) 
    FROM Wagers w 
    WHERE w.pledger_id = u.id 
    AND w.status = 'completed_success'
);
