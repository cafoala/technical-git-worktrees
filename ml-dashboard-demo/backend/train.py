"""Train the California-housing price model.

Two modes:

  baseline   default XGBoost hyperparameters -- fast, the v1.0 behaviour.
  tuned      Optuna Bayesian hyperparameter search -- slow, the demo's long
             job. Requires ``backend/tuning.py`` (added on ``main``; absent at
             the ``v1.0`` tag, where this transparently falls back to baseline).

Usage:
    python -m backend.train                 # tuned (default), N_TRIALS trials
    python -m backend.train --mode baseline  # quick baseline
    python -m backend.train --trials 80      # longer search

Artifacts are written atomically to ``models/`` so the live dashboard never
reads a half-written file mid-training.
"""
from __future__ import annotations

import argparse
import json
import os
import tempfile
from datetime import datetime

import numpy as np
import xgboost as xgb
from sklearn.metrics import mean_squared_error, r2_score

from .data import RANDOM_STATE, load_dataset
from .model import METRICS_PATH, MODEL_PATH, MODELS_DIR

DEFAULT_TRIALS = int(os.environ.get("N_TRIALS", "50"))

# Sensible defaults used for --mode baseline and as the fallback at v1.0.
BASELINE_PARAMS = dict(
    n_estimators=300,
    max_depth=6,
    learning_rate=0.1,
    subsample=0.9,
    colsample_bytree=0.9,
)


def _rmse(y_true, y_pred) -> float:
    return float(np.sqrt(mean_squared_error(y_true, y_pred)))


def _atomic_write_json(path: str, obj: dict) -> None:
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, indent=2)
    os.replace(tmp, path)


def _save(model: xgb.XGBRegressor, metrics: dict) -> None:
    os.makedirs(MODELS_DIR, exist_ok=True)
    # keep a .json suffix so XGBoost writes JSON (not UBJSON) without warning
    tmp_model = MODEL_PATH + ".tmp.json"
    model.save_model(tmp_model)
    os.replace(tmp_model, MODEL_PATH)
    _atomic_write_json(METRICS_PATH, metrics)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Train the housing price model.")
    parser.add_argument(
        "--mode", choices=["baseline", "tuned"], default="tuned",
        help="baseline params or a Bayesian (Optuna) hyperparameter search",
    )
    parser.add_argument(
        "--trials", type=int, default=DEFAULT_TRIALS,
        help="number of Optuna trials in tuned mode (env: N_TRIALS)",
    )
    args = parser.parse_args(argv)

    print(f"[train] loading data ...", flush=True)
    X_train, X_test, y_train, y_test = load_dataset()

    mode = args.mode
    params = dict(BASELINE_PARAMS)

    if mode == "tuned":
        try:
            from .tuning import bayesian_search
        except ModuleNotFoundError:
            print(
                "[train] no tuning module on this checkout (the v1.0 baseline) "
                "-> running --mode baseline instead.",
                flush=True,
            )
            mode = "baseline"
        else:
            print(f"[train] Bayesian hyperparameter search: {args.trials} trials ...",
                  flush=True)
            params = bayesian_search(X_train, y_train, n_trials=args.trials)

    print(f"[train] fitting final model ({mode}) ...", flush=True)
    model = xgb.XGBRegressor(
        **params, random_state=RANDOM_STATE, n_jobs=-1, tree_method="hist"
    )
    model.fit(X_train, y_train)

    preds = model.predict(X_test)
    importances = {
        feat: float(imp)
        for feat, imp in zip(model.feature_names_in_, model.feature_importances_)
    }
    metrics = {
        "mode": mode,
        "rmse": _rmse(y_test, preds),
        "r2": float(r2_score(y_test, preds)),
        "best_params": params,
        "feature_importances": importances,
        "n_train": int(len(X_train)),
        "n_test": int(len(X_test)),
        "trained_at": datetime.now().isoformat(timespec="seconds"),
    }
    _save(model, metrics)
    print(f"[train] done. mode={mode}  RMSE={metrics['rmse']:.4f}  "
          f"R2={metrics['r2']:.4f}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
