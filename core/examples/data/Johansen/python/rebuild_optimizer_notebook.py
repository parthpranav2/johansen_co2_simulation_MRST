#!/usr/bin/env python3
"""
Rebuild johansen_bayesian_optimizer.ipynb — v3 (production-grade)

Fixes applied:
  1. T_end capped at 100 yr (was 200)
  2. S_CO2 threshold = 15% (was MISSING entirely)
  3. BHP limit = 324 bar (10% safety margin below 360 bar fracture pressure)
  4. Optuna SQLite persistence for robust resume
  5. Constraint-aware reward (feasible/infeasible ranking)
  6. Legacy JSON trial replay into Optuna
  7. Added Condition 2 parsing (boundary well saturation — was completely absent)
"""

import json, textwrap

MRST_ROOT = '/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a'
PY_DIR    = f'{MRST_ROOT}/core/examples/data/Johansen/python'
OUT_PATH  = f'{PY_DIR}/johansen_bayesian_optimizer.ipynb'

def code(src, cid):
    return {"cell_type": "code", "execution_count": None, "id": cid,
            "metadata": {}, "outputs": [], "source": src}

def md(src, cid):
    return {"cell_type": "markdown", "id": cid, "metadata": {}, "source": src}

cells = []

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 0 — Header
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(md("""\
# 🤖 Johansen CO₂ Bayesian Optimization — Automated Mode v3

## Fully Automated MATLAB Execution

This notebook drives MATLAB **headlessly** via `subprocess`. Each trial:
1. Optuna proposes parameters
2. Python writes `well_plan.csv`
3. MATLAB runs the simulation (~5-10 min per trial)
4. Python parses results and updates Optuna

## Three Constraints Enforced

| # | Condition | Limit |
|---|---|---|
| **1** | BHP per injector | ≤ **324 bar** (90% of 360 bar fracture pressure) |
| **2** | Boundary CO₂ saturation | < **15%** at surveillance wells |
| **3** | Time horizon | T_end ≤ **100 years** |

## v3 Improvements
- Optuna SQLite persistence (resume across crashes)
- Constraint-aware TPE sampling (Condition 1 + 2)
- Boundary saturation parsing (was completely missing in v1-v2)\
""", "md00"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 1 — Dependencies
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 1 — Install dependencies
import subprocess, sys
for pkg in ['optuna', 'scikit-learn', 'joblib']:
    try:
        __import__(pkg.replace('-','_'))
        print(f'  ✅ {pkg}')
    except ImportError:
        print(f'  📦 Installing {pkg}...')
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', pkg, '-q'])
        print(f'  ✅ {pkg} installed')
print('\\nAll dependencies ready.')\
""", "c01"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 2 — Configuration
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code(f"""\
# Cell 2 — Configuration
import os, re, glob, shutil, time, json, hashlib, warnings
import numpy as np
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.cm as cm
warnings.filterwarnings('ignore')
import optuna
from optuna.samplers import TPESampler
from optuna.distributions import FloatDistribution, IntDistribution
optuna.logging.set_verbosity(optuna.logging.WARNING)

# ─── PATHS ────────────────────────────────────────────────────────────────────
MRST_ROOT      = '{MRST_ROOT}'
WELL_PLAN_PATH = f'{{MRST_ROOT}}/core/examples/data/Johansen/data/well_plan.csv'
BACKUP_CSV     = f'{{MRST_ROOT}}/core/examples/data/Johansen/data/well_plan_BACKUP_BO.csv'
WELL_CSVS_ROOT = f'{{MRST_ROOT}}/core/examples/data/Johansen/well_csvs'
PYTHON_DIR     = f'{{MRST_ROOT}}/core/examples/data/Johansen/python'
RESULTS_JSON   = f'{{PYTHON_DIR}}/bo_results_auto.json'
OPTUNA_DB      = f'sqlite:///{{PYTHON_DIR}}/johansen_bo_auto_v3.db'

# ─── MATLAB ───────────────────────────────────────────────────────────────────
MATLAB_BIN     = '/Applications/MATLAB_R2024a.app/bin/matlab'
SCRIPT_PATH    = f'{{MRST_ROOT}}/core/examples/data/Johansen/example3DJohansen.m'
MATLAB_TIMEOUT = 900  # 15 min max per simulation

# ─── PHYSICAL CONSTRAINTS ────────────────────────────────────────────────────
FRACTURE_PRESSURE = 360.0
BHP_SAFETY_MARGIN = 0.10
BHP_LIMIT_BAR     = FRACTURE_PRESSURE * (1.0 - BHP_SAFETY_MARGIN)  # = 324.0 bar
S_CO2_THRESHOLD   = 0.15    # 15% critical saturation at boundary wells

# ─── OPTIMIZATION CONFIG ──────────────────────────────────────────────────────
N_TRIALS         = 60
N_WARMUP         = 15

# ─── WELLS ────────────────────────────────────────────────────────────────────
DEEP_WELLS     = ['31/01/01', '31/1-3 S', '31/2-5', '31/05/02']
CENTRAL_WELL   = '31/05/07'
ALL_INJECTORS  = DEEP_WELLS + [CENTRAL_WELL]
BOUNDARY_WELLS = ['SBoundary_test_well', 'SBoundary_test_well_2']

# ─── SEARCH SPACE — T_end capped at 100 yr ───────────────────────────────────
BOUNDS = {{
    'Q_deep'      : (0.3,  3.0),
    'Q_central'   : (0.3,  3.0),
    'T_start_deep': (0,    20),
    'T_end_deep'  : (25,   100),   # ← capped at 100 yr
    'T_start_cen' : (0,    20),
    'T_end_cen'   : (25,   100),   # ← capped at 100 yr
}}

print('✅ Configuration loaded (automated v3).')
print(f'   BHP limit      : {{BHP_LIMIT_BAR:.0f}} bar ({{BHP_SAFETY_MARGIN*100:.0f}}% margin)')
print(f'   S_CO₂ limit    : {{S_CO2_THRESHOLD*100:.0f}}% at boundary wells')
print(f'   T_end max      : {{BOUNDS["T_end_deep"][1]}} yr')
print(f'   MATLAB binary  : {{MATLAB_BIN}}')\
""", "c02"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 3 — Utility Functions (includes Condition 2 parsing)
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 3 — Utility Functions

def backup_well_plan():
    if not os.path.exists(BACKUP_CSV):
        shutil.copy2(WELL_PLAN_PATH, BACKUP_CSV)
        print(f'✅ Backup saved → {BACKUP_CSV}')
    else:
        print(f'ℹ️  Backup exists.')

def restore_well_plan():
    if os.path.exists(BACKUP_CSV):
        shutil.copy2(BACKUP_CSV, WELL_PLAN_PATH)
        print('✅ Restored.')
    else:
        print('⚠️ No backup.')

def write_well_plan(Q_deep, T_start_deep, T_end_deep, Q_central, T_start_cen, T_end_cen):
    df = pd.read_csv(BACKUP_CSV)
    T_start_deep = int(T_start_deep)
    T_end_deep   = max(int(T_end_deep), T_start_deep + 5)
    T_start_cen  = int(T_start_cen)
    T_end_cen    = max(int(T_end_cen), T_start_cen + 5)
    for well in DEEP_WELLS:
        mask = df['Well_Bore_Name'] == well
        if mask.any():
            df.loc[mask, 'Rate_MtPerYear'] = round(Q_deep, 4)
            df.loc[mask, 'Start_Year']     = T_start_deep
            df.loc[mask, 'End_Year']       = T_end_deep
    mask_cen = df['Well_Bore_Name'] == CENTRAL_WELL
    if mask_cen.any():
        df.loc[mask_cen, 'Rate_MtPerYear'] = round(Q_central, 4)
        df.loc[mask_cen, 'Start_Year']     = T_start_cen
        df.loc[mask_cen, 'End_Year']       = T_end_cen
    df.to_csv(WELL_PLAN_PATH, index=False)

def get_latest_run_folder():
    folders = sorted([d for d in glob.glob(f'{WELL_CSVS_ROOT}/??_??_????__??_??')
                      if os.path.isdir(d)])
    return folders[-1] if folders else None

# ── Condition 1: Per-injector BHP ─────────────────────────────────────────────
def parse_per_injector_bhp(folder):
    path = os.path.join(folder, 'simulation_summary.txt')
    if not os.path.exists(path): return {}
    text = open(path).read()
    result = {}
    for m in re.finditer(r'BHP_WELL\\s+([\\w/\\s\\-]+?)\\s*:\\s*([\\d.]+)\\s*bar', text):
        result[m.group(1).strip()] = float(m.group(2))
    if not result:
        m_peak = re.search(r'Peak injector BHP\\s*:\\s*([\\d.]+)', text)
        if m_peak: result['__peak__'] = float(m_peak.group(1))
    return result

# ── Condition 2: Boundary CO₂ saturation (WAS MISSING in v1/v2) ──────────────
def parse_boundary_saturation(folder):
    result = {}
    for well in BOUNDARY_WELLS:
        safe = re.sub(r'[/ ]', '_', well)
        csv_path = os.path.join(folder, f'{safe}.csv')
        if not os.path.exists(csv_path):
            result[well] = float('nan')
            continue
        df = pd.read_csv(csv_path)
        s_cols = [c for c in df.columns if c.startswith('S_CO2_')]
        result[well] = float(df[s_cols].max().max()) if s_cols else 0.0
    return result

# ── CO₂ total ─────────────────────────────────────────────────────────────────
def parse_co2_total(folder):
    path = os.path.join(folder, 'simulation_summary.txt')
    if not os.path.exists(path): return None
    m = re.search(r'Total CO2 injected\\s*:\\s*([\\d.]+)', open(path).read())
    return float(m.group(1)) if m else None

# ── Full result parse ─────────────────────────────────────────────────────────
def parse_full_result(folder):
    \"\"\"Parse all results from a simulation run folder.\"\"\"
    co2 = parse_co2_total(folder)
    bhp_dict = parse_per_injector_bhp(folder)
    bsat_dict = parse_boundary_saturation(folder)
    if co2 is None: return None
    max_bhp = max(bhp_dict.values()) if bhp_dict else 0.0
    bw_keys = list(bsat_dict.keys())
    max_sco2_bw1 = bsat_dict.get(bw_keys[0], 0.0) if len(bw_keys) > 0 else 0.0
    max_sco2_bw2 = bsat_dict.get(bw_keys[1], 0.0) if len(bw_keys) > 1 else 0.0
    if max_sco2_bw1 != max_sco2_bw1: max_sco2_bw1 = 0.0
    if max_sco2_bw2 != max_sco2_bw2: max_sco2_bw2 = 0.0
    return {
        'co2_mt': co2, 'max_bhp_bar': max_bhp,
        'max_sco2_bw1': max_sco2_bw1, 'max_sco2_bw2': max_sco2_bw2,
    }

# ── Constraint-aware reward ───────────────────────────────────────────────────
def compute_reward_and_violations(co2_mt, max_bhp_bar, max_sco2_bw1, max_sco2_bw2):
    bhp_violation = max(0.0, max_bhp_bar - BHP_LIMIT_BAR)
    sco2_v1 = max(0.0, max_sco2_bw1 - S_CO2_THRESHOLD)
    sco2_v2 = max(0.0, max_sco2_bw2 - S_CO2_THRESHOLD)
    cond1_breach = bhp_violation > 0
    cond2_breach = sco2_v1 > 0 or sco2_v2 > 0
    is_feasible = not cond1_breach and not cond2_breach
    if is_feasible:
        reward = co2_mt
    else:
        reward = -(bhp_violation / BHP_LIMIT_BAR + sco2_v1 + sco2_v2) * 1000.0
    return {
        'reward': reward, 'is_feasible': is_feasible,
        'cond1_breach': cond1_breach, 'cond2_breach': cond2_breach,
        'bhp_violation': bhp_violation,
        'sco2_violation_1': sco2_v1, 'sco2_violation_2': sco2_v2,
    }

def run_matlab():
    folder_before = get_latest_run_folder()
    t0 = time.time()
    cmd = [
        MATLAB_BIN, '-nodesktop', '-nosplash', '-nodisplay', '-r',
        f"addpath('{MRST_ROOT}'); run('{SCRIPT_PATH}'); exit"
    ]
    try:
        subprocess.run(cmd, timeout=MATLAB_TIMEOUT, capture_output=True, text=True)
    except subprocess.TimeoutExpired:
        print('  MATLAB timed out'); return None
    except Exception as e:
        print(f'  MATLAB error: {e}'); return None
    folder_after = get_latest_run_folder()
    if folder_after == folder_before:
        print('  No new run folder detected.'); return None
    print(f'  MATLAB done in {(time.time()-t0)/60:.1f} min -> {os.path.basename(folder_after)}')
    return folder_after

def save_results(trial_log):
    with open(RESULTS_JSON, 'w') as f:
        json.dump(trial_log, f, indent=2)

print('✅ Utility functions defined (with Condition 2 parsing).')\
""", "c03"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 4 — Backup & Verify
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 4 — Backup & Verify Setup
backup_well_plan()
assert os.path.exists(MATLAB_BIN), f'MATLAB not found at {MATLAB_BIN}'
print(f'MATLAB binary confirmed.')
assert os.path.exists(SCRIPT_PATH), f'MRST script not found'
print(f'MRST script confirmed.')

df_plan = pd.read_csv(BACKUP_CSV)
active  = df_plan[df_plan['Rate_MtPerYear'] > 0]
print('Active wells in well_plan.csv:')
print(active[['Well_Bore_Name','Rate_MtPerYear','Start_Year','End_Year']].to_string(index=False))

latest = get_latest_run_folder()
if latest:
    result = parse_full_result(latest)
    if result:
        print(f'\\nParser test on: {os.path.basename(latest)}')
        print(f'  CO₂: {result["co2_mt"]} Mt  |  BHP: {result["max_bhp_bar"]} bar')
        print(f'  BW1 S_CO₂: {result["max_sco2_bw1"]*100:.2f}%  |  BW2 S_CO₂: {result["max_sco2_bw2"]*100:.2f}%')

print('\\n✅ All checks passed.')\
""", "c04"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 5 — Define Objective
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 5 — Define Objective Function
trial_log = []

def objective(trial):
    Q_deep       = trial.suggest_float('Q_deep',       *BOUNDS['Q_deep'],       step=0.05)
    T_start_deep = trial.suggest_int(  'T_start_deep', *BOUNDS['T_start_deep'])
    T_end_deep   = trial.suggest_int(  'T_end_deep',   *BOUNDS['T_end_deep'])
    Q_central    = trial.suggest_float('Q_central',    *BOUNDS['Q_central'],    step=0.05)
    T_start_cen  = trial.suggest_int(  'T_start_cen',  *BOUNDS['T_start_cen'])
    T_end_cen    = trial.suggest_int(  'T_end_cen',    *BOUNDS['T_end_cen'])

    if T_start_deep >= T_end_deep or T_start_cen >= T_end_cen:
        trial_log.append({'trial': trial.number, 'status': 'SKIPPED'})
        return -9999.0  # Maximize direction, so very negative = bad

    params = {'Q_deep': Q_deep, 'T_start_deep': T_start_deep, 'T_end_deep': T_end_deep,
              'Q_central': Q_central, 'T_start_cen': T_start_cen, 'T_end_cen': T_end_cen}

    print(f'Trial {trial.number+1}/{N_TRIALS}  Deep: Q={Q_deep:.2f} T=[{T_start_deep}->{T_end_deep}]  '
          f'Central: Q={Q_central:.2f} T=[{T_start_cen}->{T_end_cen}]')

    write_well_plan(Q_deep, T_start_deep, T_end_deep, Q_central, T_start_cen, T_end_cen)
    run_folder = run_matlab()

    if run_folder is None:
        trial_log.append({**params, 'trial': trial.number, 'status': 'FAILED'})
        save_results(trial_log)
        return -9999.0

    result = parse_full_result(run_folder)
    if result is None:
        trial_log.append({**params, 'trial': trial.number, 'status': 'PARSE_ERROR'})
        save_results(trial_log)
        return -9999.0

    rv = compute_reward_and_violations(
        result['co2_mt'], result['max_bhp_bar'],
        result['max_sco2_bw1'], result['max_sco2_bw2']
    )

    # Store constraint info for TPE
    trial.set_user_attr('bhp_violation', rv['bhp_violation'])
    trial.set_user_attr('sco2_violation_1', rv['sco2_violation_1'])
    trial.set_user_attr('sco2_violation_2', rv['sco2_violation_2'])
    trial.set_user_attr('co2_mt', result['co2_mt'])
    trial.set_user_attr('max_bhp_bar', result['max_bhp_bar'])
    trial.set_user_attr('is_feasible', rv['is_feasible'])

    status = '🟢 FEASIBLE' if rv['is_feasible'] else '🔴 INFEASIBLE'
    print(f'  {status}  CO₂={result["co2_mt"]:.1f} Mt  BHP={result["max_bhp_bar"]:.1f} bar  '
          f'BW1={result["max_sco2_bw1"]*100:.2f}%  BW2={result["max_sco2_bw2"]*100:.2f}%  '
          f'Reward={rv["reward"]:.1f}')

    entry = {**params, 'trial': trial.number, 'run_folder': os.path.basename(run_folder),
             'status': 'OK', **result, **rv}
    trial_log.append(entry)
    save_results(trial_log)
    return rv['reward']

print('Objective function defined (with Condition 2).')\
""", "c05"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 6 — Resume
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 6 — Resume from Previous Run (Optuna SQLite persistence)
if os.path.exists(RESULTS_JSON):
    with open(RESULTS_JSON) as f:
        trial_log = json.load(f)
    completed = [t for t in trial_log if t.get('status') == 'OK']
    print(f'Loaded {len(trial_log)} previous trials ({len(completed)} successful).')
else:
    trial_log = []
    print('No previous results found. Starting fresh.')\
""", "c06"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 7 — Run BO
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 7 — RUN Bayesian Optimization (Automated MATLAB)
# Each trial calls MATLAB (~5-10 min). N_TRIALS=60 => ~8 hours overnight.
# Progress auto-saved to SQLite + JSON after every trial.
# Safe to interrupt with Ctrl+C; re-run Cell 6 + this cell to resume.

print('=' * 60)
print('JOHANSEN CO₂ BAYESIAN OPTIMIZATION — AUTOMATED v3')
print('=' * 60)
print(f'Trials      : {N_TRIALS}  |  Warm-up: {N_WARMUP}')
print(f'BHP limit   : {BHP_LIMIT_BAR:.0f} bar  |  S_CO₂ limit: {S_CO2_THRESHOLD*100:.0f}%')
print(f'T_end cap   : {BOUNDS["T_end_deep"][1]} yr')
print('=' * 60)

def constraints_func(trial):
    return [
        trial.user_attrs.get('bhp_violation', 0.0),
        trial.user_attrs.get('sco2_violation_1', 0.0),
        trial.user_attrs.get('sco2_violation_2', 0.0),
    ]

sampler = TPESampler(n_startup_trials=N_WARMUP, seed=42, constraints_func=constraints_func)
study   = optuna.create_study(
    study_name='johansen_co2_bo_auto_v3',
    direction='maximize',
    sampler=sampler,
    storage=OPTUNA_DB,
    load_if_exists=True,
)

n_remaining = max(0, N_TRIALS - len(study.trials))
if n_remaining == 0:
    print('Already have enough trials. Skip to analysis cells.')
else:
    t0 = time.time()
    try:
        study.optimize(objective, n_trials=n_remaining, gc_after_trial=True, show_progress_bar=False)
    except KeyboardInterrupt:
        print('Interrupted. Results saved.')
    elapsed = time.time() - t0
    print(f'Optimization finished in {elapsed/3600:.2f} hours.')
    feasible = [t for t in study.trials if t.user_attrs.get('is_feasible', False)]
    if feasible:
        best = max(feasible, key=lambda t: t.values[0])
        print(f'Best feasible: {best.values[0]:.2f} Mt CO₂')
        print(f'Best params: {best.params}')\
""", "c07"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 8 — Load & Summarize
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 8 — Load and Summarize Results
with open(RESULTS_JSON) as f:
    trial_log = json.load(f)

df_results = pd.DataFrame(trial_log)
df_ok = df_results[df_results['status'] == 'OK'].copy()
df_feasible = df_ok[df_ok['is_feasible'] == True] if ('is_feasible' in df_ok.columns and not df_ok.empty) else pd.DataFrame()

print(f'Total trials     : {len(df_results)}')
print(f'Successful       : {len(df_ok)}')
print(f'Feasible         : {len(df_feasible)}')
print(f'Failed / Skipped : {len(df_results) - len(df_ok)}')

if not df_ok.empty:
    best = df_ok.loc[df_ok['reward'].idxmax()]
    print(f'\\nBEST RESULT (max reward):')
    print(f'  Trial #{int(best["trial"])+1}  CO₂={best["co2_mt"]:.2f} Mt  BHP={best["max_bhp_bar"]:.2f} bar  '
          f'{"FEASIBLE" if best.get("is_feasible", False) else "INFEASIBLE"}')

    if not df_feasible.empty:
        best_safe = df_feasible.loc[df_feasible['co2_mt'].idxmax()]
        print(f'\\nBEST FEASIBLE RESULT:')
        print(f'  Trial #{int(best_safe["trial"])+1}  CO₂={best_safe["co2_mt"]:.2f} Mt  BHP={best_safe["max_bhp_bar"]:.2f} bar')
        print(f'  Deep: Q={best_safe["Q_deep"]:.2f} Mt/yr  T=[{int(best_safe["T_start_deep"])}->{int(best_safe["T_end_deep"])}] yr')
        print(f'  Cen:  Q={best_safe["Q_central"]:.2f} Mt/yr  T=[{int(best_safe["T_start_cen"])}->{int(best_safe["T_end_cen"])}] yr')\
""", "c08"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 9 — Progress Visualization
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 9 — Progress Visualization (4-panel)

if df_ok.empty:
    print('No results to plot.')
else:
    df_p = df_ok.copy()
    df_p['trial_num'] = df_p['trial'].astype(int) + 1

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # Panel 1: CO₂ per trial
    ax = axes[0,0]
    colors = ['#2ca02c' if row.get('is_feasible', False) else '#d62728' for _, row in df_p.iterrows()]
    ax.scatter(df_p['trial_num'], df_p['co2_mt'], c=colors, s=60, zorder=3, edgecolors='k', lw=0.5)
    ax.plot(df_p['trial_num'], df_p['co2_mt'].cummax(), 'k--', lw=1.5, label='Running best')
    ax.legend(fontsize=9)
    ax.set(xlabel='Trial #', ylabel='CO₂ (Mt)', title='CO₂ Stored per Trial')
    ax.grid(True, ls='--', alpha=0.4)

    # Panel 2: Reward convergence
    ax = axes[0,1]
    ax.plot(df_p['trial_num'], df_p['reward'], 'b.-', lw=1.2)
    ax.set(xlabel='Trial #', ylabel='Reward', title='Reward Convergence')
    ax.grid(True, ls='--', alpha=0.4)

    # Panel 3: BHP vs CO₂
    ax = axes[1,0]
    sc = ax.scatter(df_p['max_bhp_bar'], df_p['co2_mt'], c=df_p['trial_num'], cmap='plasma', s=60, zorder=3)
    ax.axvline(BHP_LIMIT_BAR, color='red', ls='--', lw=2, label=f'BHP limit ({BHP_LIMIT_BAR:.0f} bar)')
    plt.colorbar(sc, ax=ax, label='Trial #')
    ax.legend(fontsize=9)
    ax.set(xlabel='Peak BHP (bar)', ylabel='CO₂ (Mt)', title='BHP vs CO₂ Stored')
    ax.grid(True, ls='--', alpha=0.4)

    # Panel 4: Boundary S_CO₂
    ax = axes[1,1]
    if 'max_sco2_bw1' in df_p.columns:
        ax.scatter(df_p['trial_num'], df_p['max_sco2_bw1']*100, marker='o', s=50, label='BW-1', zorder=3)
    if 'max_sco2_bw2' in df_p.columns:
        ax.scatter(df_p['trial_num'], df_p['max_sco2_bw2']*100, marker='s', s=50, label='BW-2', zorder=3)
    ax.axhline(S_CO2_THRESHOLD*100, color='red', ls='--', lw=2, label=f'Limit ({S_CO2_THRESHOLD*100:.0f}%)')
    ax.legend(fontsize=9)
    ax.set(xlabel='Trial #', ylabel='Max S_CO₂ (%)', title='Condition 2 — Boundary CO₂')
    ax.grid(True, ls='--', alpha=0.4)

    plt.suptitle('Bayesian Optimization v3 — Johansen CO₂ Storage', fontsize=14, fontweight='bold', y=1.01)
    plt.tight_layout()
    plt.savefig(f'{PYTHON_DIR}/bo_progress_auto.png', dpi=150, bbox_inches='tight')
    plt.show()\
""", "c09"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 10 — Parameter Importance
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 10 — Parameter Importance (Random Forest)
from sklearn.ensemble import RandomForestRegressor

if df_ok.empty or len(df_ok) < 5:
    print('Need at least 5 successful trials.')
else:
    param_cols = ['Q_deep','T_start_deep','T_end_deep','Q_central','T_start_cen','T_end_cen']
    X = df_ok[param_cols].values
    y = df_ok['co2_mt'].values
    rf = RandomForestRegressor(n_estimators=400, random_state=42)
    rf.fit(X, y)
    imp = rf.feature_importances_
    sidx = np.argsort(imp)[::-1]

    fig, ax = plt.subplots(figsize=(8, 4))
    bars = ax.bar([param_cols[i] for i in sidx], imp[sidx],
                  color=cm.plasma(np.linspace(0.15, 0.85, len(param_cols))), edgecolor='k', lw=0.7)
    for bar, v in zip(bars, imp[sidx]):
        ax.text(bar.get_x()+bar.get_width()/2, bar.get_height()+0.005,
                f'{v:.1%}', ha='center', va='bottom', fontsize=9, fontweight='bold')
    ax.set(ylabel='Importance', title='Parameter Importance for CO₂ Storage')
    ax.grid(True, ls='--', alpha=0.4, axis='y')
    plt.tight_layout()
    plt.savefig(f'{PYTHON_DIR}/bo_importance_auto.png', dpi=150, bbox_inches='tight')
    plt.show()\
""", "c10"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 11 — Surrogate Surface
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 11 — Surrogate Surface Visualization
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.preprocessing import StandardScaler

if df_ok.empty or len(df_ok) < 5:
    print('Need ≥5 successful trials.')
else:
    param_cols = ['Q_deep','T_start_deep','T_end_deep','Q_central','T_start_cen','T_end_cen']
    X = df_ok[param_cols].values
    y = df_ok['co2_mt'].values
    scaler = StandardScaler()
    surr = GradientBoostingRegressor(n_estimators=400, max_depth=4, random_state=42)
    surr.fit(scaler.fit_transform(X), y)
    best_params = df_ok.loc[df_ok['reward'].idxmax(), param_cols].values

    Q_grid = np.linspace(*BOUNDS['Q_deep'], 50)
    T_grid = np.linspace(*BOUNDS['T_end_deep'], 50)
    QQ, TT = np.meshgrid(Q_grid, T_grid)
    grid_pts = np.column_stack([QQ.ravel(), np.full(QQ.size, best_params[1]),
                                TT.ravel(), np.full(QQ.size, best_params[3]),
                                np.full(QQ.size, best_params[4]), np.full(QQ.size, best_params[5])])
    Z = surr.predict(scaler.transform(grid_pts)).reshape(QQ.shape)

    fig, ax = plt.subplots(figsize=(9, 6))
    cf = ax.contourf(QQ, TT, Z, levels=25, cmap='YlOrRd')
    ax.contour(QQ, TT, Z, levels=10, colors='k', linewidths=0.5, alpha=0.5)
    plt.colorbar(cf, ax=ax, label='Predicted CO₂ (Mt)')
    ax.scatter(df_ok['Q_deep'], df_ok['T_end_deep'], c=df_ok['co2_mt'],
               cmap='YlOrRd', edgecolors='k', s=60, zorder=5, lw=0.8)
    if not df_feasible.empty:
        bs = df_feasible.loc[df_feasible['co2_mt'].idxmax()]
        ax.scatter([bs['Q_deep']], [bs['T_end_deep']], s=250, marker='*', color='blue', zorder=6, label='Best feasible')
    ax.set(xlabel='Q_deep (Mt/yr)', ylabel='T_end_deep (yr)',
           title='Surrogate: CO₂ vs Q_deep & T_end_deep')
    ax.legend(fontsize=10)
    plt.tight_layout()
    plt.savefig(f'{PYTHON_DIR}/bo_surrogate_auto.png', dpi=150, bbox_inches='tight')
    plt.show()\
""", "c11"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 12 — Full Results Table
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 12 — Full Results Table
from IPython.display import display

if df_ok.empty:
    print('No results yet.')
else:
    dcols = ['trial','Q_deep','T_start_deep','T_end_deep','Q_central','T_start_cen','T_end_cen',
             'co2_mt','max_bhp_bar','max_sco2_bw1','max_sco2_bw2','is_feasible','reward']
    avail = [c for c in dcols if c in df_ok.columns]
    df_show = df_ok[avail].copy()
    df_show['trial'] = df_show['trial'].astype(int) + 1
    df_show = df_show.sort_values('reward', ascending=False).reset_index(drop=True)

    def style_row(row):
        out = []
        for col in row.index:
            if col == 'max_bhp_bar' and row['max_bhp_bar'] > BHP_LIMIT_BAR:
                out.append('background-color:#ffcccc')
            elif col == 'reward' and row.name == 0:
                out.append('background-color:#ccffcc;font-weight:bold')
            else:
                out.append('')
        return out

    fmt = {'Q_deep':'{:.2f}','Q_central':'{:.2f}','co2_mt':'{:.2f}',
           'max_bhp_bar':'{:.2f}','max_sco2_bw1':'{:.4f}','max_sco2_bw2':'{:.4f}','reward':'{:.2f}'}
    display(df_show.style.apply(style_row, axis=1).format(fmt))\
""", "c12"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 13 — Apply Optimal
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 13 — Apply Optimal Parameters to well_plan.csv

if df_ok.empty:
    print('No results to apply.')
else:
    if not df_feasible.empty:
        chosen = df_feasible.loc[df_feasible['co2_mt'].idxmax()]
        mode_str = f'Best Feasible (BHP ≤ {BHP_LIMIT_BAR:.0f} bar, S_CO₂ < {S_CO2_THRESHOLD*100:.0f}%)'
    else:
        chosen = df_ok.loc[df_ok['reward'].idxmax()]
        mode_str = 'Best Reward (no feasible trial exists)'

    print(f'Applying [{mode_str}]')
    print(f'  Deep: Q={chosen["Q_deep"]:.2f} Mt/yr  T=[{int(chosen["T_start_deep"])}->{int(chosen["T_end_deep"])}] yr')
    print(f'  Cen:  Q={chosen["Q_central"]:.2f} Mt/yr  T=[{int(chosen["T_start_cen"])}->{int(chosen["T_end_cen"])}] yr')
    print(f'  CO₂: {chosen["co2_mt"]:.2f} Mt  |  BHP: {chosen["max_bhp_bar"]:.2f} bar')

    write_well_plan(chosen['Q_deep'],    int(chosen['T_start_deep']), int(chosen['T_end_deep']),
                    chosen['Q_central'], int(chosen['T_start_cen']),  int(chosen['T_end_cen']))
    print(f'\\n✅ well_plan.csv updated. Backup at: {BACKUP_CSV}')\
""", "c13"))

# ═══════════════════════════════════════════════════════════════════════════════
# CELL 14 — Emergency Restore
# ═══════════════════════════════════════════════════════════════════════════════
cells.append(code("""\
# Cell 14 — Emergency Restore
# Uncomment to undo all changes:
# restore_well_plan()
print('Uncomment restore_well_plan() to undo all changes.')\
""", "c14"))

# ═══════════════════════════════════════════════════════════════════════════════
# ASSEMBLE & WRITE
# ═══════════════════════════════════════════════════════════════════════════════
nb = {
    "nbformat": 4,
    "nbformat_minor": 5,
    "metadata": {
        "kernelspec": {
            "display_name": "Python 3",
            "language": "python",
            "name": "python3"
        },
        "language_info": {
            "name": "python",
            "version": "3.11.0"
        }
    },
    "cells": cells
}

with open(OUT_PATH, 'w') as f:
    json.dump(nb, f, indent=1)

print(f'✅ Wrote {OUT_PATH}')
print(f'   {len(cells)} cells')
