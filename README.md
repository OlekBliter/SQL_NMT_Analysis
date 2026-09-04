# NMT 2025 Analytics: Deep-Dive Examination & Educational Inequality Analysis in PostgreSQL

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15%2B-336791?logo=postgresql&logoColor=white)
![SQL Only](https://img.shields.io/badge/Analytics-100%25%20SQL-informational)

> The analysis of the results of the **National Multi-Subject Test (NMT) 2025** — the entrance exam to Ukrainian higher education institutions — was performed entirely using pure PostgreSQL.

## Executive Summary

Standardized testing is usually measured superficially—through regional or subject averages. This study sets a different goal: **finding hidden structural patterns** in how test date, geography, institution type, and choice of 4th subject shape outcome inequality—and separating real effects from statistical artifacts (sampling bias, uneven distribution of subjects across sessions, etc.).

- **Sample size:** 317,091 participants, 19 test sessions (May–July 2025).
- **Approach:** full cycle — from raw UCEQA data to normalized 3NF schema, analytical `VIEW`-storefronts and 5 independent research SQL scripts.
- **Stack:** PostgreSQL 15+, pure Analytical SQL, data modeling (Star Schema, Views/Marts).

---

## 1. Data Architecture

Instead of one wide "floating" table (where ~60% of the cells would be `NULL` due to different number of items for different participants), the data is organized in a **Star Schema**, normalized to **3NF**:

- **`participants`** / **`institutions`** / **`subjects`** — dimension tables (dimensions).
- **`exam_results`** — central fact table obtained `unpivot`-transformation (1 participant → up to 4 lines, one per subject).

A complete description of tables, relationships, and indexes is in [`docs/DATA_DICTIONARY.md`](docs/DATA_DICTIONARY.md). ERD diagram:

![ERD](docs/erd.png)

Two analytical layers (**Data Marts**) are built on top of the fact table so that research scripts do not duplicate the same logic `JOIN`/cleanup in each file:

| View | Granularity | Purpose |
|---|---|---|
| [`clean_exam_results`](sql/03_views/v_clean_exam_results.sql) | 1 line = 1 passed exam | Geolocation cleaning (City / Village / Abroad), attaching data about the institution. |
| [`student_academic_profiles`](sql/03_views/v_student_academic_profiles.sql) | 1 row = 1 participant | "Broad" student profile: expanded scores of the mandatory core, optional subject, average indicators. |

**Lineage (data flow):**

```
Raw source files
        │
        ▼
sql/01_setup/  →  staging table → ETL pipeline → indexes
        │ 
        ▼
   Star Schema (participants, institutions, subjects, exam_results)
        │
        ▼
sql/03_views/  →  v_clean_exam_results → v_student_academic_profiles
        │
        ▼
sql/02_analytics/  →  5 research modules (01–05)
```

---

## 2. Research Catalog: 5 analytical modules

Each module is designed according to a single standard: **Hypotheses → Result/Insight → `.sql` file and results**.

### Module 1 — Chronodynamics and the effect of fatigue (`01_chronos_and_exam_fatigue_dynamics`)

**Focus:** studying the impact of the calendar date of the session on testing results, testing the effect of psychological exhaustion (Exam Fatigue), and identifying hidden segregation of participants between sessions.

**Hypothesis 1 (The May Cohort Shock):**  
May Saturday sessions demonstrate a statistically higher proportion of failing to pass the threshold score (`scaled_score = 0.0`) and a lower median compared to regular June sessions, which is due to the dominance of graduates from previous years.  
* **Result: CONFIRMED.**  
  * **94.4% – 95.8%** of the participants of the three May Saturdays (40,767 people) consisted of graduates from previous years.
  * The average score of the mandatory block was only **123.5 – 128.8** points, and the failure rate reached **19.9%**.
  * The transition from the last May session (05/31) to the first day of June (06/02) caused a sharp jump in the average score by **+17.3 points** (from 129.7 to 147.0) and a drop in dropout from 11.9% to 4.8% due to the mass exit of this year's graduates (92.1% of the day's sample).

**Hypothesis 2 (Temporal Drift & Fatigue):**  
Among this year's graduates, there is a systematic decline in academic results from the beginning to the end of the regular June campaign.  
* **Result: CONFIRMED ON A WEEKLY LEVEL.**  
  * The weekly breakdown of the June session records a monotonic increase in the share of mandatory block blockages: **9.27%** (Week 1) → **11.22%** (Week 2) → **13.00%** (Week 3).
  * The average linear trend in performance drops by **-0.43 points per session**. However, the smooth trend in fatigue is offset by much stronger interday jumps.

**Hypothesis 3 (Day-over-Day Variance):**  
Day-over-Day deltas contain sharp anomalous spikes that exceed the natural variance of the sample, indicating differences in the actual difficulty of test suites on individual days.  
* **Result: CONFIRMED AND EXTENDED (KEY INSIGHT).**  
  * Enormous intraday volatility detected: standard deviation $\Delta_{\text{DoD}}$ amounted to **11.69 points** (with an amplitude of fluctuations from **-15.60** to **+17.29** points between adjacent days).
  * The source of the fluctuations is not the random complexity of the tasks, but the **bimodal segregation of testing days for the 4th sample subject** (correlation of the workload of the day and the average score: $r = -0.80$).

![Chronos Daily Dynamics](images/01_chronos_daily_dynamics.png)

| June Session Cluster | Num. of Sessions | Avg. Participants Per Day | Avg. Graduate Score 2025 | Median | Avg. Fail Rate | Test Days |
|:---|:---:|:---:|:---:|:---:|:---:|:---|
| **Academic ("Foreign Languages")** | 5 | 15,557 | **144.87** | **145.13** | **5.44%** | 02.06, 05.06, 12.06, 16.06, 18.06 |
| **Major ("Geography / Lit")** | 9 | 18 421 | **132.50** | **135.00** | **14.14%** | 03.06, 04.06, 06.06, 09.06, 10.06, 11.06, 13.06, 17.06, 19.06 |

**Key anomalies:**
* **"Black Tuesday" June 17:** an anti-record of the June campaign — a daily collapse in the average score by **-15.60** (to 128.39) and a jump in the level of collapse to a peak **20.90%**.
* **July additional session (July 17–18):** the sample is reduced to ~2.5–2.8 thousand participants with parity of cohorts (~50% current year / ~50% previous years). The failure rate reached the maximum for the entire campaign — **24.25%** (July 17), and on July 18, the test was recorded in penal institutions (**1.3%** of the session).

**SQL module tools:**
* Multi-level CTEs for aggregation from the individual attendee level to the session calendar.
* Robust statistical constructs `PERCENTILE_CONT(0.5) WITHIN GROUP (...) FILTER (...)`.
* Navigation window offsets `LAG(...) OVER w` for calculating intersession steps.
* Smoothing frames `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING`.
* Cumulative coverage of campaign progress through window aggregates.

**Files:** [`sql/02_analytics/01_chronos_and_exam_fatigue_dynamics.sql`](sql/02_analytics/01_chronos_and_exam_fatigue_dynamics.sql) · [results (CSV)](results/01_chronos_and_exam_fatigue_dynamics.csv)

### Module 2 — Monopoly of regional centers and regional centralization (`02_capital_monopoly_and_regional_centralization`)

**Focus:** quantitative measurement of spatial educational inequality in the context of "Regional Center vs. Periphery", calculation of the localization index of the academic elite ($LQ$), assessment of the depth of decline in the basic level of knowledge in the regions and typology of education systems in 24 regions of Ukraine.
- **Coverage:** 22 representative regions with operating regional centers (Kyiv agglomeration consolidated as a single educational basin) + 2 front-line regions with special status (Donetsk, Luhansk).

**Hypothesis 1 (Elite Concentration / Law of Educational Oligopoly):**  
Concentration of academic elite (average score $\ge 180$ in all disciplines) in regional centers disproportionately exceeds their share in the total number of graduates in the region ($LQ > 1.0$).
* **Result: CONFIRMED FOR 95.5% OF REGIONS.**
  * In 21 out of 22 regions $LQ > 1.0$ (average national index — **1.36**).
  * **10 regions** entered the "Highly Centralized" cluster ($LQ \in [1.40; 1.68]$), where the main city concentrates a critical mass of excellent students.
  * Peak monopoly indicators were recorded in **Chernihiv ($LQ = 1.68$)**, **Transcarpathian ($LQ = 1.64$)** and **Rivne ($LQ = 1.61$)** regions.
  * At the same time, no region crossed the threshold of extreme hypermonopoly ($\ge 1.80$), since averaging grades across 4 disciplines naturally smooths out peak grades in individual subjects.

![Academic Monopoly vs Periphery Risk](images/02_monopoly_lq_vs_fail_ratio.png)

**Hypothesis 2 (The Periphery Floor Gap):**  
The periphery loses to the center not only in terms of the share of excellent students, but also demonstrates a critical decline in the basic level: a significantly lower median and an increased risk of failing the test (Fail Rate).
* **Result: 100% CONFIRMED (MAIN SYSTEM CONCLUSION).**
  * In **all 22 studied regions** the median score of the center exceeds the median of the periphery ($\Delta_{\text{Median}} > 0$). The average national gap is **+4.52 points**.
  * In **all 22 regions** the risk of failing the test in the periphery is significantly higher than in the regional center (`fail_rate_ratio` $> 1.0$, average — **1.51x**).

![The Periphery Floor Gap](images/02_periphery_floor_gap_dumbbell.png)

**Hypothesis 3 (Regional Typology & Outliers):**  
The regions of Ukraine, according to the spatial distribution of knowledge, fall into stable topological models with pronounced poles and anomalies.
* **Result: CONFIRMED.** 4 specific educational models were identified: Polycentric, Highly Centralized, Absolute Leader Model, and Frontier.


**Key insights and spatial anomalies**
* **The "Antimonopoly Phenomenon" of Volyn (The Only Balanced Region):**  
  Volyn region became the only region of Ukraine with an index $LQ < 1.0$ (**0.97**), where the periphery prepared a higher percentage of 180-pointers (**1.57%**) than the regional center Lutsk (**1.50%**). Thanks to a network of strong specialized lyceums in cities of regional significance (Kovel, Novovolynsk, Volodymyr), the region has formed a horizontal educational network without the leaching of talented students to the regional capital.
* **Pole of "double risk": Chernihiv and Kirovohrad regions:**  
  * **Chernihiv region** has an absolute anti-record median gap (**+7.50 points**) and failure ratio (**1.99x**): in the districts **16.14%** of graduates fail exams compared to **8.11%** in Chernihiv.
  * **Kirovohrad region** records a similar gap: $\Delta_{\text{Median}} = \mathbf{+7.00}$ points, and the risk of collapse in the periphery is **1.93 times** higher (18.29% vs 9.47%). In these areas, the periphery functions in a state of severe resource deprivation.
* **Lviv quality benchmark:**  
  Lviv region maintains its undisputed leadership in the country: the median of Lviv (**146.50**) and the median of districts (**142.00**) are the highest in Ukraine. Moreover, the periphery of Lviv region surpasses the regional centers of **18 other regions** (including Odessa, Kharkiv, Dnipro and Vinnytsia) in terms of the quality of knowledge, and the concentration of excellent students in districts (**2.11%**) is abnormally high for non-metropolitan territories.
* **Frontier distortions:**  
  * **Zaporizhzhya region:** **79.7%** of testing falls on Zaporizhzhia due to the proximity of the districts to the zone of active hostilities and temporary occupation.
  * **Donetsk and Luhansk regions:** 0% of participants in historical centers; 100% of the sample is represented by relocated institutions and free periphery with medians of **137.50** and **137.00**, respectively.

**SQL module tools:**

The query is optimized for single-pass analytical processing of large amounts of data:
1. **Algebraic optimization of the concentration index ($LQ$):**  
   Instead of the unstable division of two rounded quotients, an equivalent algebraic transformation is applied:
   $$LQ = \frac{\text{center\_high} \times \text{total\_part}}{\text{total\_high} \times \text{center\_part}}$$
   This completely eliminated the floating-point accumulation error and reduced the computational cost of the engine.
2. **Parallel Filtered Aggregation:**  
   Using syntax `COUNT(*) FILTER (...)` and `PERCENTILE_CONT(0.5) WITHIN GROUP (...) FILTER (...)` allowed to combine the indicators of total volume, center and periphery in a single CTE without difficult `SELF-JOIN`.
3. **Consolidation of the metropolitan area:**  
   Conditional merger `м.Київ` and `Київська область` solved the problem of an isolated metropolitan enclave by forming a representative metropolitan model with 37,946 participants.

**Files:** [`sql/02_analytics/02_capital_monopoly_and_regional_centralization.sql`](sql/02_analytics/02_capital_monopoly_and_regional_centralization.sql) · [результати (CSV)](results/02_capital_monopoly_and_regional_centralization.csv)

### Module 3 — Rural Resilience and Institutional Polarization (`03_resilience_gap_and_rural_polarization`)

**Focus:** research into educational inequality along the "City - Village - Abroad" axis, empirical testing of the effectiveness of the rural lyceum reform (The Rural Lyceum Illusion), detection of intra-school polarization ("one genius effect"), and identification of hidden rural flagships of academic resilience.

**Hypothesis 1 (The Macro Divide):**  
Rural areas demonstrate a systemic decline in the lower threshold of knowledge and an increased dropout rate compared to urban institutions and foreign testing centers.  
* **Result: CONFIRMED.**  
  * The median of rural graduates (**133.67**) is **3.66 points** lower than the urban (**137.33**) and **4.66 points** lower than the foreign (**138.33**). The lower quartile in rural areas falls to **123.33** (versus 127.33 in the city).
  * The share of graduates who received $0.0$ points in at least one mandatory subject reaches **15.72%** in the village (versus **11.37%** in the city and **8.23%** abroad).
  * Share of academic elite ($\ge 180$ points) in the village is half as low as in the city: **0.78%** versus **1.59%**.
  * Foreign graduates (3,050 people) formed the phenomenon of a compressed distribution: the lowest interquartile range ($IQR = 16.33$), the lowest dropout rate (8.23%), but almost complete absence of excellent students (only **0.39%**).

![The Macro Divide](images/03_macro_divide_benchmark.png)

**Hypothesis 2 (The Rural Lyceum Illusion):**  
The transformation of ordinary rural schools into "lyceums" did not provide a qualitative leap in the training of graduates and did not form a reliable protective threshold of knowledge.  
* **Result: 100% CONFIRMED (MAIN INSTITUTIONAL CONCLUSION).**  
  * Rural lyceums (39,831 students, 65.8% of the village sample) showed **full statistical parity** with regular secondary general education schools (13,882 students):
    * Absolutely identical median: **134.33** vs **134.33**;
    * Identical lower threshold ($Q_1$): **123.67** vs **123.00**;
    * Almost the same percentage of failure: **15.27%** vs **16.15%**.
  * The share of excellent students in regular rural schools turned out to be even higher than in lyceums: **1.02%** versus **0.77%**. The legal renaming of institutions did not affect academic results.
  * The critical risk zone is vocational education institutions (VET) and colleges in villages: the failure rate reaches **24.89%** and **21.10%**, respectively, with medians of $126.00$ and $128.33$.

![The Rural Lyceum Illusion](images/03_rural_lyceum_illusion_meso.png)

**Hypothesis 3 (Rural Resilience Outliers vs. "One Genius"):**  
Despite the systemic backwardness of rural areas, a large-scale cluster of rural schools has been formed in Ukraine, which consistently outperform urban institutions in terms of the quality of education.  
* **Result: CONFIRMED AND EXTENDED.**  
  * **Flagship schools of sustainability:** **718 institutions (32.2%** of the rural network), where **16,694 graduates (35.9%)** studied, have an average median of **142.35 points**, which is **+5.02 points higher than the average urban benchmark of Ukraine (137.33)**.
  * **Polarized schools ("one genius effect"):** recorded only in **58 institutions (2.6%)**, where in the presence of single 180-scorers, the institution's median ($129.75$) falls below the average rural bottom.
  * **Typical rural schools:** cover **1,454 institutions (65.2%)** with 28,095 students and an average median of **129.84 points**.

![Rural School Archetypes](images/03_rural_school_archetypes_micro.png)

**SQL module tools:**
* Cascade calculation of quantiles through `PERCENTILE_CONT(0.25 | 0.50 | 0.75) WITHIN GROUP (...)`.
* Calculating the interquartile range ($IQR$) and the coefficient of variation ($CV = \text{STDDEV} / \text{AVG}$) directly in aggregate queries.
* Multi-level CTE with generation of dynamic national benchmarks (`national_rural_median`, `national_urban_median`) and cross-connection (`CROSS JOIN`).
* Boolean predicate logic `BOOL_OR(mandatory_avg_score >= 180)` to isolate anomalies of intra-school segregation.
* Window coating particles through a single-pass `COUNT(*) / SUM(COUNT(*)) OVER ()`.

**Files:** [`sql/02_analytics/03_resilience_gap_and_rural_polarization.sql`](sql/02_analytics/03_resilience_gap_and_rural_polarization.sql) · results: [`macro (CSV)`](results/03_resilience_gap_and_rural_polarization_macro.csv) · [`meso (CSV)`](results/03_resilience_gap_and_rural_polarization_meso.csv) · [`micro (CSV)`](results/03_resilience_gap_and_rural_polarization_micro.csv)

### Module 4 — Strategy for choosing the 4th subject (`04_elective_subject_strategy_and_student_cohorts`)

**Focus:** TBD

*Hypotheses, tools, results — TBD.*

### Module 5 — STEM vs Humanities Asymmetry (`05_asymmetrical_student_stem_vs_humanities`)

**Focus:** TBD
*Hypotheses, tools, results — TBD.*

---

## 3. Repository structure

```text
├── sql/
│   ├── 01_setup/       # DDL, staging-table, ETL-pipeline, indexes
│   ├── 02_analytics/   # 5 research SQL-scripts
│   └── 03_views/       # Analytic views (clean_exam_results, student_academic_profiles)
├── docs/                # Data dictionary, ERD
├── results/             # Queries results (CSV)
└── README.md
```

---

## 4. Conclusions and practical value (Key Takeaways)

*The section will be supplemented after the completion of all 5 modules — a summary of the main conclusions and their practical value for regulators (MES, UCEQA) and applicants.*
