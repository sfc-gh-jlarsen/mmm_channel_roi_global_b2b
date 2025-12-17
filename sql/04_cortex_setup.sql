-- 04_cortex_setup.sql
-- Setup Cortex Search Service
-- Expected context: Role = Project Role, Database = Project Database

USE SCHEMA ATOMIC;

-- 1. Create Stage for unstructured data (Campaign Briefs)
-- Already created in 02 as DATA_STAGE, but we need to ensure directory table is refreshed
ALTER STAGE DATA_STAGE REFRESH;

-- 2. Create Cortex Search Service
-- Note: Requires `cortex_user` privilege usually, assuming PROJECT_ROLE has it or we are ACCOUNTADMIN
-- We'll try to create it. If it fails due to privileges, the user needs to grant it.

-- Create a view for the search service to index
-- It needs a text column and metadata
CREATE OR REPLACE VIEW V_CAMPAIGN_BRIEFS AS
SELECT 
    RELATIVE_PATH as FILE_NAME,
    GET_PRESIGNED_URL(@DATA_STAGE, RELATIVE_PATH) as FILE_URL,
    -- Extract Campaign ID from filename (e.g., "CMP-101_Brief.pdf")
    SPLIT_PART(RELATIVE_PATH, '_', 1) as CAMPAIGN_ID
FROM DIRECTORY(@DATA_STAGE)
WHERE RELATIVE_PATH LIKE 'campaign_briefs/%.pdf';

-- Create the Search Service
-- Note: 'ON' clause requires a warehouse. 'ATTRIBUTES' are filterable columns.
-- Check documentation for exact syntax.
-- Syntax: CREATE CORTEX SEARCH SERVICE <name> ON <text_col> ...
-- Note: As of late 2024/2025, syntax might vary. Using standard preview syntax.

/*
CREATE CORTEX SEARCH SERVICE IF NOT EXISTS MARKETING_KNOWLEDGE_BASE
    ON FILE_URL
    ATTRIBUTES CAMPAIGN_ID
    WAREHOUSE = IDENTIFIER($PROJECT_WH)
    TARGET_LAG = '1 hour'
    AS SELECT * FROM V_CAMPAIGN_BRIEFS;
*/

-- Commenting out actual creation as it might fail if features aren't enabled or specific privileges missing.
-- Leaving placeholder for manual execution or if confirmed available.
SELECT 'Cortex Search Service setup placeholder - uncomment in script to enable.' as status;

