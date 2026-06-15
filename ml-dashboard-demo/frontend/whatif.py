"""Interactive 'what-if' price predictor panel.

This module lives ONLY on the ``feature/whatif-predictor`` branch — it's the
colleague's unmerged work used by the "review a branch side-by-side" scenario.
``app.py`` imports it inside a try/except, so on ``main`` (where this file is
absent) the panel simply doesn't appear.
"""
from __future__ import annotations

import pandas as pd
import streamlit as st

from backend.model import predict


def render_whatif(model) -> None:
    """Render sliders for the key features and show the model's live prediction."""
    st.subheader("🔮 What-if predictor")
    st.caption("Adjust the inputs to see the model's predicted median house value.")

    c1, c2, c3, c4 = st.columns(4)
    med_inc = c1.slider("Median income (×$10k)", 0.5, 15.0, 3.9, 0.1)
    house_age = c2.slider("House age (years)", 1, 52, 28)
    ave_rooms = c3.slider("Avg rooms / household", 1.0, 12.0, 5.4, 0.1)
    ave_occup = c4.slider("Avg occupants / household", 1.0, 6.0, 3.0, 0.1)

    row = pd.DataFrame([{
        "MedInc": med_inc,
        "HouseAge": float(house_age),
        "AveRooms": ave_rooms,
        "AveBedrms": ave_rooms * 0.2,
        "Population": 1425.0,
        "AveOccup": ave_occup,
        "Latitude": 34.2,
        "Longitude": -118.4,
    }])
    pred = float(predict(model, row)[0])
    st.metric("Predicted median house value", f"${pred * 100_000:,.0f}")
