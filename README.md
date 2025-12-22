# Global B2B Marketing Mix Modeling (MMM) & ROI Engine

A comprehensive Marketing Mix Modeling solution built on Snowflake, enabling B2B enterprises to attribute revenue to marketing channels and optimize budget allocation.

## Business Problem

For global B2B enterprises, marketing data is fragmented across:
- **Ad Platforms** (Sprinklr) — Impressions, Clicks, Spend
- **CRM** (Salesforce) — Pipeline, Opportunities
- **ERP** (SAP) — Booked Revenue

Traditional attribution fails because B2B sales cycles span 6-18 months and revenue flows through distributor partners. This solution provides:

- **Unified Attribution**: Connect marketing spend to actual revenue with proper time lags
- **ROI by Channel**: Understand true return on investment per marketing channel
- **Budget Optimization**: Simulate reallocation scenarios and predict revenue impact

## Target Outcomes

| Metric | Target |
|--------|--------|
| Marketing Efficiency Ratio | 15% improvement |
| Budget Decision Cycles | 2x faster |

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Sprinklr   │    │ Salesforce  │    │    SAP      │
│  (Ad Spend) │    │ (Pipeline)  │    │ (Revenue)   │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
       └──────────────────┴──────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │      Snowflake        │
              │  ┌─────────────────┐  │
              │  │  Snowpark ML    │  │
              │  │  (MMM Training) │  │
              │  └─────────────────┘  │
              │  ┌─────────────────┐  │
              │  │   Cortex AI     │  │
              │  │   (Analyst)     │  │
              │  └─────────────────┘  │
              └───────────┬───────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │   Streamlit App       │
              │  (Interactive UI)     │
              └───────────────────────┘
```

## User Personas

| Persona | Role | Primary View |
|---------|------|--------------|
| **Strategic** | CMO / VP Marketing | Executive Dashboard with ROI attribution |
| **Operational** | Regional Demand Lead | Budget Simulator for what-if scenarios |
| **Technical** | Data Scientist | Model Explorer with diagnostics & Cortex Analyst |

## Project Structure

```
├── cortex/
│   └── mmm_semantic_model.yaml    # Cortex Analyst semantic model
├── data/
│   ├── synthetic/                 # Synthetic demo data
│   ├── ref_geography.csv          # Reference data
│   ├── ref_marketing_channel.csv
│   └── ref_product_category.csv
├── notebooks/
│   └── 01_mmm_training.ipynb      # MMM training pipeline
├── sql/
│   ├── 01_account_setup.sql       # Snowflake account configuration
│   ├── 02_schema_setup.sql        # Database/schema creation
│   ├── 03_dimensional_views.sql   # Dimensional views for analysis
│   ├── 03_load_data.sql           # Data loading scripts
│   ├── 04_cortex_setup.sql        # Cortex AI configuration
│   └── 05_fix_attribution.sql     # Attribution logic fixes
├── streamlit/
│   ├── mmm_roi_app.py             # Home page (persona routing)
│   ├── pages/
│   │   ├── 1_Strategic_Dashboard.py
│   │   ├── 2_Simulator.py
│   │   ├── 3_Model_Explorer.py
│   │   └── 4_About.py
│   └── utils/
│       ├── data_loader.py         # Parallel query execution
│       ├── styling.py             # Brand CSS & theming
│       ├── cortex_analyst.py      # Cortex Analyst integration
│       ├── map_viz.py             # Map visualization utilities
│       └── explanations.py        # Text generation utilities
├── deploy.sh                      # Deployment script
├── run.sh                         # Runtime operations script
└── DRD.md                         # Design Requirements Document
```

## Quick Start

### 1. Setup Snowflake Environment

```bash
# Run SQL setup scripts in order
snow sql -f sql/01_account_setup.sql
snow sql -f sql/02_schema_setup.sql
snow sql -f sql/03_load_data.sql
snow sql -f sql/03_dimensional_views.sql
snow sql -f sql/04_cortex_setup.sql
snow sql -f sql/05_fix_attribution.sql
```

Alternatively, you can use the deployment script:
```bash
./deploy.sh
# Note: You may need to manually run the additional SQL scripts if using deploy.sh
```

### 2. Train the MMM Model

You can run the notebook directly or use the helper script:

```bash
./run.sh main
```

Or open `notebooks/01_mmm_training.ipynb` in Snowflake Notebooks and run all cells. This will:
- Load weekly marketing and revenue data
- Apply Adstock and Saturation transformations
- Optimize hyperparameters using Nevergrad
- Save model results and response curves to Snowflake

### 3. Deploy the Streamlit App

```bash
./deploy.sh
```

To get the Streamlit app URL after deployment:
```bash
./run.sh streamlit
```

## Key Features

### Executive Dashboard
- KPI cards: Total Spend, Attributed Revenue, Blended ROAS
- Waterfall chart showing channel contributions
- AI-generated recommendations for budget reallocation

### Budget Simulator
- Interactive sliders to adjust spend per channel
- Real-time revenue predictions using response curves
- Before/after comparison visualizations

### Model Explorer
- Exploratory data analysis (trends, correlations)
- Model diagnostics (coefficients, R² score)
- Interactive response curves
- Cortex Analyst for natural language queries

### About Page
- Business pitch deck summary
- Architecture overview
- Success metrics and technology stack

## Technology Stack

- **Snowflake**: Data warehouse, compute, governance
- **Snowpark ML**: Python ML training on Snowflake
- **Cortex AI**: Natural language analytics
- **Streamlit**: Interactive web application
- **Nevergrad**: Hyperparameter optimization
- **Plotly**: Data visualization

## License

See [LICENSE](LICENSE) for details.
