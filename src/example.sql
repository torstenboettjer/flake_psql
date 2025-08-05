-- Create a test table
CREATE TABLE IF NOT EXISTS hello (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL
);

-- Insert a value
INSERT INTO hello (message) VALUES ('Hello from PL/pgSQL!');

-- View values
SELECT * FROM hello;
