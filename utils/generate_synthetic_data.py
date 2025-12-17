import pandas as pd
import numpy as np
import random
import os
import datetime
from datetime import timedelta
from faker import Faker
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter

# --- Constants & Configuration ---
RANDOM_SEED = 42
OUTPUT_DIR = "data/synthetic"
BRIEFS_DIR = os.path.join(OUTPUT_DIR, "campaign_briefs")
START_DATE = datetime.date(2022, 1, 1)
END_DATE = datetime.date(2024, 12, 31)
DAYS = (END_DATE - START_DATE).days + 1

# Taxonomy Components
BGS = ["SIBG", "HCBG", "TEBG", "CBG"]
REGIONS = ["NA", "EMEA", "APAC", "LATAM"]
DIVISIONS = {
    "SIBG": ["ASD", "PSD"],
    "HCBG": ["MSD", "HIS"],
    "TEBG": ["EMSD", "AD"],
    "CBG": ["CHIM", "HIC"]
}
TYPES = ["Brand", "LeadGen", "Nurture"]
CHANNELS = ["LinkedIn", "Google Ads", "Programmatic", "Facebook"]

# --- Initialization ---
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)
fake = Faker()
Faker.seed(RANDOM_SEED)

def ensure_directories():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(BRIEFS_DIR, exist_ok=True)

# --- Helper Functions ---

def get_fiscal_week(date_obj):
    return f"{date_obj.year}-W{date_obj.isocalendar()[1]:02d}"

def generate_campaigns(num_campaigns=50):
    campaigns = []
    for i in range(num_campaigns):
        bg = random.choice(BGS)
        region = random.choice(REGIONS)
        division = random.choice(DIVISIONS[bg])
        ctype = random.choice(TYPES)
        cid = f"CMP-{100+i}"
        name = f"{bg}_{region}_{division}_{ctype}_{cid}"
        
        # Assign primary channel based on type preferences
        if ctype == "Brand":
            channel = random.choices(CHANNELS, weights=[0.4, 0.1, 0.4, 0.1])[0] # Heavy LinkedIn/Prog
        else:
            channel = random.choices(CHANNELS, weights=[0.3, 0.5, 0.1, 0.1])[0] # Heavy Search/LinkedIn
            
        campaigns.append({
            "CAMPAIGN_ID": cid,
            "CAMPAIGN_NAME": name,
            "BG": bg,
            "REGION": region,
            "DIVISION": division,
            "TYPE": ctype,
            "CHANNEL": channel,
            "START_DATE": START_DATE + timedelta(days=random.randint(0, DAYS - 90)),
            "DURATION": random.randint(30, 90) # Days
        })
    return pd.DataFrame(campaigns)

def generate_spend(campaigns_df):
    spend_records = []
    
    for _, camp in campaigns_df.iterrows():
        # Seasonal multiplier (Q1/Q3 spikes)
        start = camp["START_DATE"]
        for day_offset in range(camp["DURATION"]):
            current_date = start + timedelta(days=day_offset)
            if current_date > END_DATE:
                break
                
            month = current_date.month
            seasonality = 1.0
            if month in [1, 2, 3, 7, 8, 9]: # Q1 and Q3
                seasonality = 1.5
            
            # Channel CPMs
            cpm = 50 if camp["CHANNEL"] == "LinkedIn" else (10 if camp["CHANNEL"] == "Facebook" else 20)
            
            # Base spend with noise
            base_spend = np.random.uniform(500, 5000) * seasonality
            
            # Injection: Healthcare LinkedIn Boost
            if camp["BG"] == "HCBG" and camp["CHANNEL"] == "LinkedIn":
                base_spend *= 1.2
                
            impressions = int((base_spend / cpm) * 1000)
            ctr = 0.005 if camp["CHANNEL"] == "LinkedIn" else 0.02
            clicks = int(impressions * ctr)
            
            spend_records.append({
                "DATE": current_date,
                "CAMPAIGN_ID": camp["CAMPAIGN_ID"],
                "CHANNEL": camp["CHANNEL"],
                "SPEND_AMT": round(base_spend, 2),
                "IMPRESSIONS": impressions,
                "CLICKS": clicks,
                "VIDEO_VIEWS_50": int(impressions * 0.1) if camp["TYPE"] == "Brand" else 0
            })
            
    return pd.DataFrame(spend_records)

def generate_opportunities(spend_df, campaigns_df):
    opps = []
    campaign_lookup = campaigns_df.set_index("CAMPAIGN_ID").to_dict("index")
    
    # Identify high-spend days to trigger opportunities
    # Simplified: Random sample of spend records trigger leads
    trigger_records = spend_df.sample(frac=0.1, random_state=RANDOM_SEED)
    
    for _, row in trigger_records.iterrows():
        camp = campaign_lookup[row["CAMPAIGN_ID"]]
        
        # Lag: 2-6 weeks
        lag_days = random.randint(14, 42)
        created_date = row["DATE"] + timedelta(days=lag_days)
        
        if created_date > END_DATE:
            continue
            
        # Win Rate Injection
        base_win_rate = 0.2
        if camp["CHANNEL"] == "LinkedIn":
            base_win_rate = 0.25 # 25% higher
            
        stage = np.random.choice(
            ["Closed Won", "Closed Lost", "Negotiation", "Discovery"], 
            p=[base_win_rate, 0.4, 0.2, 1.0 - base_win_rate - 0.6]
        )
        
        # Close date logic
        cycle_days = random.randint(90, 270) # Long B2B cycle
        close_date = created_date + timedelta(days=cycle_days)
        
        opps.append({
            "OPPORTUNITY_ID": f"OPP-{fake.uuid4()[:8]}",
            "ACCOUNT_NAME": fake.company(),
            "LEAD_SOURCE_CAMPAIGN": row["CAMPAIGN_ID"],
            "STAGE": stage,
            "AMOUNT_USD": round(np.random.lognormal(10, 1), 2), # ~$22k avg, fat tail
            "CREATED_DATE": created_date,
            "CLOSE_DATE": close_date if stage in ["Closed Won", "Closed Lost"] else None,
            "BUSINESS_GROUP": camp["BG"]
        })
        
    return pd.DataFrame(opps)

def generate_revenue(opps_df):
    # Revenue comes from Closed Won opportunities
    # Lag from Close Date to Invoice (SAP) is short, but total lag from Spend is handled by Opp Cycle
    
    won_opps = opps_df[opps_df["STAGE"] == "Closed Won"]
    invoices = []
    
    for _, opp in won_opps.iterrows():
        # Generate 1-3 invoices per deal
        num_invoices = random.randint(1, 3)
        total_amt = opp["AMOUNT_USD"]
        
        for i in range(num_invoices):
            # Invoice lag 15-45 days after close
            inv_date = opp["CLOSE_DATE"] + timedelta(days=random.randint(15, 45) * (i+1))
            
            if inv_date > END_DATE:
                continue
                
            invoices.append({
                "INVOICE_ID": f"INV-{fake.uuid4()[:8]}",
                "BOOKED_REVENUE": round(total_amt / num_invoices, 2),
                "PROFIT_CENTER": f"PC_{opp['BUSINESS_GROUP']}_NA", # Simplified
                "POSTING_DATE": inv_date,
                "OPPORTUNITY_ID": opp["OPPORTUNITY_ID"]
            })
            
    return pd.DataFrame(invoices)

def generate_macro_data():
    dates = [START_DATE + timedelta(days=i) for i in range(DAYS)]
    data = []
    
    for d in dates:
        # PMI varies between 45 and 60 with sine wave trend
        pmi = 52 + 5 * np.sin(d.toordinal() / 365.0 * 2 * np.pi) + np.random.normal(0, 0.5)
        
        # Competitor SOV - Inverse to our spend (simplified)
        comp_sov = np.random.uniform(0.1, 0.4)
        
        if d.weekday() == 0: # Weekly grain usually, but daily for file
            data.append({
                "DATE": d,
                "PMI_INDEX": round(pmi, 2),
                "COMPETITOR_SOV": round(comp_sov, 3),
                "REGION": "NA" # Simplified
            })
            
    return pd.DataFrame(data)

def generate_campaign_briefs(campaigns_df):
    # Generate simple PDF briefs for Cortex Search
    for _, camp in campaigns_df.iterrows():
        filename = f"{camp['CAMPAIGN_ID']}_Brief.pdf"
        filepath = os.path.join(BRIEFS_DIR, filename)
        
        c = canvas.Canvas(filepath, pagesize=letter)
        c.drawString(100, 750, f"Campaign Strategy Brief: {camp['CAMPAIGN_NAME']}")
        c.drawString(100, 730, f"ID: {camp['CAMPAIGN_ID']}")
        c.drawString(100, 710, f"Objective: Drive {camp['BG']} growth in {camp['REGION']}")
        c.drawString(100, 690, f"Channel Strategy: Heavy investment in {camp['CHANNEL']} to target decision makers.")
        c.drawString(100, 670, f"Key Message: 'Innovation in {camp['DIVISION']} leads to safety and efficiency.'")
        c.drawString(100, 650, f"Target Audience: Procurement Managers, Engineers in {camp['REGION']}.")
        c.save()

# --- Main Execution ---

def main():
    print(f"Generating synthetic data to {OUTPUT_DIR}...")
    ensure_directories()
    
    print("1. Generating Campaigns...")
    campaigns_df = generate_campaigns(75)
    campaigns_df.to_csv(os.path.join(OUTPUT_DIR, "campaign_metadata.csv"), index=False)
    
    print("2. Generating Spend (Sprinklr)...")
    spend_df = generate_spend(campaigns_df)
    spend_df.to_csv(os.path.join(OUTPUT_DIR, "sprinklr_spend.csv"), index=False)
    
    print("3. Generating Opportunities (Salesforce)...")
    opps_df = generate_opportunities(spend_df, campaigns_df)
    opps_df.to_csv(os.path.join(OUTPUT_DIR, "salesforce_opps.csv"), index=False)
    
    print("4. Generating Revenue (SAP)...")
    rev_df = generate_revenue(opps_df)
    rev_df.to_csv(os.path.join(OUTPUT_DIR, "sap_revenue.csv"), index=False)
    
    print("5. Generating Macro Indicators...")
    macro_df = generate_macro_data()
    macro_df.to_csv(os.path.join(OUTPUT_DIR, "macro_indicators.csv"), index=False)
    
    print("6. Generating Campaign Briefs (PDFs)...")
    generate_campaign_briefs(campaigns_df)
    
    print("Data generation complete.")

if __name__ == "__main__":
    main()

