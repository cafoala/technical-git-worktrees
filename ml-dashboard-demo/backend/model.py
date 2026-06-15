"""Load the trained model + metrics and run predictions."""
from __future__ import annotations

import json
import os

import pandas as pd
import xgboost as xgb

from .data import FEATURE_ORDER, add_engineered_features

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(ROOT, "models")
MODEL_PATH = os.path.join(MODELS_DIR, "model.json")
METRICS_PATH = os.path.join(MODELS_DIR, "metrics.json")


def model_exists() -> bool:
    """True once a model and its metrics have been written by ``train.py``."""
    return os.path.exists(MODEL_PATH) and os.path.exists(METRICS_PATH)


def load_metrics() -> dict:
    """Return the metrics dict written alongside the model."""
    with open(METRICS_PATH, encoding="utf-8") as fh:
        return json.load(fh)


def load_model() -> xgb.XGBRegressor:
    """Load the trained XGBoost regressor from disk."""
    model = xgb.XGBRegressor()
    model.load_model(MODEL_PATH)
    return model


def predict(model: xgb.XGBRegressor, X: pd.DataFrame):
    """Predict median house value for a frame of **raw** features.

    Engineered features are added here, so callers only need to supply the
    eight raw columns. Columns are reordered to the canonical training order.
    """
    feats = add_engineered_features(X)[FEATURE_ORDER]
    return model.predict(feats)
