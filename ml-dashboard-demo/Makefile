.PHONY: install train tune dashboard test clean
PY := python3
VENV := .venv

$(VENV):
	$(PY) -m venv $(VENV)

install: $(VENV)
	$(VENV)/bin/pip install -r requirements.txt

train: install
	$(VENV)/bin/python -m backend.train --mode baseline

tune: install
	$(VENV)/bin/python -m backend.train --mode tuned

dashboard: install
	$(VENV)/bin/streamlit run frontend/app.py

test: install
	$(VENV)/bin/python -m pytest -q

clean:
	rm -rf $(VENV) models __pycache__ .pytest_cache
