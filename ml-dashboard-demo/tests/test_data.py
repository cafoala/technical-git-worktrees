import numpy as np
import pandas as pd

from backend.data import _safe_ratio, add_engineered_features


def test_engineered_columns_are_added():
    df = pd.DataFrame(
        {
            "AveRooms": [5.0, 4.0],
            "AveBedrms": [1.0, 2.0],
            "AveOccup": [2.0, 4.0],
        }
    )
    out = add_engineered_features(df)
    assert "bedrooms_per_room" in out.columns
    assert "rooms_per_person" in out.columns
    # AveBedrms / AveRooms
    assert out["bedrooms_per_room"].iloc[0] == 0.2
    # AveRooms / AveOccup
    assert out["rooms_per_person"].iloc[0] == 2.5


def test_safe_ratio_handles_zero_denominator():
    out = _safe_ratio(pd.Series([1.0, 2.0]), pd.Series([0.0, 4.0]))
    assert out.iloc[0] == 0.0  # 1/0 -> 0.0, not inf/NaN
    assert out.iloc[1] == 0.5


def test_safe_ratio_handles_missing_values():
    out = _safe_ratio(pd.Series([np.nan, 3.0]), pd.Series([2.0, np.nan]))
    assert out.iloc[0] == 0.0
    assert out.iloc[1] == 0.0


def test_add_engineered_features_does_not_mutate_input():
    df = pd.DataFrame({"AveRooms": [5.0], "AveBedrms": [1.0], "AveOccup": [2.0]})
    add_engineered_features(df)
    assert list(df.columns) == ["AveRooms", "AveBedrms", "AveOccup"]
