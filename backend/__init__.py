"""Backend for the California-housing price model.

Responsibilities:
  * ``data``    -- load the dataset and engineer features
  * ``train``   -- fit the model (baseline or Bayesian-tuned) and write artifacts
  * ``tuning``  -- the Optuna Bayesian search (the demo's long-running job)
  * ``model``   -- load the trained artifacts and run predictions
"""

__version__ = "1.0.0"
