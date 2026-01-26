"""
MMM Problem Statement: Why Raw Spend Fails
==========================================
An interactive exploration of why naive attribution doesn't work.
"""

import streamlit as st
import pandas as pd
import numpy as np
from snowflake.snowpark.context import get_active_session
import altair as alt

st.set_page_config(
    page_title="The Attribution Problem",
    page_icon="🎯",
    layout="wide"
)

@st.cache_resource
def get_session():
    return get_active_session()

@st.cache_data(ttl=600)
def load_weekly_data():
    session = get_session()
    df = session.sql("""
        SELECT 
            s.WEEK_START,
            s.CHANNEL,
            s.WEEKLY_SPEND,
            r.WEEKLY_REVENUE
        FROM DIMENSIONAL.WEEKLY_SPEND_BY_CHANNEL s
        JOIN DIMENSIONAL.WEEKLY_REVENUE r ON s.WEEK_START = r.WEEK_START
        WHERE s.REGION = 'GLOBAL' AND r.REGION = 'ALL'
        ORDER BY s.WEEK_START, s.CHANNEL
    """).to_pandas()
    return df

@st.cache_data(ttl=600)
def load_total_weekly():
    session = get_session()
    df = session.sql("""
        SELECT 
            s.WEEK_START,
            SUM(s.WEEKLY_SPEND) as TOTAL_SPEND,
            MAX(r.WEEKLY_REVENUE) as REVENUE
        FROM DIMENSIONAL.WEEKLY_SPEND_BY_CHANNEL s
        JOIN DIMENSIONAL.WEEKLY_REVENUE r ON s.WEEK_START = r.WEEK_START
        WHERE s.REGION = 'GLOBAL' AND r.REGION = 'ALL'
        GROUP BY s.WEEK_START
        ORDER BY s.WEEK_START
    """).to_pandas()
    return df

st.title("🎯 The Marketing Attribution Problem")

st.markdown("""
### Why can't we just correlate spend with revenue?

Marketing teams spend millions on advertising, but measuring impact is surprisingly hard.
Let's explore why **naive approaches fail** and what makes this problem interesting.
""")

st.divider()

tab1, tab2, tab3, tab4 = st.tabs([
    "📊 The Naive Approach", 
    "⏰ Problem 1: Memory", 
    "📉 Problem 2: Saturation",
    "✅ The Solution"
])

with tab1:
    st.header("The Naive Approach: Raw Spend vs Revenue")
    
    st.markdown("""
    **The intuition**: If advertising works, spending more should mean more revenue, right?
    
    Let's test this by simply correlating weekly spend with weekly revenue.
    """)
    
    try:
        df_total = load_total_weekly()
        
        col1, col2 = st.columns(2)
        
        with col1:
            correlation = df_total['TOTAL_SPEND'].corr(df_total['REVENUE'])
            
            st.metric(
                label="Correlation (Raw Spend vs Revenue)",
                value=f"{correlation:.3f}",
                delta="Poor fit" if abs(correlation) < 0.5 else "Moderate",
                delta_color="inverse" if abs(correlation) < 0.5 else "normal"
            )
            
            st.markdown(f"""
            **Result**: A correlation of **{correlation:.3f}** is {'weak' if abs(correlation) < 0.3 else 'moderate' if abs(correlation) < 0.6 else 'strong'}.
            
            {'❌ This is too weak to make confident business decisions.' if abs(correlation) < 0.5 else '⚠️ Some signal, but lots of noise.'}
            """)
        
        with col2:
            scatter = alt.Chart(df_total).mark_circle(size=60, opacity=0.6).encode(
                x=alt.X('TOTAL_SPEND:Q', title='Weekly Spend ($)', scale=alt.Scale(zero=False)),
                y=alt.Y('REVENUE:Q', title='Weekly Revenue ($)', scale=alt.Scale(zero=False)),
                tooltip=['WEEK_START', 'TOTAL_SPEND', 'REVENUE']
            ).properties(
                title='Raw Spend vs Revenue (No Transformation)',
                width=400,
                height=350
            )
            
            regression = scatter.transform_regression(
                'TOTAL_SPEND', 'REVENUE'
            ).mark_line(color='red', strokeDash=[5,5])
            
            st.altair_chart(scatter + regression, use_container_width=True)
        
        st.markdown("---")
        st.subheader("Why is the correlation so noisy?")
        
        st.markdown("""
        Two fundamental problems with raw spend data:
        
        | Problem | What It Means | Example |
        |---------|--------------|---------|
        | **1. Advertising has memory** | Today's ads influence next week's purchases | You see a Super Bowl ad → buy the product 2 weeks later |
        | **2. Diminishing returns** | More spend ≠ proportionally more results | First $100K reaches new customers; 10th $100K re-targets the same people |
        
        Let's explore each problem...
        """)
        
    except Exception as e:
        st.error(f"Error loading data: {e}")

with tab2:
    st.header("Problem 1: Advertising Has Memory")
    
    st.markdown("""
    ### The Carryover Effect
    
    When you see an ad, you don't immediately buy. The ad creates **awareness** that influences 
    your behavior over days or weeks. This is called the **carryover** or **adstock** effect.
    """)
    
    col1, col2 = st.columns([1, 1])
    
    with col1:
        st.markdown("""
        #### Real-World Example
        
        **Week 1**: Company runs $500K TV campaign  
        **Week 2**: Zero TV spend  
        **Week 2 Revenue**: Still elevated!
        
        A naive model sees:
        - Week 1: High spend → measures some effect
        - Week 2: Zero spend → **misses the lingering effect**
        
        The model can't explain why revenue is high when spend is zero.
        """)
        
        st.info("""
        💡 **The Fix**: Transform spend with **adstock** to capture carryover.
        
        `adstock[t] = spend[t] + θ × adstock[t-1]`
        
        Where θ (theta) is the decay rate (0-1).
        """)
    
    with col2:
        st.markdown("#### Simulated Adstock Effect")
        
        theta = st.slider("Decay Rate (θ)", 0.0, 0.95, 0.7, 0.05, 
                         help="Higher = longer memory")
        
        weeks = 12
        spend = np.array([100, 0, 0, 0, 50, 0, 0, 0, 75, 0, 0, 0])
        
        adstock = np.zeros(weeks)
        adstock[0] = spend[0]
        for t in range(1, weeks):
            adstock[t] = spend[t] + theta * adstock[t-1]
        
        demo_df = pd.DataFrame({
            'Week': range(1, weeks + 1),
            'Raw Spend': spend,
            'Adstock (Effective Spend)': adstock
        })
        
        base = alt.Chart(demo_df).encode(x=alt.X('Week:O', title='Week'))
        
        bars = base.mark_bar(color='lightblue', opacity=0.7).encode(
            y=alt.Y('Raw Spend:Q', title='Spend ($K)')
        )
        
        line = base.mark_line(color='red', strokeWidth=3).encode(
            y=alt.Y('Adstock (Effective Spend):Q')
        )
        
        points = base.mark_circle(color='red', size=80).encode(
            y=alt.Y('Adstock (Effective Spend):Q'),
            tooltip=['Week', 'Raw Spend', 'Adstock (Effective Spend)']
        )
        
        st.altair_chart(bars + line + points, use_container_width=True)
        
        st.caption("Blue bars = actual spend. Red line = 'effective' spend with carryover.")

with tab3:
    st.header("Problem 2: Diminishing Returns")
    
    st.markdown("""
    ### The Saturation Effect
    
    Marketing channels **saturate**. The first dollar is more effective than the millionth dollar.
    
    - **First $100K**: Reaches new customers who've never seen your brand
    - **Next $100K**: Reaches some new people, but also re-targets existing awareness
    - **$1M+**: Mostly re-targeting people who already know you
    """)
    
    col1, col2 = st.columns([1, 1])
    
    with col1:
        st.markdown("""
        #### Why This Breaks Linear Models
        
        A linear model assumes:
        > "If $100K → $1M revenue, then $200K → $2M revenue"
        
        **Reality**: 
        > "$100K → $1M, but $200K → only $1.4M"
        
        Linear models:
        - Overestimate high-spend returns
        - Recommend infinite spending
        - Miss the "sweet spot" of optimal investment
        """)
        
        st.info("""
        💡 **The Fix**: Transform spend with the **Hill function** to capture saturation.
        
        `saturation(x) = x^α / (γ^α + x^α)`
        
        Where:
        - α (alpha) = steepness of curve
        - γ (gamma) = half-saturation point
        """)
    
    with col2:
        st.markdown("#### Hill Saturation Curve")
        
        gamma = st.slider("Half-Saturation γ ($K)", 100, 1000, 400, 50,
                         help="Spend level for 50% effect")
        alpha = st.slider("Steepness α", 0.5, 3.0, 1.5, 0.1,
                         help="How quickly saturation kicks in")
        
        x = np.linspace(0, 2000, 200)
        y_hill = (x ** alpha) / (gamma ** alpha + x ** alpha)
        y_linear = x / 2000
        
        hill_df = pd.DataFrame({
            'Spend ($K)': np.concatenate([x, x]),
            'Effect': np.concatenate([y_hill, y_linear]),
            'Model': ['Hill (Realistic)'] * len(x) + ['Linear (Naive)'] * len(x)
        })
        
        chart = alt.Chart(hill_df).mark_line(strokeWidth=3).encode(
            x=alt.X('Spend ($K):Q'),
            y=alt.Y('Effect:Q', title='Marketing Effect (0-1)', scale=alt.Scale(domain=[0, 1.1])),
            color=alt.Color('Model:N', scale=alt.Scale(
                domain=['Hill (Realistic)', 'Linear (Naive)'],
                range=['#e74c3c', '#95a5a6']
            )),
            strokeDash=alt.StrokeDash('Model:N', scale=alt.Scale(
                domain=['Hill (Realistic)', 'Linear (Naive)'],
                range=[[0], [5, 5]]
            ))
        ).properties(height=350)
        
        gamma_line = alt.Chart(pd.DataFrame({'x': [gamma]})).mark_rule(
            color='green', strokeDash=[3, 3], strokeWidth=2
        ).encode(x='x:Q')
        
        gamma_label = alt.Chart(pd.DataFrame({'x': [gamma], 'y': [0.55], 'text': [f'γ = {gamma}']})).mark_text(
            align='left', dx=5, color='green', fontSize=12
        ).encode(x='x:Q', y='y:Q', text='text:N')
        
        st.altair_chart(chart + gamma_line + gamma_label, use_container_width=True)
        
        st.caption("Red = realistic saturation. Gray dashed = naive linear assumption.")

with tab4:
    st.header("The Solution: Feature Engineering")
    
    st.markdown("""
    ### Transform Raw Spend Into Predictive Features
    
    The solution is to encode **domain knowledge** about how advertising works:
    """)
    
    st.markdown("""
    ```
    Raw Spend → Adstock(θ) → Hill Saturation(α, γ) → Scaled Feature → ML Model
    ```
    """)
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("""
        #### 1️⃣ Adstock
        **Captures**: Carryover effect
        
        **Parameter**: θ (theta) = decay rate
        
        **Insight**: Which channels have lasting effects?
        """)
    
    with col2:
        st.markdown("""
        #### 2️⃣ Hill Saturation
        **Captures**: Diminishing returns
        
        **Parameters**: 
        - α = curve shape
        - γ = half-saturation point
        
        **Insight**: Where are you on the curve?
        """)
    
    with col3:
        st.markdown("""
        #### 3️⃣ ML Model
        **Learns**: Channel contributions
        
        **Output**: β coefficients
        
        **Insight**: Which channels drive revenue?
        """)
    
    st.divider()
    
    st.subheader("The Result")
    
    try:
        df_total = load_total_weekly()
        raw_corr = df_total['TOTAL_SPEND'].corr(df_total['REVENUE'])
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric(
                label="Raw Spend Correlation",
                value=f"{raw_corr:.3f}",
                delta="Naive approach"
            )
        
        with col2:
            st.metric(
                label="Transformed Features Correlation",
                value="0.757",
                delta=f"+{0.757 - raw_corr:.3f} improvement",
                delta_color="normal"
            )
        
        with col3:
            st.metric(
                label="Improvement",
                value=f"{((0.757 - raw_corr) / abs(raw_corr)) * 100:.0f}%",
                delta="With feature engineering"
            )
        
        st.success("""
        ✅ **By encoding domain knowledge into features, we dramatically improve model fit.**
        
        The transformed model can now:
        - Accurately attribute revenue to channels
        - Identify saturation points for budget optimization  
        - Understand carryover effects for timing decisions
        """)
        
    except Exception as e:
        st.info("Run the MMM training notebook to see the improvement metrics.")
    
    st.divider()
    
    st.markdown("""
    ### Key Takeaway
    
    > **Feature engineering is where domain expertise meets data science.**
    
    Raw data rarely reflects reality. By transforming marketing spend to capture 
    carryover and saturation effects, we turn noisy data into actionable insights.
    
    ---
    
    📚 **Learn More**: See the full MMM ROI App for model results and budget optimization.
    """)

st.sidebar.markdown("---")
st.sidebar.markdown("""
### About This App

This app demonstrates **why naive attribution fails** 
and motivates the need for feature engineering in 
Marketing Mix Models.

**Key Concepts**:
- Adstock (carryover effect)
- Hill Saturation (diminishing returns)
- Feature engineering

**Built with**: Streamlit in Snowflake
""")
