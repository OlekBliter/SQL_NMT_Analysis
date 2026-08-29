SET search_path TO nmt_2025, public;

-- Optimize JOINs between participants and exam results
CREATE INDEX IF NOT EXISTS idx_exam_results_out_id 
ON exam_results(out_id);

-- Optimize JOINs between participants and institutions
CREATE INDEX IF NOT EXISTS idx_participants_institution_id 
ON participants(institution_id);

-- Partial composite index for score distributions and aggregations by subject
CREATE INDEX IF NOT EXISTS idx_exam_results_subj_score 
ON exam_results(subject_code, scaled_score) 
WHERE is_present = TRUE;

-- Multi-column index for geographic demographic breakdowns
CREATE INDEX IF NOT EXISTS idx_participants_geo_ter 
ON participants(reg_name, ter_type);

-- Index for examination center mobility queries
CREATE INDEX IF NOT EXISTS idx_exam_results_pt_reg 
ON exam_results(pt_reg_name);