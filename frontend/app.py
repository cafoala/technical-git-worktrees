"""Streamlit dashboard for the California-housing price model.

Run from the repo root:  streamlit run frontend/app.py [--port 8501]
It reads the artifacts written by ``backend/train.py`` and refreshes itself
whenever a new model is trained.
"""
from __future__ import annotations

import os
import sys

# Make the repo root importable regardless of how Streamlit launches this file.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pandas as pd
import plotly.express as px
import streamlit as st

from backend import model as M
from backend.data import load_dataset
from frontend import theme

st.set_page_config(
    page_title="California Housing — Price Model",
    page_icon="🏠",
    layout="wide",
)

st.title("🏠 California Housing — Price Model Dashboard")

if not M.model_exists():
    st.info(
        "⏳ No trained model yet. Run `python -m backend.train` "
        "to train one — this dashboard updates automatically when it finishes."
    )
    st.stop()

metrics = M.load_metrics()
# mtime is the cache key: when training writes a new model, the caches refresh.
mtime = os.path.getmtime(M.METRICS_PATH)


@st.cache_resource
def _get_model(_mtime: float):
    return M.load_model()


@st.cache_data
def _get_predictions(_mtime: float) -> pd.DataFrame:
    X_train, X_test, y_train, y_test = load_dataset()
    model = _get_model(_mtime)
    preds = model.predict(X_test)
    df = X_test.copy()
    df["actual"] = y_test.to_numpy()
    df["predicted"] = preds
    df["residual"] = df["predicted"] - df["actual"]
    df["direction"] = df["residual"].apply(
        lambda r: "Over-prediction" if r > 0 else "Under-prediction"
    )
    return df


model = _get_model(mtime)
df = _get_predictions(mtime)

# --- headline metrics -------------------------------------------------------
c1, c2, c3, c4 = st.columns(4)
c1.metric("RMSE", f"{metrics['rmse']:.3f}")
c2.metric("R²", f"{metrics['r2']:.3f}")
c3.metric("Mode", metrics["mode"])
c4.metric("Trained at", metrics.get("trained_at", "—"))

DIRECTION_COLORS = {
    "Over-prediction": theme.OVER_PRED,
    "Under-prediction": theme.UNDER_PRED,
}

left, right = st.columns(2)

# --- feature importance -----------------------------------------------------
with left:
    imp = (
        pd.Series(metrics["feature_importances"], name="importance")
        .sort_values()
        .reset_index()
        .rename(columns={"index": "feature"})
    )
    fig_imp = px.bar(
        imp,
        x="importance",
        y="feature",
        orientation="h",
        color="feature",
        color_discrete_sequence=theme.PALETTE,
        title="Feature importance",
    )
    fig_imp.update_layout(showlegend=False)
    st.plotly_chart(fig_imp, use_container_width=True)

# --- predicted vs actual ----------------------------------------------------
with right:
    sample = df.sample(min(2000, len(df)), random_state=0)
    fig_pva = px.scatter(
        sample,
        x="actual",
        y="predicted",
        color="direction",
        color_discrete_map=DIRECTION_COLORS,
        opacity=0.5,
        title="Predicted vs actual (coloured by error direction)",
        labels={"actual": "Actual ($100k)", "predicted": "Predicted ($100k)"},
    )
    lo = float(min(sample["actual"].min(), sample["predicted"].min()))
    hi = float(max(sample["actual"].max(), sample["predicted"].max()))
    fig_pva.add_shape(type="line", x0=lo, y0=lo, x1=hi, y1=hi,
                      line=dict(color="#444", dash="dash"))
    st.plotly_chart(fig_pva, use_container_width=True)

# --- residuals --------------------------------------------------------------
fig_res = px.histogram(
    df,
    x="residual",
    color="direction",
    color_discrete_map=DIRECTION_COLORS,
    nbins=60,
    title="Residuals — over- vs under-prediction",
    labels={"residual": "Predicted − actual ($100k)"},
)
st.plotly_chart(fig_res, use_container_width=True)

# --- optional colleague feature (present only on feature/whatif-predictor) --
try:
    from frontend.whatif import render_whatif
except ModuleNotFoundError:
    pass
else:
    st.divider()
    render_whatif(model)
