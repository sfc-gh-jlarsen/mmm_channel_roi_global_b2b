from concurrent.futures import ThreadPoolExecutor, as_completed
import pandas as pd
import logging
import time
from typing import Dict

logger = logging.getLogger(__name__)


# =============================================================================
# Centralized Query Definitions - Single source of truth for all SQL queries
# =============================================================================
QUERIES = {
    # Weekly input data for MMM - Note: View is in DIMENSIONAL schema
    "WEEKLY": "SELECT * FROM DIMENSIONAL.V_MMM_INPUT_WEEKLY ORDER BY WEEK_START",
    
    # Response curves from model training
    "CURVES": "SELECT * FROM MMM.RESPONSE_CURVES",
    
    # Model results - get all results (MODEL_RESULTS has no CREATED_AT column)
    "RESULTS": "SELECT * FROM MMM.MODEL_RESULTS",
    
    # ROI summary by channel
    "ROI": "SELECT * FROM MMM.V_ROI_BY_CHANNEL",
    
    # Model metadata - latest run
    "METADATA": "SELECT * FROM MMM.MODEL_METADATA ORDER BY MODEL_RUN_DATE DESC LIMIT 1",
    
    # ROI by channel and region (from view)
    "ROI_REGION": "SELECT * FROM MMM.V_ROI_BY_CHANNEL_REGION",
    
    # Regional aggregates from model results
    # Extracts region from CHANNEL name (e.g., 'Facebook_NA_ALL' -> 'NA')
    "RESULTS_BY_REGION": """
        SELECT 
            SPLIT_PART(CHANNEL, '_', -2) as REGION,
            AVG(ROI) as AVG_ROI,
            SUM(CURRENT_SPEND) as TOTAL_SPEND,
            AVG(MARGINAL_ROI) as AVG_MARGINAL_ROI,
            COUNT(*) as CHANNEL_COUNT,
            ARRAY_AGG(CHANNEL) as CHANNELS
        FROM MMM.MODEL_RESULTS
        GROUP BY SPLIT_PART(CHANNEL, '_', -2)
        ORDER BY AVG_ROI DESC
    """,
}


def run_queries_parallel(
    session,
    queries: Dict[str, str],
    max_workers: int = 4,
    return_empty_on_error: bool = True
) -> Dict[str, pd.DataFrame]:
    """
    Execute multiple independent SQL queries in parallel.
    
    Args:
        session: Snowflake Snowpark session
        queries: Dict mapping names to SQL strings
        max_workers: Max concurrent queries (4 recommended for Snowflake)
        return_empty_on_error: Return empty DataFrame on failure vs raise
    
    Returns:
        Dict mapping query names to result DataFrames
    """
    if not queries:
        return {}
    
    start_time = time.time()
    results: Dict[str, pd.DataFrame] = {}
    
    def execute_query(name: str, query: str) -> tuple:
        try:
            df = session.sql(query).to_pandas()
            return name, df
        except Exception as e:
            logger.error(f"Query '{name}' failed: {e}")
            if return_empty_on_error:
                return name, pd.DataFrame()
            raise
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_name = {
            executor.submit(execute_query, name, query): name
            for name, query in queries.items()
        }
        
        for future in as_completed(future_to_name):
            name = future_to_name[future]
            try:
                query_name, result_df = future.result()
                results[query_name] = result_df
            except Exception as e:
                if return_empty_on_error:
                    results[name] = pd.DataFrame()
                else:
                    raise
    
    logger.info(f"Parallel execution: {len(queries)} queries in {time.time() - start_time:.2f}s")
    return results

