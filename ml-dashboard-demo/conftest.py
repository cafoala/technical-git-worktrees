import os
import sys

# Put the repo root on sys.path so `pytest` (however it's invoked) can import
# the `backend` and `frontend` packages.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
