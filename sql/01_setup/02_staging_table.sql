SET search_path TO nmt_2025, public;

-- Creates an untyped staging table for raw CSV bulk ingestion.
-- Use UNLOGGED table to speed up write operations (bypasses WAL logs)
CREATE UNLOGGED TABLE staging_nmt_raw (
    outid TEXT,
    birth TEXT,
    sex_type_name TEXT,
    reg_name TEXT,
    area_name TEXT,
    ter_name TEXT,
    reg_type_name TEXT,
    ter_type_name TEXT,
    eo_name TEXT,
    eo_type_name TEXT,
    eo_reg_name TEXT,
    eo_area_name TEXT,
    eo_ter_name TEXT,
    eo_parent TEXT,
    eo_edrpou TEXT,
    eo_edeboid TEXT,
    test TEXT,
    test_date TEXT,
    -- 12 Subject blocks
    ukr_block TEXT, ukr_status TEXT, ukr_ball100 TEXT, ukr_ball TEXT,
    hist_block TEXT, hist_lang TEXT, hist_status TEXT, hist_ball100 TEXT, hist_ball TEXT,
    math_block TEXT, math_lang TEXT, math_status TEXT, math_ball100 TEXT, math_ball TEXT,
    phys_block TEXT, phys_lang TEXT, phys_status TEXT, phys_ball100 TEXT, phys_ball TEXT,
    chem_block TEXT, chem_lang TEXT, chem_status TEXT, chem_ball100 TEXT, chem_ball TEXT,
    bio_block TEXT, bio_lang TEXT, bio_status TEXT, bio_ball100 TEXT, bio_ball TEXT,
    geo_block TEXT, geo_lang TEXT, geo_status TEXT, geo_ball100 TEXT, geo_ball TEXT,
    eng_block TEXT, eng_status TEXT, eng_ball100 TEXT, eng_ball TEXT,
    fra_block TEXT, fra_status TEXT, fra_ball100 TEXT, fra_ball TEXT,
    deu_block TEXT, deu_status TEXT, deu_ball100 TEXT, deu_ball TEXT,
    spa_block TEXT, spa_status TEXT, spa_ball100 TEXT, spa_ball TEXT,
    ukrlit_block TEXT, ukrlit_status TEXT, ukrlit_ball100 TEXT, ukrlit_ball TEXT,
    -- Examination center
    pt_reg_name TEXT,
    pt_area_name TEXT,
    pt_ter_name TEXT
);

-- Note: Run the following psql meta-command in terminal/psql console:
-- \copy nmt_2025.staging_nmt_raw FROM '/data/raw/Odata2025File.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', QUOTE '"', ENCODING 'UTF-8');