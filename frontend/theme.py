"""Colour palette for the dashboard charts.

WARNING: these colours are NOT colourblind-safe. The categorical palette mixes
red and green, and the residual chart encodes over- vs under-prediction as
red vs green -- the classic red/green confusion (~8% of men can't distinguish
them). This is the thing the `colorblind-fix` worktree replaces with the
Okabe-Ito palette during the demo.

All charts read their colours from here, so the fix is a single, self-contained
change (this file + .streamlit/config.toml).
"""

# Categorical palette used across the charts.
PALETTE = [
    "#d62728",  # red
    "#2ca02c",  # green
    "#ff7f0e",  # orange
    "#bcbd22",  # yellow-green
    "#17becf",  # cyan
    "#7f7f7f",  # grey
]

# Semantic colours for the residual / error-direction charts.
OVER_PRED = "#d62728"   # model over-predicts  (red)
UNDER_PRED = "#2ca02c"  # model under-predicts (green)

# Accent for single-series charts (matches the Streamlit primaryColor).
PRIMARY = "#d62728"
