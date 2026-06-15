import numpy as np
import pandas as pd
import xgboost as xgb

from backend.data import add_engineered_features
from backend.model import predict


def _raw_frame(n: int = 25) -> pd.DataFrame:
    rng = np.random.default_rng(0)
    return pd.DataFrame(
        {
            "MedInc": rng.uniform(1, 10, n),
            "HouseAge": rng.uniform(1, 50, n),
            "AveRooms": rng.uniform(3, 8, n),
            "AveBedrms": rng.uniform(0.8, 1.5, n),
            "Population": rng.uniform(100, 3000, n),
            "AveOccup": rng.uniform(1, 5, n),
            "Latitude": rng.uniform(32, 42, n),
            "Longitude": rng.uniform(-124, -114, n),
        }
    )


def test_predict_adds_features_and_returns_one_value_per_row():
    raw = _raw_frame(25)
    target = raw["MedInc"] * 0.4 + raw["AveRooms"] * 0.1
    model = xgb.XGBRegressor(n_estimators=10, max_depth=2, random_state=0)
    model.fit(add_engineered_features(raw), target)

    # predict() is given RAW features only; it must engineer them internally.
    preds = predict(model, raw)
    assert len(preds) == len(raw)
    assert np.isfinite(preds).all()
