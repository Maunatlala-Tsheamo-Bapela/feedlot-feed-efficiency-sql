-- =====================================================================
-- FEEDLOT STEER EFFICIENCY: ADG, FCR AND FEED COST PER KG GAIN
-- Data: Beck (Mendeley Data, DOI 10.17632/wcc46fhff8.1), 150 steers,
--       3 experiments (Beck 2023, Proctor 2024, Foote 2024)
-- Dialect: PostgreSQL (tested on version 16; works on 12 and newer).
-- Run in pgAdmin: open Query Tool, paste, and run each step.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 0. CREATE THE RAW TABLE AND LOAD THE CSV
-- Note: TAG is only unique within an experiment, so the key is (experiment, tag).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS raw_steers CASCADE;
CREATE TABLE raw_steers (
    experiment  TEXT,
    tag         INTEGER,
    trt         TEXT,
    int_bw      NUMERIC,
    fin_bw      NUMERIC,
    av_bw       NUMERIC,
    av_bw_075   NUMERIC,
    adg         NUMERIC,
    dmi         NUMERIC,
    gf          NUMERIC,
    euclid_sum  NUMERIC,
    cv          NUMERIC,
    pred_dmi    NUMERIC,
    rfi         NUMERIC,
    pred_adg    NUMERIC,
    radg        NUMERIC,
    rig         NUMERIC,
    yg          NUMERIC,
    marb        NUMERIC,
    qgs         NUMERIC,
    hcw         NUMERIC,
    dressing    NUMERIC,
    bf          NUMERIC,
    rea         NUMERIC,
    ebf_pct     NUMERIC
);

-- Load the CSV. Option A (pgAdmin, easiest): right-click raw_steers >
-- Import/Export Data > Import, pick feedlot_steers.csv, Header = on,
-- Delimiter = comma.
-- Option B (psql), use the full path to your file:
-- \copy raw_steers FROM 'C:/path/to/feedlot_steers.csv' CSV HEADER

-- Check: should return 150
SELECT COUNT(*) AS rows_loaded FROM raw_steers;


-- ---------------------------------------------------------------------
-- STEP 1. PRICE ASSUMPTIONS (ZAR), prices as at 13-16 November 2026
-- feed_zar_per_kg_dm  : ration cost per kg of DRY MATTER
--   Source: Grain SA, SAFEX Feeds page. Yellow maize (YMAZ) Dec 2026,
--   R3,971.60/ton, last traded 16 Nov 2026. Converted to dry matter at
--   88% DM = R4.51/kg DM (low). Base adds 20% and high adds 40% for the
--   rest of the ration (roughage, protein, premix, mixing). The mark-ups
--   are assumptions.
-- live_gain_zar_per_kg: value of a kg of live gain
--   Source: RMIS National Livestock Prices Dashboard (data from ABSA),
--   Class A cattle carcass R66.25/kg, week 46, released 13 Nov 2026.
--   x average dressing of the 150 steers (64.309%) = R42.60/kg live gain.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS price_scenarios;
CREATE TABLE price_scenarios (
    scenario            TEXT PRIMARY KEY,
    feed_zar_per_kg_dm  NUMERIC,
    live_gain_zar_per_kg NUMERIC
);
INSERT INTO price_scenarios VALUES
    ('low',  4.51, 42.60),
    ('base', 5.42, 42.60),
    ('high', 6.32, 42.60);


-- ---------------------------------------------------------------------
-- STEP 2. CLEAN VIEW WITH THE CORE METRICS
-- days_on_feed is not in the file, so it is derived: (final - initial) / ADG
-- FCR = DMI / ADG  (kg dry matter per kg gain, lower is better)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS steers CASCADE;
CREATE VIEW steers AS
SELECT
    CASE
        WHEN experiment LIKE 'Beck%'    THEN 'Beck 2023'
        WHEN experiment LIKE 'Proctor%' THEN 'Proctor 2024'
        WHEN experiment LIKE 'Foote%'   THEN 'Foote 2024'
        ELSE experiment
    END                                             AS experiment,
    tag,
    COALESCE(trt, 'No treatment')                   AS treatment,
    int_bw,
    fin_bw,
    adg,
    dmi,
    rfi,
    cv                                              AS dmi_cv_pct,
    hcw,
    dressing,
    ROUND((fin_bw - int_bw) / adg)                  AS days_on_feed,
    fin_bw - int_bw                                 AS total_gain_kg,
    dmi * ROUND((fin_bw - int_bw) / adg)            AS total_dm_kg,
    dmi / adg                                       AS fcr
FROM raw_steers;


-- ---------------------------------------------------------------------
-- STEP 3. DATA QUALITY CHECKS
-- ---------------------------------------------------------------------

-- 3a. Row counts and missing values per experiment
SELECT
    experiment,
    COUNT(*)                                        AS animals,
    SUM(CASE WHEN treatment = 'No treatment' THEN 1 ELSE 0 END) AS no_treatment_label,
    SUM(CASE WHEN hcw IS NULL THEN 1 ELSE 0 END)    AS missing_hcw
FROM steers
GROUP BY experiment;

-- 3b. Impossible or suspicious values (expect zero rows)
SELECT *
FROM steers
WHERE adg <= 0 OR dmi <= 0 OR fin_bw <= int_bw
   OR days_on_feed < 30 OR days_on_feed > 200;

-- 3c. Does recalculated ADG match the reported ADG? (expect tiny differences)
SELECT
    ROUND(MAX(ABS(total_gain_kg / days_on_feed - adg)), 4) AS max_adg_difference
FROM steers;


-- ---------------------------------------------------------------------
-- STEP 4. EXPERIMENT-LEVEL SUMMARY (ADG, DMI, FCR)
-- Experiments differ a lot, so never pool them without saying so.
-- ---------------------------------------------------------------------
SELECT
    experiment,
    COUNT(*)                        AS n,
    ROUND(AVG(days_on_feed), 0)     AS avg_days,
    ROUND(AVG(int_bw), 0)           AS avg_initial_kg,
    ROUND(AVG(adg), 2)              AS avg_adg,
    ROUND(AVG(dmi), 2)              AS avg_dmi,
    ROUND(AVG(fcr), 2)              AS avg_fcr
FROM steers
GROUP BY experiment
ORDER BY experiment;


-- ---------------------------------------------------------------------
-- STEP 5. TREATMENT COMPARISON (ONLY VALID WITHIN AN EXPERIMENT)
-- ---------------------------------------------------------------------
SELECT
    experiment,
    treatment,
    COUNT(*)                        AS n,
    ROUND(AVG(adg), 2)              AS avg_adg,
    ROUND(AVG(dmi), 2)              AS avg_dmi,
    ROUND(AVG(fcr), 2)              AS avg_fcr,
    ROUND(MIN(fcr), 2)              AS best_fcr,
    ROUND(MAX(fcr), 2)              AS worst_fcr
FROM steers
WHERE treatment <> 'No treatment'
GROUP BY experiment, treatment
ORDER BY experiment, avg_fcr;


-- ---------------------------------------------------------------------
-- STEP 6. FEED COST PER KG GAIN UNDER EACH PRICE SCENARIO
-- cost per kg gain = FCR x feed price per kg DM
-- ---------------------------------------------------------------------
SELECT
    p.scenario,
    s.experiment,
    ROUND(AVG(s.fcr), 2)                            AS avg_fcr,
    ROUND(AVG(s.fcr * p.feed_zar_per_kg_dm), 2)     AS avg_feed_cost_per_kg_gain_zar,
    ROUND(AVG(s.total_dm_kg * p.feed_zar_per_kg_dm), 0) AS avg_feed_cost_per_animal_zar
FROM steers s
CROSS JOIN price_scenarios p
GROUP BY p.scenario, s.experiment
ORDER BY p.scenario, s.experiment;


-- ---------------------------------------------------------------------
-- STEP 7. EFFICIENCY GROUPS (MAIN ANALYSIS)
-- Rank animals by RFI within each experiment and split into thirds.
-- Low RFI = eats less than predicted for its size and gain = more efficient.
-- Ranking inside each experiment removes the trial-to-trial differences.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS steers_grouped CASCADE;
CREATE VIEW steers_grouped AS
SELECT
    *,
    CASE NTILE(3) OVER (PARTITION BY experiment ORDER BY rfi)
        WHEN 1 THEN '1 Efficient (low RFI)'
        WHEN 2 THEN '2 Average'
        ELSE        '3 Inefficient (high RFI)'
    END AS rfi_group
FROM steers;

-- 7a. Performance by efficiency group (pooled across experiments)
SELECT
    rfi_group,
    COUNT(*)                        AS n,
    ROUND(AVG(rfi), 2)              AS avg_rfi,
    ROUND(AVG(adg), 2)              AS avg_adg,
    ROUND(AVG(dmi), 2)              AS avg_dmi,
    ROUND(AVG(fcr), 2)              AS avg_fcr,
    ROUND(AVG(hcw), 0)              AS avg_hcw_kg
FROM steers_grouped
GROUP BY rfi_group
ORDER BY rfi_group;

-- 7b. Same table, by experiment (check the pattern holds in each trial)
SELECT
    experiment,
    rfi_group,
    COUNT(*)                        AS n,
    ROUND(AVG(adg), 2)              AS avg_adg,
    ROUND(AVG(dmi), 2)              AS avg_dmi,
    ROUND(AVG(fcr), 2)              AS avg_fcr
FROM steers_grouped
GROUP BY experiment, rfi_group
ORDER BY experiment, rfi_group;


-- ---------------------------------------------------------------------
-- STEP 8. PROFIT ANGLE: INCOME OVER FEED COST PER ANIMAL (BASE SCENARIO)
-- income over feed = (gain x value of live gain) - (total DM x feed price)
-- This ignores purchase cost, labour, vet and interest, so it is a
-- margin over feed only, not full profit. Say so in the case study.
-- ---------------------------------------------------------------------
SELECT
    g.rfi_group,
    COUNT(*)                                                        AS n,
    ROUND(AVG(g.fcr * p.feed_zar_per_kg_dm), 2)                     AS feed_cost_per_kg_gain,
    ROUND(AVG(g.total_dm_kg * p.feed_zar_per_kg_dm), 0)             AS feed_cost_per_animal,
    ROUND(AVG(g.total_gain_kg * p.live_gain_zar_per_kg
              - g.total_dm_kg * p.feed_zar_per_kg_dm), 0)           AS income_over_feed_per_animal
FROM steers_grouped g
JOIN price_scenarios p ON p.scenario = 'base'
GROUP BY g.rfi_group
ORDER BY g.rfi_group;

-- 8b. Value of efficiency: efficient third vs inefficient third, all scenarios
WITH per_group AS (
    SELECT
        p.scenario,
        g.rfi_group,
        AVG(g.total_gain_kg * p.live_gain_zar_per_kg
            - g.total_dm_kg * p.feed_zar_per_kg_dm) AS income_over_feed
    FROM steers_grouped g
    CROSS JOIN price_scenarios p
    GROUP BY p.scenario, g.rfi_group
)
SELECT
    e.scenario,
    ROUND(e.income_over_feed, 0)                    AS efficient_group_zar,
    ROUND(i.income_over_feed, 0)                    AS inefficient_group_zar,
    ROUND(e.income_over_feed - i.income_over_feed, 0) AS advantage_per_animal_zar
FROM per_group e
JOIN per_group i
  ON i.scenario = e.scenario
 AND i.rfi_group = '3 Inefficient (high RFI)'
WHERE e.rfi_group = '1 Efficient (low RFI)'
ORDER BY e.scenario;


-- ---------------------------------------------------------------------
-- STEP 9. DOES DAY-TO-DAY INTAKE VARIABILITY MATTER?
-- Pearson correlations using PostgreSQL's built-in CORR function.
-- Positive correlation with FCR means more variable eaters are less efficient.
-- ---------------------------------------------------------------------
SELECT
    ROUND(CORR(dmi, adg)::numeric, 3)            AS corr_dmi_adg,
    ROUND(CORR(dmi_cv_pct, fcr)::numeric, 3)     AS corr_intake_cv_fcr,
    ROUND(CORR(rfi, fcr)::numeric, 3)            AS corr_rfi_fcr
FROM steers;
