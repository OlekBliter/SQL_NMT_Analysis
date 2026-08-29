-- Initializes database schema
CREATE SCHEMA IF NOT EXISTS nmt_2025;
SET search_path TO nmt_2025, public;

-- 1. Subject Reference Table
CREATE TABLE subjects (
    subject_code VARCHAR(10) PRIMARY KEY,
    subject_name VARCHAR(100) NOT NULL,
    is_mandatory BOOLEAN NOT NULL DEFAULT FALSE
);

-- Seed dictionary data for all 12 test blocks
INSERT INTO subjects (subject_code, subject_name, is_mandatory) VALUES
('Ukr',    'Ukrainian Language',     TRUE),
('Hist',   'History of Ukraine',     TRUE),
('Math',   'Mathematics',            TRUE),
('Phys',   'Physics',                FALSE),
('Chem',   'Chemistry',              FALSE),
('Bio',    'Biology',                FALSE),
('Geo',    'Geography',              FALSE),
('Eng',    'English Language',       FALSE),
('Fra',    'French Language',        FALSE),
('Deu',    'German Language',        FALSE),
('Spa',    'Spanish Language',       FALSE),
('UkrLit', 'Ukrainian Literature',   FALSE);

-- 2. Educational Institutions Table
CREATE TABLE institutions (
    institution_id SERIAL PRIMARY KEY,
    edebo_id VARCHAR(50),
    edrpou VARCHAR(50),
    institution_name TEXT NOT NULL,
    institution_type VARCHAR(150),
    reg_name VARCHAR(100),
    area_name VARCHAR(100),
    ter_name VARCHAR(100),
    parent_governance TEXT
);

-- 3. Participants Table (Demographics and Residence)
CREATE TABLE participants (
    out_id UUID PRIMARY KEY,
    birth_year SMALLINT,
    gender VARCHAR(15),
    participant_status VARCHAR(100), -- Current year graduate, previous years, etc.
    ter_type VARCHAR(50),            -- Urban (місто) / Rural (село / смт)
    reg_name VARCHAR(100),
    area_name VARCHAR(100),
    ter_name VARCHAR(100),
    institution_id INT REFERENCES institutions(institution_id) ON DELETE SET NULL
);

-- 4. Exam Results Fact Table
CREATE TABLE exam_results (
    result_id BIGSERIAL PRIMARY KEY,
    out_id UUID NOT NULL REFERENCES participants(out_id) ON DELETE CASCADE,
    subject_code VARCHAR(10) NOT NULL REFERENCES subjects(subject_code),
    test_date DATE,
    exam_lang VARCHAR(50),
    status VARCHAR(100),
    raw_score NUMERIC(5, 2),
    scaled_score NUMERIC(5, 2),       -- Scaled score (100 - 200)
    is_present BOOLEAN GENERATED ALWAYS AS (status NOT ILIKE '%не з%яв%') STORED,
    -- Temporary Examination Center (TEC) Geography
    pt_reg_name VARCHAR(100),
    pt_area_name VARCHAR(100),
    pt_ter_name VARCHAR(100)
);