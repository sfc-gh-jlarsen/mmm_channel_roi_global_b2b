# Global B2B Marketing Mix & ROI Engine: Optimize Spend with Snowflake

For global manufacturers, fragmented marketing data across regions and channels hides the true drivers of revenue.

---

## The Cost of Inaction

![Problem Impact](images/problem-impact.png)

**$2.4M in wasted annual spend** per business unit due to inefficient "peanut butter" budget allocation. Marketing leaders struggle to correlate top-of-funnel digital spend with booked revenue that lags by 6–18 months in SAP.

---

## The Problem in Context

- **Fragmented Attribution.** Ad spend (Sprinklr) and Revenue (SAP) live in silos, making ROI calculation manual and delayed.
- **Long Sales Cycles.** The 9-month lag between a LinkedIn impression and a Distributor Invoice obscures cause-and-effect.
- **Blind Budgeting.** Without data-driven curves, regional leads cut spend indiscriminately, risking future pipeline.
- **Lost Signals.** Validating the impact of "soft" metrics like Brand Sentiment (PMI/SOV) on hard revenue is practically impossible.

---

## The Transformation

![Before After](images/before-after.png)

From spreadsheet-based lagging indicators to AI-driven predictive allocation.

---

## What We'll Achieve

- **15% Improvement in MER.** (Marketing Efficiency Ratio) by shifting budget to high-marginal-ROI channels.
- **90% Faster Planning.** Reduce quarterly planning cycles from weeks to days with automated data prep.
- **Unified Visibility.** A single view of ROI across Industrial, Healthcare, and Consumer business units.
- **Predictive Agility.** Simulate "What-If" scenarios to defend budget decisions to the CFO.

---

## Business Value

![ROI Value](images/roi-value.png)

Unlocking millions in incremental revenue by optimizing the marketing mix without increasing top-line budget.

---

## Why Snowflake

- **Unified data foundation.** Integrate Sprinklr, Salesforce, and SAP data in one governed place without ETL friction.
- **Performance that scales.** Train complex Robyn/Ridge Regression models on full historical data using Snowpark Container Services.
- **Collaboration without compromise.** Share ROI models securely across regional teams without data copying.
- **Built‑in AI/ML and apps.** Democratize data science via Cortex Analyst (Natural Language) and Streamlit interactive apps.

---

## The Data

![Data ERD](images/data-erd.png)

### Source Tables

| Table | Type | Records | Purpose |
|-------|------|---------|---------|
| `MEDIA_SPEND_DAILY` | Fact | ~100k | Daily ad spend, impressions, clicks by channel/campaign. |
| `ACTUAL_FINANCIAL_RESULT` | Fact | ~50k | Invoiced revenue from ERP (SAP) at line-item grain. |
| `OPPORTUNITY` | Fact | ~20k | CRM pipeline stages to track intermediate conversion. |
| `MARKETING_CAMPAIGN` | Dim | ~500 | Metadata linking campaigns to Business Groups. |

### Data Characteristics

- **Freshness:** Weekly batch updates to align with fiscal reporting cycles.
- **Trust:** Row-level access policies ensure Regional leads only see their Business Unit's data.
- **Relationships:** Campaigns link to Opportunities; Opportunities link to Financial Results.

---

## Solution Architecture

![Architecture](images/architecture.png)

1. **Ingest:** Raw data from Sprinklr/SAP lands in Snowflake `RAW` schema.
2. **Refine:** DBT/SQL transforms data into the `ATOMIC` schema (Golden Thread).
3. **Model:** Snowpark Python (Notebook) trains Ridge Regression models to attribute revenue.
4. **Serve:** Streamlit App consumes `MMM` Mart views for visualization and simulation.
5. **Ask:** Cortex Analyst enables natural language queries on the semantic model.

---

## How It Comes Together

1. **Ingest & Normalize.** Load and join spend/revenue data. → `sql/03_load_data.sql`
2. **Train MMM Model.** Run Ridge Regression with Adstock transformation. → `notebooks/01_mmm_training.ipynb`
3. **Deploy App.** Launch the Interactive ROI Dashboard. → `streamlit/mmm_roi_app.py`
4. **Simulate Spend.** Use sliders to predict revenue impact. → [Streamlit App Page 2]
5. **Ask Questions.** "Show me ROAS by Channel." → [Cortex Analyst]

---

## Key Visualizations

### ROI Dashboard
![Dashboard](images/dashboard-preview.png)

Exec-level view of Total Spend, Attributed Revenue, and Blended ROAS.

### Budget Simulator
Interactive "Flight Simulator" allowing users to adjust channel spend (+/- 20%) and see real-time predicted revenue impact based on model coefficients.

---

## Call to Action

**Run the Demo**

```bash
# 1. Deploy Infrastructure & Data
./deploy.sh

# 2. Train the Model
./run.sh main

# 3. Launch the App
./run.sh streamlit
```

**Customize**

- Add your own `macro_indicators.csv` to test the impact of inflation on sales.
- Modify `notebooks/01_mmm_training.ipynb` to use a different decay rate for Adstock.

---

*From peanut-butter spreading to precision-guided growth with Snowflake.*

