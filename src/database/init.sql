-- Create landing_coach table if it doesn't exist
CREATE TABLE IF NOT EXISTS landing_coach (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    specialization VARCHAR(50) NOT NULL,
    experience_level VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'new',
    notes TEXT
);

-- Create index on email for faster searching
CREATE INDEX IF NOT EXISTS idx_landing_coach_email ON landing_coach(email);

-- Create index on created_at for faster sorting/filtering
CREATE INDEX IF NOT EXISTS idx_landing_coach_created_at ON landing_coach(created_at);

-- Create index on status for faster filtering
CREATE INDEX IF NOT EXISTS idx_landing_coach_status ON landing_coach(status);

-- Create index on specialization for filtering
CREATE INDEX IF NOT EXISTS idx_landing_coach_specialization ON landing_coach(specialization);

-- Create index on experience_level for filtering
CREATE INDEX IF NOT EXISTS idx_landing_coach_experience ON landing_coach(experience_level);

-- Sample function to help with cleaning up test data (if needed)
CREATE OR REPLACE FUNCTION clear_test_applications() 
RETURNS void AS $$
BEGIN
    DELETE FROM landing_coach WHERE email LIKE '%test%' OR email LIKE '%example%';
END;
$$ LANGUAGE plpgsql;

-- Add comment to table
COMMENT ON TABLE landing_coach IS 'Stores applications for ML, Data Engineering, and DevOps training';
