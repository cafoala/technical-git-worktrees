"""Data loading and feature engineering for the California-housing model.

The raw dataset ships with scikit-learn and is cached locally after the first
fetch, so the demo runs offline once the cache is warm.
"""
from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.datasets import fetch_california_housing
from sklearn.model_selection import train_test_split

RANDOM_STATE = 42
TARGET = "MedHouseVal"

# The eight raw features that ship with the dataset, in their native order.
FEATURE_NAMES_RAW = [
    "MedInc",
    "HouseAge",
    "AveRooms",
    "AveBedrms",
    "Population",
    "AveOccup",
    "Latitude",
    "Longitude",
]

# Features we engineer on top of the raw ones.
ENGINEERED_FEATURES = ["bedrooms_per_room", "rooms_per_person"]

# The full column order the model is trained and served with.
FEATURE_ORDER = FEATURE_NAMES_RAW + ENGINEERED_FEATURES


def load_raw() -> tuple[pd.DataFrame, pd.Series]:
    """Return the raw California-housing data as a ``(features, target)`` pair."""
    bunch = fetch_california_housing(as_frame=True)
    return bunch.data.copy(), bunch.target.copy()


def _safe_ratio(numerator: pd.Series, denominator: pd.Series) -> pd.Series:
    """Element-wise ``numerator / denominator``, returning 0.0 where the
    denominator is zero, NaN or produces a non-finite result."""
    num = pd.to_numeric(numerator, errors="coerce")
    den = pd.to_numeric(denominator, errors="coerce")
    ratio = num.divide(den.replace(0, np.nan))
    return ratio.replace([np.inf, -np.inf], np.nan).fillna(0.0)


def add_engineered_features(df: pd.DataFrame) -> pd.DataFrame:
    """Return a copy of ``df`` with the engineered ratio features added.

    Adds:
      * ``bedrooms_per_room`` -- ``AveBedrms / AveRooms``
      * ``rooms_per_person``  -- ``AveRooms / AveOccup``
    """
    out = df.copy()
    out["bedrooms_per_room"] = _safe_ratio(out["AveBedrms"], out["AveRooms"])
    out["rooms_per_person"] = _safe_ratio(out["AveRooms"], out["AveOccup"])
    return out


def load_dataset(*, test_size: float = 0.2):
    """Load California housing, engineer features and return a train/test split.

    Returns ``(X_train, X_test, y_train, y_test)`` with feature columns in the
    canonical :data:`FEATURE_ORDER`.
    """
    X, y = load_raw()
    X = add_engineered_features(X)[FEATURE_ORDER]
    return train_test_split(X, y, test_size=test_size, random_state=RANDOM_STATE)
