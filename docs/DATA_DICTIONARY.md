# Database Documentation: NMT 2025 Analytics

> **NMT** — Ukraine's National Multi-subject Test (Національний мультипредметний тест), the standardized university entrance exam.

## 1. Architecture Overview

The database follows a **Star Schema** pattern, normalized to **Third Normal Form (3NF)**.

Instead of a single wide, sparse table (where ~60% of cells were `NULL`), the schema is organized into a central **fact table** (exam results) and several **dimension tables** (participants, institutions, subjects). This structure is optimized for fast aggregations.

---

## 2. Table Reference

### 🔹 `subjects` — Subject Reference Table
Small static dimension table.

| Column | Type | Description |
|---|---|---|
| `subject_code` | `VARCHAR`, PK | Short subject code (e.g. `'Ukr'`, `'Math'`). Used instead of a surrogate `INT` ID for query readability. |
| `subject_name` | `VARCHAR` | Full subject name (Ukrainian). |
| `is_mandatory` | `BOOLEAN` | Flags mandatory subjects. Useful for filtering when comparing only elective subjects. |

### 🔹 `institutions` — Educational Institutions
Dimension table containing unique schools, lyceums, and colleges. Duplicates from the raw source file have been merged using official identifiers and hierarchy.

| Column | Type | Description |
|---|---|---|
| `institution_id` | `SERIAL`, PK | Internal unique ID. |
| `edebo_id` / `edrpou` | `VARCHAR` | Official state identifiers (EDEBO — Unified State Electronic Database on Education, and EDRPOU — Unified State Register of Enterprises and Organizations). |
| `institution_name` | `TEXT` | Institution name. |
| `institution_type` | `VARCHAR` | Institution type (general secondary school, lyceum, etc.). |
| `reg_name`, `area_name`, `ter_name` | `VARCHAR` | Geographic hierarchy (Region → District → City/Village). |

### 🔹 `participants` — Test Participants
Dimension table containing demographic data.

| Column | Type | Description |
|---|---|---|
| `out_id` | `UUID`, PK | Original UCEQA (Ukrainian Center for Educational Quality Assessment) identifier. Using UUID prevents collisions when merging data across multiple years. |
| `birth_year` | `SMALLINT` | Birth year (more storage-efficient than `INT`). |
| `gender` | `VARCHAR` | Gender. |
| `participant_status` | `VARCHAR` | Participant category (current-year graduate, prior-year graduate, etc.). |
| `ter_type` | `VARCHAR` | Territory type (urban/rural). **Key column for inequality analysis** (Urban/Rural gap). |
| `reg_name`, `area_name`, `ter_name` | `VARCHAR` | Participant's place of residence. |
| `institution_id` | `INT`, FK | Reference to school. *Note: `NULL` for prior-year graduates.* |

### 🔹 `exam_results` — Fact Table
Central fact table, built via an **unpivot** transformation — each exam subject taken by a participant is a separate row (1 participant → up to 4 rows).

| Column | Type | Description |
|---|---|---|
| `result_id` | `BIGSERIAL`, PK | Surrogate row key. |
| `out_id` | `UUID`, FK | Who took the exam. |
| `subject_code` | `VARCHAR`, FK | Which subject. |
| `test_date` | `DATE` | Exam date, normalized to ISO format (`YYYY-MM-DD`). |
| `status` | `VARCHAR` | Raw text status (Passed, Cancelled, No-show, etc.). |
| `raw_score` / `scaled_score` | `NUMERIC` | Raw test score (up to ~32) and scaled rating score (100–200). Stored as `NUMERIC(5,2)` to eliminate floating-point rounding errors (unlike `FLOAT` or `REAL`). |
| `is_present` | `BOOLEAN`, `GENERATED ALWAYS AS` | Computed virtual column. Returns `FALSE` when the status matches any variation of "did not appear". |
| `pt_reg_name`, `pt_area_name`, `pt_ter_name` | `VARCHAR` | Location of the testing center (as opposed to the participant's residence). |

---

## 3. Relationships & Constraints

All relationships are designed with referential integrity in mind:

1. **`exam_results.out_id` → `participants.out_id`** (Many-to-one, N:1)
   - **Policy:** `ON DELETE CASCADE` — deleting a participant automatically deletes all their exam results, preventing orphaned rows.

2. **`participants.institution_id` → `institutions.institution_id`** (N:1)
   - **Policy:** `ON DELETE SET NULL` — if an institution is dissolved and removed from the reference table, the participant's history is preserved; the institution field is simply set to `NULL`.

3. **`exam_results.subject_code` → `subjects.subject_code`** (N:1)
   - **Policy:** Strict foreign key enforcement (default behavior).

- Entity Relationship Diagram:
![erd](erd.png)

---

## 4. Indexing & Performance Tuning

PostgreSQL automatically creates indexes only for `PRIMARY KEY` and `UNIQUE` constraints. Indexes on `FOREIGN KEY` columns must be created manually, which has been done here.

- **`idx_exam_results_out_id`** and **`idx_participants_institution_id`**
  B-Tree indexes on foreign keys. These speed up `JOIN` operations by 10–100x on large datasets.

- **`idx_exam_results_subject_score`** (Partial composite index)
  ```sql
  ON exam_results(subject_code, scaled_score) WHERE is_present = TRUE;
  ```
  Built only over rows where the participant actually attended the exam. When computing percentiles, variance, or medians for a given subject, the query can be satisfied entirely from the index (Index-Only Scan) without touching the base table.

- **`idx_participants_ter_type`**
  Speeds up grouping when analyzing the "urban vs. rural" factor's effect on exam performance.
