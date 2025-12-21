-- 03_dimensional_views.sql
-- Creates DIMENSIONAL schema with flattened views for MMM modeling and Streamlit
-- Depends on: 02_schema_setup.sql (ATOMIC tables must exist)
-- Expected context: Role = Project Role, Database = Project Database

-- ============================================================================
-- DIMENSIONAL SCHEMA
-- Purpose: Flattened views that denormalize hierarchies for easy analytics
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS DIMENSIONAL 
    COMMENT = 'Flattened dimensional views for MMM modeling and Streamlit dashboards';

USE SCHEMA DIMENSIONAL;

-- ============================================================================
-- SECTION 1: FLATTENED HIERARCHY VIEWS
-- These views flatten self-referential hierarchies into columnar format
-- ============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 DIM_GEOGRAPHY_HIERARCHY
-- Flattens: Super-Region → Region → Country
-- Usage: Regional drill-down in dashboards, geographic filtering in models
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW DIM_GEOGRAPHY_HIERARCHY AS
SELECT 
    -- Country Level (Leaf)
    g.GEOGRAPHY_ID,
    g.GEOGRAPHY_CODE AS COUNTRY_CODE,
    g.GEOGRAPHY_NAME AS COUNTRY_NAME,
    g.ISO_COUNTRY_CODE,
    g.ISO_COUNTRY_CODE_2,
    -- Region Level (Parent)
    r.GEOGRAPHY_ID AS REGION_ID,
    r.GEOGRAPHY_CODE AS REGION_CODE,
    r.GEOGRAPHY_NAME AS REGION_NAME,
    -- Super-Region Level (Grandparent)
    sr.GEOGRAPHY_ID AS SUPER_REGION_ID,
    sr.GEOGRAPHY_CODE AS SUPER_REGION_CODE,
    sr.GEOGRAPHY_NAME AS SUPER_REGION_NAME
FROM ATOMIC.GEOGRAPHY g
LEFT JOIN ATOMIC.GEOGRAPHY r 
    ON g.PARENT_GEOGRAPHY_ID = r.GEOGRAPHY_ID 
    AND r.IS_CURRENT_FLAG = TRUE
LEFT JOIN ATOMIC.GEOGRAPHY sr 
    ON r.PARENT_GEOGRAPHY_ID = sr.GEOGRAPHY_ID 
    AND sr.IS_CURRENT_FLAG = TRUE
WHERE g.IS_CURRENT_FLAG = TRUE 
  AND g.GEOGRAPHY_TYPE = 'COUNTRY';

COMMENT ON VIEW DIM_GEOGRAPHY_HIERARCHY IS 
    'Flattened geography hierarchy: Super-Region → Region → Country. Use for regional drill-down analysis.';

-- -----------------------------------------------------------------------------
-- 1.2 DIM_PRODUCT_HIERARCHY
-- Flattens: Business Segment → Division → Product Category
-- Usage: Product line drill-down, portfolio analysis
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW DIM_PRODUCT_HIERARCHY AS
SELECT
    -- Category Level (Leaf - Level 3)
    pc.PRODUCT_CATEGORY_ID,
    pc.PRODUCT_CATEGORY_CODE AS CATEGORY_CODE,
    pc.CATEGORY_NAME,
    pc.CATEGORY_DESCRIPTION,
    -- Division Level (Parent - Level 2)
    div.PRODUCT_CATEGORY_ID AS DIVISION_ID,
    div.PRODUCT_CATEGORY_CODE AS DIVISION_CODE,
    div.CATEGORY_NAME AS DIVISION_NAME,
    -- Segment Level (Grandparent - Level 1)
    seg.PRODUCT_CATEGORY_ID AS SEGMENT_ID,
    seg.PRODUCT_CATEGORY_CODE AS SEGMENT_CODE,
    seg.CATEGORY_NAME AS SEGMENT_NAME
FROM ATOMIC.PRODUCT_CATEGORY pc
LEFT JOIN ATOMIC.PRODUCT_CATEGORY div 
    ON pc.PARENT_CATEGORY_ID = div.PRODUCT_CATEGORY_ID 
    AND div.IS_CURRENT_FLAG = TRUE
LEFT JOIN ATOMIC.PRODUCT_CATEGORY seg 
    ON div.PARENT_CATEGORY_ID = seg.PRODUCT_CATEGORY_ID 
    AND seg.IS_CURRENT_FLAG = TRUE
WHERE pc.IS_CURRENT_FLAG = TRUE 
  AND pc.CATEGORY_LEVEL = 3;

COMMENT ON VIEW DIM_PRODUCT_HIERARCHY IS 
    'Flattened product hierarchy: Segment → Division → Category. Maps 23 product lines to business segments.';

-- -----------------------------------------------------------------------------
-- 1.3 DIM_ORGANIZATION_HIERARCHY
-- Flattens: Corporate → Business Group → Regional Business Unit
-- Usage: Organizational drill-down, budget rollup
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW DIM_ORGANIZATION_HIERARCHY AS
SELECT
    -- Regional BU Level (Leaf)
    o.ORGANIZATION_ID,
    o.ORGANIZATION_CODE AS BU_CODE,
    o.ORGANIZATION_NAME AS BU_NAME,
    o.ORGANIZATION_TYPE AS BU_TYPE,
    -- Business Group Level (Parent)
    bg.ORGANIZATION_ID AS BUSINESS_GROUP_ID,
    bg.ORGANIZATION_CODE AS BUSINESS_GROUP_CODE,
    bg.ORGANIZATION_NAME AS BUSINESS_GROUP_NAME,
    -- Corporate Level (Grandparent)
    corp.ORGANIZATION_ID AS CORPORATE_ID,
    corp.ORGANIZATION_CODE AS CORPORATE_CODE,
    corp.ORGANIZATION_NAME AS CORPORATE_NAME
FROM ATOMIC.ORGANIZATION o
LEFT JOIN ATOMIC.ORGANIZATION bg 
    ON o.PARENT_ORGANIZATION_ID = bg.ORGANIZATION_ID 
    AND bg.IS_CURRENT_FLAG = TRUE
LEFT JOIN ATOMIC.ORGANIZATION corp 
    ON bg.PARENT_ORGANIZATION_ID = corp.ORGANIZATION_ID 
    AND corp.IS_CURRENT_FLAG = TRUE
WHERE o.IS_CURRENT_FLAG = TRUE;

COMMENT ON VIEW DIM_ORGANIZATION_HIERARCHY IS 
    'Flattened organization hierarchy: Corporate → Business Group → Regional BU.';

-- ============================================================================
-- SECTION 2: DENORMALIZED DIMENSION VIEWS
-- These views join multiple dimensions for single-query access
-- ============================================================================

-- -----------------------------------------------------------------------------
-- 2.1 DIM_CAMPAIGN
-- Fully denormalized campaign dimension with all hierarchical attributes
-- Usage: Primary dimension for spend analysis, campaign filtering
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW DIM_CAMPAIGN AS
SELECT
    -- Campaign Core Attributes
    c.MARKETING_CAMPAIGN_ID,
    c.CAMPAIGN_CODE,
    c.CAMPAIGN_NAME,
    c.CAMPAIGN_OBJECTIVE,
    c.START_DATE AS CAMPAIGN_START_DATE,
    c.END_DATE AS CAMPAIGN_END_DATE,
    c.BUDGET_AMOUNT AS CAMPAIGN_BUDGET,
    
    -- Channel Attributes
    ch.MARKETING_CHANNEL_ID,
    ch.CHANNEL_CODE,
    ch.CHANNEL_NAME,
    ch.CHANNEL_TYPE,
    ch.PLATFORM_CPM AS CHANNEL_BENCHMARK_CPM,
    ch.PLATFORM_CTR AS CHANNEL_BENCHMARK_CTR,
    
    -- Geography Attributes (Flattened Hierarchy)
    g.GEOGRAPHY_ID,
    g.COUNTRY_CODE,
    g.COUNTRY_NAME,
    g.ISO_COUNTRY_CODE,
    g.REGION_ID,
    g.REGION_CODE,
    g.REGION_NAME,
    g.SUPER_REGION_ID,
    g.SUPER_REGION_CODE,
    g.SUPER_REGION_NAME,
    
    -- Product Attributes (Flattened Hierarchy)
    p.PRODUCT_CATEGORY_ID,
    p.CATEGORY_CODE,
    p.CATEGORY_NAME,
    p.DIVISION_ID,
    p.DIVISION_CODE,
    p.DIVISION_NAME,
    p.SEGMENT_ID,
    p.SEGMENT_CODE,
    p.SEGMENT_NAME,
    
    -- Organization Attributes (Flattened Hierarchy)
    o.ORGANIZATION_ID,
    o.BU_CODE,
    o.BU_NAME,
    o.BUSINESS_GROUP_ID,
    o.BUSINESS_GROUP_CODE,
    o.BUSINESS_GROUP_NAME,
    o.CORPORATE_ID,
    o.CORPORATE_CODE,
    o.CORPORATE_NAME

FROM ATOMIC.MARKETING_CAMPAIGN c
LEFT JOIN ATOMIC.MARKETING_CHANNEL ch 
    ON c.MARKETING_CHANNEL_ID = ch.MARKETING_CHANNEL_ID 
    AND ch.IS_CURRENT_FLAG = TRUE
LEFT JOIN DIM_GEOGRAPHY_HIERARCHY g 
    ON c.GEOGRAPHY_ID = g.GEOGRAPHY_ID
LEFT JOIN DIM_PRODUCT_HIERARCHY p 
    ON c.PRODUCT_CATEGORY_ID = p.PRODUCT_CATEGORY_ID
LEFT JOIN DIM_ORGANIZATION_HIERARCHY o 
    ON c.ORGANIZATION_ID = o.ORGANIZATION_ID
WHERE c.IS_CURRENT_FLAG = TRUE;

COMMENT ON VIEW DIM_CAMPAIGN IS 
    'Fully denormalized campaign dimension with channel, geography, product, and organization hierarchies flattened.';

-- ============================================================================
-- SECTION 3: FACT VIEWS FOR STREAMLIT DASHBOARDS
-- Pre-joined fact tables for optimal dashboard performance
-- ============================================================================

-- -----------------------------------------------------------------------------
-- 3.1 FACT_MEDIA_SPEND_DAILY
-- Daily spend fact with all dimensional attributes pre-joined
-- Usage: Streamlit dashboards, trend analysis, drill-down reports
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW FACT_MEDIA_SPEND_DAILY AS
SELECT
    -- Fact Keys
    s.MARKETING_MEDIA_SPEND_ID,
    s.MARKETING_CAMPAIGN_ID,
    
    -- Date Dimension
    s.AD_DATE,
    YEAR(s.AD_DATE) AS AD_YEAR,
    QUARTER(s.AD_DATE) AS AD_QUARTER,
    MONTH(s.AD_DATE) AS AD_MONTH,
    WEEK(s.AD_DATE) AS AD_WEEK,
    DAYOFWEEK(s.AD_DATE) AS AD_DAY_OF_WEEK,
    
    -- Creative Attributes
    s.ASSET_TYPE,
    
    -- Spend Metrics
    s.SPEND_USD,
    s.IMPRESSIONS,
    s.CLICKS,
    s.VIDEO_VIEWS_50,
    s.ENGAGEMENTS,
    
    -- Calculated Metrics
    DIV0(s.CLICKS, s.IMPRESSIONS) AS CTR,
    DIV0(s.SPEND_USD, s.IMPRESSIONS) * 1000 AS CPM,
    DIV0(s.SPEND_USD, s.CLICKS) AS CPC,
    
    -- All Dimensional Attributes from DIM_CAMPAIGN
    c.CAMPAIGN_CODE,
    c.CAMPAIGN_NAME,
    c.CAMPAIGN_OBJECTIVE,
    c.CAMPAIGN_START_DATE,
    c.CAMPAIGN_END_DATE,
    c.CAMPAIGN_BUDGET,
    c.CHANNEL_CODE,
    c.CHANNEL_NAME,
    c.CHANNEL_TYPE,
    c.COUNTRY_CODE,
    c.COUNTRY_NAME,
    c.REGION_CODE,
    c.REGION_NAME,
    c.SUPER_REGION_CODE,
    c.SUPER_REGION_NAME,
    c.CATEGORY_CODE,
    c.CATEGORY_NAME,
    c.DIVISION_CODE,
    c.DIVISION_NAME,
    c.SEGMENT_CODE,
    c.SEGMENT_NAME,
    c.BU_CODE,
    c.BU_NAME,
    c.BUSINESS_GROUP_CODE,
    c.BUSINESS_GROUP_NAME

FROM ATOMIC.MARKETING_MEDIA_SPEND s
JOIN DIM_CAMPAIGN c 
    ON s.MARKETING_CAMPAIGN_ID = c.MARKETING_CAMPAIGN_ID;

COMMENT ON VIEW FACT_MEDIA_SPEND_DAILY IS 
    'Daily media spend fact with all dimensional attributes. Primary view for Streamlit dashboards.';

-- ============================================================================
-- SECTION 4: MMM MODEL INPUT/OUTPUT VIEWS
-- Aggregated views optimized for Marketing Mix Modeling
-- ============================================================================

-- -----------------------------------------------------------------------------
-- 4.1 V_MMM_INPUT_WEEKLY
-- Weekly aggregated data for Robyn/PyMC model training
-- Grain: Week × Region × Country × Segment × Division × Category × Channel
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW V_MMM_INPUT_WEEKLY AS
WITH WEEKLY_SPEND AS (
    SELECT 
        DATE_TRUNC('WEEK', s.AD_DATE) AS WEEK_START,
        s.SUPER_REGION_NAME,
        s.REGION_NAME,
        s.COUNTRY_NAME,
        s.SEGMENT_NAME,
        s.DIVISION_NAME,
        s.CATEGORY_NAME,
        s.CHANNEL_CODE,
        s.CHANNEL_TYPE,
        s.CAMPAIGN_OBJECTIVE,
        -- Spend Metrics
        SUM(s.SPEND_USD) AS TOTAL_SPEND,
        SUM(s.IMPRESSIONS) AS TOTAL_IMPRESSIONS,
        SUM(s.CLICKS) AS TOTAL_CLICKS,
        SUM(s.VIDEO_VIEWS_50) AS TOTAL_VIDEO_VIEWS,
        SUM(s.ENGAGEMENTS) AS TOTAL_ENGAGEMENTS,
        -- Calculated Metrics
        DIV0(SUM(s.CLICKS), SUM(s.IMPRESSIONS)) AS AVG_CTR,
        DIV0(SUM(s.SPEND_USD), SUM(s.IMPRESSIONS)) * 1000 AS AVG_CPM
    FROM FACT_MEDIA_SPEND_DAILY s
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
),
WEEKLY_REVENUE AS (
    SELECT
        DATE_TRUNC('WEEK', r.POSTING_DATE) AS WEEK_START,
        g.SUPER_REGION_NAME,
        g.REGION_NAME,
        g.COUNTRY_NAME,
        p.SEGMENT_NAME,
        p.DIVISION_NAME,
        p.CATEGORY_NAME,
        SUM(r.REVENUE_AMOUNT) AS TOTAL_REVENUE,
        COUNT(DISTINCT r.INVOICE_ID) AS TRANSACTION_COUNT
    FROM ATOMIC.ACTUAL_FINANCIAL_RESULT r
    LEFT JOIN DIM_GEOGRAPHY_HIERARCHY g ON r.GEOGRAPHY_ID = g.GEOGRAPHY_ID
    LEFT JOIN DIM_PRODUCT_HIERARCHY p ON r.PRODUCT_CATEGORY_ID = p.PRODUCT_CATEGORY_ID
    GROUP BY 1, 2, 3, 4, 5, 6, 7
),
WEEKLY_INDICATORS AS (
    SELECT
        DATE_TRUNC('WEEK', mi.INDICATOR_DATE) AS WEEK_START,
        g.SUPER_REGION_NAME,
        g.REGION_NAME,
        g.COUNTRY_NAME,
        AVG(mi.PMI_INDEX) AS AVG_PMI,
        AVG(mi.COMPETITOR_SHARE_OF_VOICE) AS AVG_COMPETITOR_SOV,
        AVG(mi.INDUSTRY_GROWTH_RATE) AS AVG_INDUSTRY_GROWTH
    FROM ATOMIC.MARKET_INDICATOR mi
    LEFT JOIN DIM_GEOGRAPHY_HIERARCHY g ON mi.GEOGRAPHY_ID = g.GEOGRAPHY_ID
    GROUP BY 1, 2, 3, 4
)
SELECT
    -- Time Dimension
    COALESCE(s.WEEK_START, r.WEEK_START, i.WEEK_START) AS WEEK_START,
    
    -- Geography Dimensions
    COALESCE(s.SUPER_REGION_NAME, r.SUPER_REGION_NAME, i.SUPER_REGION_NAME) AS SUPER_REGION,
    COALESCE(s.REGION_NAME, r.REGION_NAME, i.REGION_NAME) AS REGION,
    COALESCE(s.COUNTRY_NAME, r.COUNTRY_NAME, i.COUNTRY_NAME) AS COUNTRY,
    
    -- Product Dimensions
    COALESCE(s.SEGMENT_NAME, r.SEGMENT_NAME) AS SEGMENT,
    COALESCE(s.DIVISION_NAME, r.DIVISION_NAME) AS DIVISION,
    COALESCE(s.CATEGORY_NAME, r.CATEGORY_NAME) AS CATEGORY,
    
    -- Channel Dimensions
    s.CHANNEL_CODE AS CHANNEL,
    s.CHANNEL_TYPE,
    s.CAMPAIGN_OBJECTIVE,
    
    -- Spend Metrics (Independent Variables for MMM)
    ZEROIFNULL(s.TOTAL_SPEND) AS SPEND,
    ZEROIFNULL(s.TOTAL_IMPRESSIONS) AS IMPRESSIONS,
    ZEROIFNULL(s.TOTAL_CLICKS) AS CLICKS,
    ZEROIFNULL(s.TOTAL_VIDEO_VIEWS) AS VIDEO_VIEWS,
    ZEROIFNULL(s.TOTAL_ENGAGEMENTS) AS ENGAGEMENTS,
    ZEROIFNULL(s.AVG_CTR) AS CTR,
    ZEROIFNULL(s.AVG_CPM) AS CPM,
    
    -- Revenue Metrics (Dependent Variable for MMM)
    ZEROIFNULL(r.TOTAL_REVENUE) AS REVENUE,
    ZEROIFNULL(r.TRANSACTION_COUNT) AS TRANSACTIONS,
    
    -- Control Variables (Exogenous for MMM)
    i.AVG_PMI AS PMI_INDEX,
    i.AVG_COMPETITOR_SOV AS COMPETITOR_SOV,
    i.AVG_INDUSTRY_GROWTH AS INDUSTRY_GROWTH,
    
    -- Calculated ROAS (for validation)
    DIV0(ZEROIFNULL(r.TOTAL_REVENUE), ZEROIFNULL(s.TOTAL_SPEND)) AS ROAS

FROM WEEKLY_SPEND s
FULL OUTER JOIN WEEKLY_REVENUE r 
    ON s.WEEK_START = r.WEEK_START 
    AND s.SUPER_REGION_NAME = r.SUPER_REGION_NAME 
    AND s.REGION_NAME = r.REGION_NAME
    AND s.COUNTRY_NAME = r.COUNTRY_NAME
    AND s.SEGMENT_NAME = r.SEGMENT_NAME
    AND s.DIVISION_NAME = r.DIVISION_NAME
    AND s.CATEGORY_NAME = r.CATEGORY_NAME
LEFT JOIN WEEKLY_INDICATORS i 
    ON COALESCE(s.WEEK_START, r.WEEK_START) = i.WEEK_START 
    AND COALESCE(s.SUPER_REGION_NAME, r.SUPER_REGION_NAME) = i.SUPER_REGION_NAME
    AND COALESCE(s.REGION_NAME, r.REGION_NAME) = i.REGION_NAME
    AND COALESCE(s.COUNTRY_NAME, r.COUNTRY_NAME) = i.COUNTRY_NAME;

COMMENT ON VIEW V_MMM_INPUT_WEEKLY IS 
    'Weekly aggregated MMM input data. Primary training dataset for Robyn/PyMC models. Includes spend (X), revenue (Y), and control variables.';

-- -----------------------------------------------------------------------------
-- 4.2 V_MMM_RESULTS_ANALYSIS
-- Model results with dimensional attributes for What-If analysis in Streamlit
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW V_MMM_RESULTS_ANALYSIS AS
SELECT
    -- Model Metadata
    r.MMM_MODEL_RESULT_ID,
    r.MODEL_RUN_DATE,
    r.MODEL_VERSION,
    
    -- Model Coefficients and Metrics
    r.COEFFICIENT_WEIGHT,
    r.ROI,
    r.MARGINAL_ROI,
    r.OPTIMAL_SPEND_SUGGESTION,
    r.ADSTOCK_DECAY_RATE,
    r.SATURATION_POINT,
    
    -- Channel Attributes
    ch.CHANNEL_CODE,
    ch.CHANNEL_NAME,
    ch.CHANNEL_TYPE,
    
    -- Geography Attributes (Flattened)
    g.COUNTRY_CODE,
    g.COUNTRY_NAME,
    g.REGION_CODE,
    g.REGION_NAME,
    g.SUPER_REGION_CODE,
    g.SUPER_REGION_NAME,
    
    -- Product Attributes (Flattened)
    p.CATEGORY_CODE,
    p.CATEGORY_NAME,
    p.DIVISION_CODE,
    p.DIVISION_NAME,
    p.SEGMENT_CODE,
    p.SEGMENT_NAME,
    
    -- Organization Attributes (Flattened)
    o.BU_CODE,
    o.BU_NAME,
    o.BUSINESS_GROUP_CODE,
    o.BUSINESS_GROUP_NAME

FROM ATOMIC.MMM_MODEL_RESULT r
LEFT JOIN ATOMIC.MARKETING_CHANNEL ch 
    ON r.MARKETING_CHANNEL_ID = ch.MARKETING_CHANNEL_ID 
    AND ch.IS_CURRENT_FLAG = TRUE
LEFT JOIN DIM_GEOGRAPHY_HIERARCHY g 
    ON r.GEOGRAPHY_ID = g.GEOGRAPHY_ID
LEFT JOIN DIM_PRODUCT_HIERARCHY p 
    ON r.PRODUCT_CATEGORY_ID = p.PRODUCT_CATEGORY_ID
LEFT JOIN DIM_ORGANIZATION_HIERARCHY o 
    ON r.ORGANIZATION_ID = o.ORGANIZATION_ID;

COMMENT ON VIEW V_MMM_RESULTS_ANALYSIS IS 
    'MMM model results with dimensional attributes. Used for What-If simulation in Streamlit Budget Optimizer.';

-- ============================================================================
-- SECTION 5: CONVENIENCE VIEWS FOR STREAMLIT FILTERS
-- Pre-aggregated views for populating filter dropdowns
-- ============================================================================

-- Available Regions for Filter
CREATE OR REPLACE VIEW V_FILTER_REGIONS AS
SELECT DISTINCT
    SUPER_REGION_CODE,
    SUPER_REGION_NAME,
    REGION_CODE,
    REGION_NAME
FROM DIM_GEOGRAPHY_HIERARCHY
ORDER BY SUPER_REGION_NAME, REGION_NAME;

-- Available Product Categories for Filter
CREATE OR REPLACE VIEW V_FILTER_PRODUCTS AS
SELECT DISTINCT
    SEGMENT_CODE,
    SEGMENT_NAME,
    DIVISION_CODE,
    DIVISION_NAME,
    CATEGORY_CODE,
    CATEGORY_NAME
FROM DIM_PRODUCT_HIERARCHY
ORDER BY SEGMENT_NAME, DIVISION_NAME, CATEGORY_NAME;

-- Available Channels for Filter
CREATE OR REPLACE VIEW V_FILTER_CHANNELS AS
SELECT DISTINCT
    ch.CHANNEL_CODE,
    ch.CHANNEL_NAME,
    ch.CHANNEL_TYPE
FROM ATOMIC.MARKETING_CHANNEL ch
WHERE ch.IS_CURRENT_FLAG = TRUE
ORDER BY ch.CHANNEL_TYPE, ch.CHANNEL_NAME;

-- Date Range for Filters
CREATE OR REPLACE VIEW V_FILTER_DATE_RANGE AS
SELECT
    MIN(AD_DATE) AS MIN_DATE,
    MAX(AD_DATE) AS MAX_DATE,
    COUNT(DISTINCT AD_DATE) AS TOTAL_DAYS,
    COUNT(DISTINCT DATE_TRUNC('WEEK', AD_DATE)) AS TOTAL_WEEKS
FROM ATOMIC.MARKETING_MEDIA_SPEND;

SELECT 'Dimensional views created successfully.' AS STATUS;

