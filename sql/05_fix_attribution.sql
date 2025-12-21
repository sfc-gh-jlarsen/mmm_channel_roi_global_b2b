-- 05_fix_attribution.sql
-- Fix revenue attribution by properly joining through Opportunity → Campaign → Channel
-- This creates views that correctly attribute revenue to marketing channels
-- Run after 02_schema_setup.sql and 03_load_data.sql

USE DATABASE GLOBAL_B2B_MMM;
USE SCHEMA DIMENSIONAL;

-- =============================================================================
-- Fix V_MMM_INPUT_WEEKLY to properly attribute revenue to channels
-- The key insight: Revenue → Opportunity → Campaign → Channel
-- =============================================================================

CREATE OR REPLACE VIEW V_MMM_INPUT_WEEKLY AS
WITH WEEKLY_SPEND AS (
    -- Aggregate spend by week and channel
    SELECT 
        DATE_TRUNC('WEEK', s.SPEND_DATE) AS WEEK_START,
        c.REGION AS REGION_NAME,
        c.CHANNEL AS CHANNEL_CODE,
        CASE 
            WHEN c.CHANNEL = 'LinkedIn' THEN 'SOCIAL'
            WHEN c.CHANNEL = 'Facebook' THEN 'SOCIAL'
            WHEN c.CHANNEL = 'Google Ads' THEN 'SEARCH'
            WHEN c.CHANNEL = 'Programmatic' THEN 'PROGRAMMATIC'
            ELSE 'OTHER'
        END AS CHANNEL_TYPE,
        c.CAMPAIGN_TYPE AS CAMPAIGN_OBJECTIVE,
        SUM(s.SPEND_AMOUNT) AS TOTAL_SPEND,
        SUM(s.IMPRESSIONS) AS TOTAL_IMPRESSIONS,
        SUM(s.CLICKS) AS TOTAL_CLICKS,
        SUM(s.VIDEO_VIEWS) AS TOTAL_VIDEO_VIEWS
    FROM ATOMIC.MEDIA_SPEND_DAILY s
    LEFT JOIN ATOMIC.MARKETING_CAMPAIGN_FLAT c ON s.CAMPAIGN_ID = c.CAMPAIGN_ID
    GROUP BY 1, 2, 3, 4, 5
),
WEEKLY_REVENUE_BY_CHANNEL AS (
    -- Attribute revenue to channels through: Revenue → Opportunity → Campaign → Channel
    SELECT
        DATE_TRUNC('WEEK', r.POSTING_DATE) AS WEEK_START,
        c.REGION AS REGION_NAME,
        c.CHANNEL AS CHANNEL_CODE,
        SUM(r.REVENUE_AMOUNT) AS TOTAL_REVENUE,
        COUNT(DISTINCT r.INVOICE_ID) AS TRANSACTION_COUNT
    FROM ATOMIC.ACTUAL_FINANCIAL_RESULT r
    -- Join to Opportunity to get campaign link
    JOIN ATOMIC.OPPORTUNITY o ON r.OPPORTUNITY_ID = o.OPPORTUNITY_ID
    -- Join to Campaign to get channel
    JOIN ATOMIC.MARKETING_CAMPAIGN_FLAT c ON o.CAMPAIGN_ID = c.CAMPAIGN_ID
    GROUP BY 1, 2, 3
),
WEEKLY_INDICATORS AS (
    SELECT
        DATE_TRUNC('WEEK', ms.SIGNAL_DATE) AS WEEK_START,
        ms.REGION AS REGION_NAME,
        AVG(CASE WHEN ms.SIGNAL_TYPE = 'PMI' THEN ms.SIGNAL_VALUE END) AS AVG_PMI,
        AVG(CASE WHEN ms.SIGNAL_TYPE = 'SOV' THEN ms.SIGNAL_VALUE END) AS AVG_COMPETITOR_SOV
    FROM ATOMIC.MARKET_SIGNAL ms
    GROUP BY 1, 2
)
SELECT
    COALESCE(s.WEEK_START, r.WEEK_START, i.WEEK_START) AS WEEK_START,
    COALESCE(s.REGION_NAME, r.REGION_NAME, i.REGION_NAME) AS SUPER_REGION_NAME,
    COALESCE(s.REGION_NAME, r.REGION_NAME, i.REGION_NAME) AS REGION_NAME,
    NULL AS COUNTRY_NAME,
    NULL AS SEGMENT_NAME,
    NULL AS DIVISION_NAME,
    NULL AS CATEGORY_NAME,
    COALESCE(s.CHANNEL_CODE, r.CHANNEL_CODE) AS CHANNEL_CODE,
    s.CHANNEL_TYPE,
    s.CAMPAIGN_OBJECTIVE,
    -- Spend metrics
    ZEROIFNULL(s.TOTAL_SPEND) AS SPEND,
    ZEROIFNULL(s.TOTAL_IMPRESSIONS) AS IMPRESSIONS,
    ZEROIFNULL(s.TOTAL_CLICKS) AS CLICKS,
    ZEROIFNULL(s.TOTAL_VIDEO_VIEWS) AS VIDEO_VIEWS,
    0 AS ENGAGEMENTS,
    -- Revenue - now properly attributed to channel!
    ZEROIFNULL(r.TOTAL_REVENUE) AS REVENUE,
    -- Control variables
    i.AVG_PMI,
    i.AVG_COMPETITOR_SOV,
    0 AS AVG_INDUSTRY_GROWTH
FROM WEEKLY_SPEND s
FULL OUTER JOIN WEEKLY_REVENUE_BY_CHANNEL r 
    ON s.WEEK_START = r.WEEK_START 
    AND s.REGION_NAME = r.REGION_NAME
    AND s.CHANNEL_CODE = r.CHANNEL_CODE  -- KEY: Join on channel!
LEFT JOIN WEEKLY_INDICATORS i 
    ON COALESCE(s.WEEK_START, r.WEEK_START) = i.WEEK_START 
    AND COALESCE(s.REGION_NAME, r.REGION_NAME) = i.REGION_NAME;

COMMENT ON VIEW V_MMM_INPUT_WEEKLY IS 
    'Weekly MMM input with revenue properly attributed to channels via Opportunity → Campaign linkage';

-- =============================================================================
-- Update MMM.V_ROI_BY_CHANNEL to use the fixed view
-- =============================================================================
USE SCHEMA MMM;

CREATE OR REPLACE VIEW V_ROI_BY_CHANNEL AS
SELECT
    CHANNEL_CODE AS CHANNEL,
    SUM(SPEND) AS TOTAL_SPEND,
    SUM(REVENUE) AS ATTRIBUTED_REVENUE,
    DIV0(SUM(REVENUE), SUM(SPEND)) AS ROAS
FROM DIMENSIONAL.V_MMM_INPUT_WEEKLY
WHERE CHANNEL_CODE IS NOT NULL
GROUP BY 1;

COMMENT ON VIEW V_ROI_BY_CHANNEL IS 
    'ROI metrics by channel with proper revenue attribution';

-- =============================================================================
-- Update V_MMM_INPUT_WEEKLY alias in MMM schema for Streamlit queries
-- =============================================================================

CREATE OR REPLACE VIEW MMM.V_MMM_INPUT_WEEKLY AS
SELECT * FROM DIMENSIONAL.V_MMM_INPUT_WEEKLY;

-- =============================================================================
-- Verify the fix
-- =============================================================================
SELECT 'Testing V_ROI_BY_CHANNEL...' as status;

SELECT 
    CHANNEL,
    TOTAL_SPEND,
    ATTRIBUTED_REVENUE,
    ROAS
FROM MMM.V_ROI_BY_CHANNEL
ORDER BY ROAS DESC;

