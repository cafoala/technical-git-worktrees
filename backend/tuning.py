"""Bayesian hyperparameter search for the XGBoost model, using Optuna.

This module is what makes ``train.py --mode tuned`` the demo's long-running
job: it fits ``n_trials x cv`` models while a TPE (Tree-structured Parzen
Estimator) sampler -- a Bayesian optimiser -- proposes each next set of
hyperparameters from the results so far.

It is deliberately ABSENT from the ``v1.0`` tag; there, ``train.py`` falls back
to a plain baseline. That difference is what the "compare two versions"
worktree scenario shows off.
"""
from __future__ import annotations

import optuna
import xgboost as xgb
from sklearn.model_selection import cross_val_score

from .data import RANDOM_STATE

optuna.logging.set_verbosity(optuna.logging.WARNING)


def bayesian_search(X, y, *, n_trials: int = 50, cv: int = 5) -> dict:
    """Return the best XGBoost hyperparameters found by an Optuna TPE search.

    Optimises 5-fold cross-validated RMSE. Prints per-trial progress so the
    search is visible while it runs (the whole point of the live demo).
    """

    def objective(trial: optuna.Trial) -> float:
        params = {
            "n_estimators": trial.suggest_int("n_estimators", 200, 600),
            "max_depth": trial.suggest_int("max_depth", 3, 10),
            "learning_rate": trial.suggest_float("learning_rate", 0.01, 0.3, log=True),
            "subsample": trial.suggest_float("subsample", 0.6, 1.0),
            "colsample_bytree": trial.suggest_float("colsample_bytree", 0.6, 1.0),
            "min_child_weight": trial.suggest_int("min_child_weight", 1, 10),
            "reg_lambda": trial.suggest_float("reg_lambda", 1e-3, 10.0, log=True),
        }
        model = xgb.XGBRegressor(
            **params, random_state=RANDOM_STATE, n_jobs=-1, tree_method="hist"
        )
        scores = cross_val_score(
            model, X, y, cv=cv, scoring="neg_root_mean_squared_error", n_jobs=1
        )
        return float(-scores.mean())

    sampler = optuna.samplers.TPESampler(seed=RANDOM_STATE)
    study = optuna.create_study(direction="minimize", sampler=sampler)

    def _progress(study: optuna.Study, trial: optuna.Trial) -> None:
        print(
            f"[tune] trial {trial.number + 1}/{n_trials}  "
            f"rmse={trial.value:.4f}  best={study.best_value:.4f}",
            flush=True,
        )

    study.optimize(objective, n_trials=n_trials, callbacks=[_progress])
    print(f"[tune] best RMSE={study.best_value:.4f}  params={study.best_params}",
          flush=True)
    return dict(study.best_params)
