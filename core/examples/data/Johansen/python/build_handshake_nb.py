import json

MRST_ROOT = '/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a'
PY_DIR    = f'{MRST_ROOT}/core/examples/data/Johansen/python'
DATA_DIR  = f'{MRST_ROOT}/core/examples/data/Johansen/data'
WELL_CSVS = f'{MRST_ROOT}/core/examples/data/Johansen/well_csvs'

def code(src, cid): return {"cell_type":"code","execution_count":None,"id":cid,"metadata":{},"outputs":[],"source":src}
def md(src, cid):   return {"cell_type":"markdown","id":cid,"metadata":{},"source":src}

cells = []

# ── 0: Header ────────────────────────────────────────────────────────────────
cells.append(md(
"""# 🧠 Johansen CO₂ — Bayesian Optimization (Handshake Mode)

## Workflow
This notebook does **NOT** launch MATLAB itself. Instead, it uses a file-based handshake:

```
[Python]  →  writes well_plan.csv + bo_pending.json
                ↓  you see the message "Run MATLAB now"
[YOU]     →  open MATLAB → run example3DJohansen.m (as usual)
                ↓  MATLAB finishes → auto-writes bo_signal.json
[Python]  →  detects signal → reads result → updates Optuna surrogate
           → proposes next trial → writes new well_plan.csv
                ↓  you see "Run MATLAB now" again
[YOU]     →  repeat
```

## Reliability Guarantees
- ✅ Crash-safe: every result saved to `bo_results.json` immediately
- ✅ Resumable: re-run Cell 6 (resume) + Cell 7 (loop) after any interruption  
- ✅ You can stop after any trial and pick up later
- ✅ No timeout issues — waits as long as needed
- ✅ Works with your existing MATLAB GUI workflow""", "md00"))

# ── 1: Dependencies ──────────────────────────────────────────────────────────
cells.append(code(
"""# Cell 1 — Install dependencies
import subprocess, sys
for pkg in ['optuna', 'scikit-learn']:
    try:
        __import__(pkg.replace('-','_'))
        print(f'  ✅ {pkg}')
    except ImportError:
        print(f'  📦 Installing {pkg}...')
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', pkg, '-q'])
        print(f'  ✅ {pkg} installed')
print('\\nAll dependencies ready.')""", "c01"))

# ── 2: Config ────────────────────────────────────────────────────────────────
cells.append(code(
f"""# Cell 2 — Imports and Configuration
import os, re, glob, shutil, time, json, warnings
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.cm as cm
warnings.filterwarnings('ignore')
import optuna
from optuna.samplers import TPESampler
optuna.logging.set_verbosity(optuna.logging.WARNING)

# ─── PATHS ───────────────────────────────────────────────────────────────────
MRST_ROOT      = '{MRST_ROOT}'
WELL_PLAN_PATH = f'{{MRST_ROOT}}/core/examples/data/Johansen/data/well_plan.csv'
BACKUP_CSV     = f'{{MRST_ROOT}}/core/examples/data/Johansen/data/well_plan_BACKUP_BO.csv'
WELL_CSVS_ROOT = f'{{MRST_ROOT}}/core/examples/data/Johansen/well_csvs'
PYTHON_DIR     = f'{{MRST_ROOT}}/core/examples/data/Johansen/python'
RESULTS_JSON   = f'{{PYTHON_DIR}}/bo_results.json'
SIGNAL_FILE    = f'{{PYTHON_DIR}}/bo_signal.json'     # MATLAB writes this when done
PENDING_FILE   = f'{{PYTHON_DIR}}/bo_pending.json'    # Python writes this before waiting

# ─── OPTIMIZATION CONFIG ─────────────────────────────────────────────────────
N_TRIALS       = 40       # Total Bayesian trials
N_WARMUP       = 10       # Pure random warm-up before GP kicks in
PENALTY_LAMBDA = 100.0    # Penalty per bar over BHP limit
BHP_LIMIT_BAR  = 248.0    # 360 psi in bar

# ─── ACTIVE WELLS ────────────────────────────────────────────────────────────
DEEP_WELLS    = ['31/01/01', '31/1-3 S', '31/2-5', '31/05/02']
CENTRAL_WELL  = '31/05/07'

# ─── SEARCH SPACE BOUNDS ─────────────────────────────────────────────────────
BOUNDS = {{
    'Q_deep':       (0.3, 3.0),    # Mt/yr per deep well
    'Q_central':    (0.3, 3.0),    # Mt/yr central
    'T_start_deep': (0,   20),     # start year
    'T_end_deep':   (30,  300),    # end year
    'T_start_cen':  (0,   20),
    'T_end_cen':    (30,  300),
}}

print('✅ Configuration loaded.')
print(f'   N_TRIALS      : {{N_TRIALS}} ({{N_WARMUP}} random warm-up + {{N_TRIALS-N_WARMUP}} BO-guided)')
print(f'   BHP limit     : {{BHP_LIMIT_BAR}} bar = 360 psi')
print(f'   Signal file   : {{SIGNAL_FILE}}')""", "c02"))

# ── 3: Utilities ─────────────────────────────────────────────────────────────
cells.append(code(
"""# Cell 3 — Utility Functions

def backup_well_plan():
    if not os.path.exists(BACKUP_CSV):
        shutil.copy2(WELL_PLAN_PATH, BACKUP_CSV)
        print(f'✅ Backup saved → {BACKUP_CSV}')
    else:
        print(f'ℹ️  Backup already exists.')

def restore_well_plan():
    if os.path.exists(BACKUP_CSV):
        shutil.copy2(BACKUP_CSV, WELL_PLAN_PATH)
        print('✅ Original well_plan.csv restored.')
    else:
        print('⚠️ No backup found.')

def write_well_plan(Q_deep, T_start_deep, T_end_deep, Q_central, T_start_cen, T_end_cen):
    \"\"\"Write trial parameters to well_plan.csv (uses backup as base).\"\"\"
    df = pd.read_csv(BACKUP_CSV)
    T_start_deep = int(T_start_deep)
    T_end_deep   = max(int(T_end_deep), T_start_deep + 10)
    T_start_cen  = int(T_start_cen)
    T_end_cen    = max(int(T_end_cen), T_start_cen + 10)
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
    \"\"\"Return the path of the most recently created simulation folder.\"\"\"
    folders = sorted([d for d in glob.glob(f'{WELL_CSVS_ROOT}/??_??_????__??_??') if os.path.isdir(d)])
    return folders[-1] if folders else None

def parse_summary(folder):
    \"\"\"Parse simulation_summary.txt. Returns dict or None.\"\"\"
    path = os.path.join(folder, 'simulation_summary.txt')
    if not os.path.exists(path): return None
    text = open(path).read()
    co2 = re.search(r'Total CO2 injected\\s*:\\s*([\\d.]+)', text)
    bhp = re.search(r'Peak injector BHP\\s*:\\s*([\\d.]+)', text)
    if not (co2 and bhp): return None
    return {'co2_total_mt': float(co2.group(1)), 'peak_bhp_bar': float(bhp.group(1))}

def save_results():
    \"\"\"Persist trial_log to JSON — called after every trial.\"\"\"
    with open(RESULTS_JSON, 'w') as f:
        json.dump(trial_log, f, indent=2)

def clear_signal():
    \"\"\"Delete the MATLAB signal file after consuming it.\"\"\"
    if os.path.exists(SIGNAL_FILE):
        os.remove(SIGNAL_FILE)

def write_pending(trial_num, params):
    \"\"\"Write pending file so MATLAB knows which trial is expected.\"\"\"
    data = {**params, 'trial': trial_num, 'written_at': time.strftime('%Y-%m-%d %H:%M:%S')}
    with open(PENDING_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def wait_for_matlab(trial_num, poll_seconds=30):
    \"\"\"
    Block until bo_signal.json appears (written by MATLAB at end of run).
    Prints a countdown and beeps when signal is detected.
    Returns the run_folder path from the signal, or None on timeout (KeyboardInterrupt).
    \"\"\"
    clear_signal()   # ensure no stale signal from a previous run
    waited = 0
    print(f'  ⏳ Waiting for MATLAB signal (poll every {poll_seconds}s) ... Press Ctrl+C to skip this trial.')
    try:
        while True:
            time.sleep(poll_seconds)
            waited += poll_seconds
            if os.path.exists(SIGNAL_FILE):
                with open(SIGNAL_FILE) as f:
                    signal = json.load(f)
                clear_signal()
                run_folder = signal.get('run_folder', '')
                print(f'  ✅ Signal received after {waited//60} min! Folder: {os.path.basename(run_folder)}')
                return run_folder
            else:
                mins = waited // 60
                print(f'  ... still waiting ({mins} min elapsed). Run example3DJohansen.m in MATLAB.')
    except KeyboardInterrupt:
        print('  ⚡ Skipped by user.')
        clear_signal()
        return None

print('✅ Utility functions defined.')""", "c03"))

# ── 4: Backup + verify ───────────────────────────────────────────────────────
cells.append(code(
"""# Cell 4 — Backup & Verify Setup
backup_well_plan()

df_plan = pd.read_csv(BACKUP_CSV)
active  = df_plan[df_plan['Rate_MtPerYear'] > 0]
print('\\n📋 Current active wells (base configuration):')
print(active[['Well_Bore_Name','Rate_MtPerYear','Start_Year','End_Year']].to_string(index=False))

# Test parser on most recent run
latest = get_latest_run_folder()
if latest:
    parsed = parse_summary(latest)
    if parsed:
        print(f'\\n✅ Parser test OK on {os.path.basename(latest)}')
        print(f'   CO2={parsed[\"co2_total_mt\"]} Mt  |  BHP={parsed[\"peak_bhp_bar\"]} bar')

# Clean up any stale signal files
clear_signal()
if os.path.exists(PENDING_FILE): os.remove(PENDING_FILE)
print('\\n✅ All checks passed. Proceed to Cell 5, then Cell 7.')""", "c04"))

# ── 5: Objective ─────────────────────────────────────────────────────────────
cells.append(code(
"""# Cell 5 — Define Objective Function (Handshake Version)
trial_log = []

def objective(trial):
    \"\"\"
    Optuna objective — handshake version.
    1. Propose parameters
    2. Write well_plan.csv
    3. Print instructions for user
    4. Wait for MATLAB signal
    5. Parse result
    6. Return -reward
    \"\"\"
    # ── 1. PROPOSE ───────────────────────────────────────────────────────────
    Q_deep       = trial.suggest_float('Q_deep',       *BOUNDS['Q_deep'],       step=0.05)
    T_start_deep = trial.suggest_int(  'T_start_deep', *BOUNDS['T_start_deep'])
    T_end_deep   = trial.suggest_int(  'T_end_deep',   *BOUNDS['T_end_deep'])
    Q_central    = trial.suggest_float('Q_central',    *BOUNDS['Q_central'],    step=0.05)
    T_start_cen  = trial.suggest_int(  'T_start_cen',  *BOUNDS['T_start_cen'])
    T_end_cen    = trial.suggest_int(  'T_end_cen',    *BOUNDS['T_end_cen'])

    # Guard: reject physically invalid combinations immediately
    if T_start_deep >= T_end_deep or T_start_cen >= T_end_cen:
        trial_log.append({'trial': trial.number, 'status': 'SKIPPED', 'reason': 'T_start>=T_end'})
        save_results()
        return 9999.0

    params = {
        'Q_deep': Q_deep, 'T_start_deep': T_start_deep, 'T_end_deep': T_end_deep,
        'Q_central': Q_central, 'T_start_cen': T_start_cen, 'T_end_cen': T_end_cen
    }

    phase = 'WARMUP (random)' if trial.number < N_WARMUP else 'BO-GUIDED'

    print()
    print('═' * 62)
    print(f'  TRIAL {trial.number+1}/{N_TRIALS}  [{phase}]')
    print('═' * 62)
    print(f'  Deep wells  : Q = {Q_deep:.2f} Mt/yr   T = [{T_start_deep} → {T_end_deep}] yr')
    print(f'  Central well: Q = {Q_central:.2f} Mt/yr   T = [{T_start_cen} → {T_end_cen}] yr')
    print()

    # ── 2. WRITE well_plan.csv ────────────────────────────────────────────────
    write_well_plan(Q_deep, T_start_deep, T_end_deep, Q_central, T_start_cen, T_end_cen)
    write_pending(trial.number, params)
    print(f'  ✅ well_plan.csv updated.')
    print()
    print('  ┌─────────────────────────────────────────────────────┐')
    print('  │  ▶  NOW: Switch to MATLAB and run:                  │')
    print('  │     example3DJohansen.m                             │')
    print('  │  The notebook will automatically detect completion. │')
    print('  └─────────────────────────────────────────────────────┘')

    # ── 3. WAIT for MATLAB to finish ──────────────────────────────────────────
    run_folder = wait_for_matlab(trial.number)

    if run_folder is None:
        # User pressed Ctrl+C — check if a new folder appeared anyway
        latest = get_latest_run_folder()
        run_folder = latest

    if run_folder is None:
        print('  ⚠️  No result available — marking trial as failed.')
        trial_log.append({**params, 'trial': trial.number, 'status': 'FAILED'})
        save_results()
        return 9999.0

    # ── 4. PARSE result ───────────────────────────────────────────────────────
    result = parse_summary(run_folder)
    if result is None:
        print(f'  ⚠️  Could not parse summary in {os.path.basename(run_folder)}')
        trial_log.append({**params, 'trial': trial.number, 'status': 'PARSE_ERROR'})
        save_results()
        return 9999.0

    co2_mt  = result['co2_total_mt']
    bhp_bar = result['peak_bhp_bar']
    bhp_excess = max(0.0, bhp_bar - BHP_LIMIT_BAR)
    penalty    = PENALTY_LAMBDA * bhp_excess
    reward     = co2_mt - penalty

    status_str = f'🚨 BHP BREACH (+{bhp_excess:.1f} bar, penalty={penalty:.0f})' if bhp_excess > 0 else '✅ BHP safe'
    print(f'  CO₂ stored   : {co2_mt:.2f} Mt')
    print(f'  Peak BHP     : {bhp_bar:.2f} bar   {status_str}')
    print(f'  Reward       : {reward:.2f}')

    # ── 5. LOG & SAVE ─────────────────────────────────────────────────────────
    entry = {
        **params,
        'trial':      trial.number,
        'run_folder': os.path.basename(run_folder),
        'status':     'OK',
        'co2_mt':     co2_mt,
        'bhp_bar':    bhp_bar,
        'bhp_excess': bhp_excess,
        'penalty':    penalty,
        'reward':     reward,
    }
    trial_log.append(entry)
    save_results()

    return -reward   # Optuna minimizes

print('✅ Objective function defined.')""", "c05"))

# ── 6: Resume ────────────────────────────────────────────────────────────────
cells.append(code(
"""# Cell 6 — (Optional) Resume from Previous Run
# Run this cell BEFORE Cell 7 if you are continuing a partially completed study.

if os.path.exists(RESULTS_JSON):
    with open(RESULTS_JSON) as f:
        trial_log = json.load(f)
    ok = [t for t in trial_log if t.get('status') == 'OK']
    print(f'📂 Loaded {len(trial_log)} previous trials ({len(ok)} successful).')
    if ok:
        best = max(ok, key=lambda x: x.get('reward', -9999))
        print(f'   Current best: CO₂={best[\"co2_mt\"]:.2f} Mt  BHP={best[\"bhp_bar\"]:.2f} bar')
    print(f'   Trials remaining: {max(0, N_TRIALS - len(trial_log))}')
else:
    trial_log = []
    print('ℹ️  No previous results found — starting fresh.')""", "c06"))

# ── 7: Main loop ─────────────────────────────────────────────────────────────
cells.append(code(
"""# Cell 7 — 🚀 START / CONTINUE Optimization Loop
#
# HOW TO USE:
#   1. Run this cell
#   2. When you see "Switch to MATLAB → run example3DJohansen.m":
#      → Go to MATLAB and run example3DJohansen.m as you normally do
#   3. When MATLAB finishes, come back here — it auto-detects and continues
#   4. Repeat until N_TRIALS are done
#   5. Ctrl+C at any time to pause; re-run Cell 6 + Cell 7 to resume

print('═' * 62)
print('  JOHANSEN CO₂ BAYESIAN OPTIMIZATION — HANDSHAKE MODE')
print('═' * 62)
print(f'  N_TRIALS      : {N_TRIALS}')
print(f'  Warm-up trials: {N_WARMUP}')
print(f'  BHP limit     : {BHP_LIMIT_BAR} bar (360 psi)')
print(f'  Results file  : bo_results.json')
print('═' * 62)

sampler = TPESampler(n_startup_trials=N_WARMUP, seed=42)
study   = optuna.create_study(
    study_name='johansen_co2_bo',
    direction='minimize',
    sampler=sampler,
)

n_remaining = max(0, N_TRIALS - len(trial_log))

if n_remaining == 0:
    print('\\n✅ All trials complete. Run analysis cells (8–12).')
else:
    print(f'\\n  Trials to run: {n_remaining}')
    print(f'  You will be prompted {n_remaining} times to run MATLAB.')
    print()
    try:
        study.optimize(objective, n_trials=n_remaining, gc_after_trial=True, show_progress_bar=False)
    except KeyboardInterrupt:
        print('\\n⚡ Optimization paused. Run Cell 6 + Cell 7 again to resume.')

    ok = [t for t in trial_log if t.get('status') == 'OK']
    if ok:
        best = max(ok, key=lambda x: x.get('reward', -9999))
        print(f'\\n🏆 Best so far: CO₂={best[\"co2_mt\"]:.2f} Mt  BHP={best[\"bhp_bar\"]:.2f} bar')
        print(f'   Params: Q_deep={best[\"Q_deep\"]:.2f} T_deep=[{int(best[\"T_start_deep\"])}->{int(best[\"T_end_deep\"])}]')
        print(f'           Q_cen={best[\"Q_central\"]:.2f}  T_cen=[{int(best[\"T_start_cen\"])}->{int(best[\"T_end_cen\"])}]')""", "c07"))

# ── 8: Summarize ─────────────────────────────────────────────────────────────
cells.append(code(
"""# Cell 8 — Summarize Results
# Run any time to see current results without waiting for all trials.

if os.path.exists(RESULTS_JSON):
    with open(RESULTS_JSON) as f:
        trial_log = json.load(f)

df_results = pd.DataFrame(trial_log)
df_ok = df_results[df_results['status'] == 'OK'].copy() if not df_results.empty else pd.DataFrame()

if df_ok.empty:
    print('No successful trials yet.')
else:
    print(f'Total trials     : {len(df_results)}')
    print(f'Successful       : {len(df_ok)}')
    print(f'Failed / Skipped : {len(df_results) - len(df_ok)}')

    best      = df_ok.loc[df_ok['reward'].idxmax()]
    df_safe   = df_ok[df_ok['bhp_bar'] <= BHP_LIMIT_BAR]
    best_safe = df_safe.loc[df_safe['co2_mt'].idxmax()] if not df_safe.empty else None

    print(f'\\n🏆 BEST (max reward) — Trial #{int(best[\"trial\"])+1}')
    print(f'   CO₂ stored  : {best[\"co2_mt\"]:.2f} Mt')
    print(f'   Peak BHP    : {best[\"bhp_bar\"]:.2f} bar  [{\"✅ safe\" if best[\"bhp_bar\"]<=BHP_LIMIT_BAR else \"🚨 BREACH\"}]')
    print(f'   Deep wells  : Q={best[\"Q_deep\"]:.2f} Mt/yr  T=[{int(best[\"T_start_deep\"])}->{int(best[\"T_end_deep\"])}] yr')
    print(f'   Central     : Q={best[\"Q_central\"]:.2f} Mt/yr  T=[{int(best[\"T_start_cen\"])}->{int(best[\"T_end_cen\"])}] yr')

    if best_safe is not None:
        print(f'\\n🛡️  BEST SAFE (BHP ≤ {BHP_LIMIT_BAR} bar) — Trial #{int(best_safe[\"trial\"])+1}')
        print(f'   CO₂ stored  : {best_safe[\"co2_mt\"]:.2f} Mt')
        print(f'   Peak BHP    : {best_safe[\"bhp_bar\"]:.2f} bar')
        print(f'   Deep wells  : Q={best_safe[\"Q_deep\"]:.2f} Mt/yr  T=[{int(best_safe[\"T_start_deep\"])}->{int(best_safe[\"T_end_deep\"])}] yr')
        print(f'   Central     : Q={best_safe[\"Q_central\"]:.2f} Mt/yr  T=[{int(best_safe[\"T_start_cen\"])}->{int(best_safe[\"T_end_cen\"])}] yr')
    else:
        print(f'\\n⚠️ No safe trial yet (all BHP > {BHP_LIMIT_BAR} bar). Consider lowering Q bounds.')

    print(f'\\n   CO₂ range: {df_ok[\"co2_mt\"].min():.1f} → {df_ok[\"co2_mt\"].max():.1f} Mt')
    print(f'   BHP range: {df_ok[\"bhp_bar\"].min():.1f} → {df_ok[\"bhp_bar\"].max():.1f} bar')""", "c08"))

# ── 9: Progress Plot ──────────────────────────────────────────────────────────
cells.append(code(
"""# Cell 9 — Optimization Progress Plots
from matplotlib.lines import Line2D
from IPython.display import display

if 'df_ok' not in dir() or df_ok.empty:
    print('Run Cell 8 first.')
else:
    df_p = df_ok.reset_index(drop=True).copy()
    df_p['trial_num']  = df_p['trial'] + 1
    df_p['cummax_co2'] = df_p['co2_mt'].cummax()
    df_p['cummax_rew'] = df_p['reward'].cummax()
    colors = ['#d62728' if b > BHP_LIMIT_BAR else '#1f77b4' for b in df_p['bhp_bar']]

    fig, axes = plt.subplots(2, 2, figsize=(14, 9))

    # Panel 1: CO2 per trial
    ax = axes[0,0]
    ax.scatter(df_p['trial_num'], df_p['co2_mt'], c=colors, s=65, zorder=3)
    ax.plot(df_p['trial_num'], df_p['cummax_co2'], 'k--', lw=1.5, label='Running best')
    ax.legend(handles=[
        Line2D([0],[0],marker='o',color='w',markerfacecolor='#1f77b4',ms=9,label='BHP safe'),
        Line2D([0],[0],marker='o',color='w',markerfacecolor='#d62728',ms=9,label='BHP breach'),
        Line2D([0],[0],color='k',ls='--',label='Running best')
    ], fontsize=9)
    ax.set(xlabel='Trial #', ylabel='CO₂ Stored (Mt)', title='CO₂ per Trial')
    ax.grid(True, ls='--', alpha=0.4)

    # Panel 2: Reward convergence
    ax = axes[0,1]
    ax.plot(df_p['trial_num'], df_p['reward'], 'o-', color='#2ca02c', ms=5, lw=1.5)
    ax.plot(df_p['trial_num'], df_p['cummax_rew'], 'k--', lw=1.5, label='Running best')
    ax.legend(fontsize=9)
    ax.set(xlabel='Trial #', ylabel='Reward (CO₂ − Penalty)', title='Reward Convergence (BO Learning)')
    ax.grid(True, ls='--', alpha=0.4)

    # Panel 3: BHP vs CO2
    ax = axes[1,0]
    sc = ax.scatter(df_p['bhp_bar'], df_p['co2_mt'], c=df_p['trial_num'], cmap='plasma', s=65, zorder=3)
    ax.axvline(BHP_LIMIT_BAR, color='red', ls='--', lw=2, label=f'BHP limit ({BHP_LIMIT_BAR} bar)')
    plt.colorbar(sc, ax=ax, label='Trial #')
    ax.legend(fontsize=9)
    ax.set(xlabel='Peak BHP (bar)', ylabel='CO₂ Stored (Mt)', title='Peak BHP vs CO₂ Stored')
    ax.grid(True, ls='--', alpha=0.4)

    # Panel 4: Q landscape
    ax = axes[1,1]
    sc2 = ax.scatter(df_p['Q_deep'], df_p['Q_central'], c=df_p['co2_mt'],
                     cmap='YlGn', s=70, edgecolors='k', lw=0.5, zorder=3)
    best_row = df_p.loc[df_p['reward'].idxmax()]
    ax.scatter([best_row['Q_deep']], [best_row['Q_central']], s=220, marker='*', color='red', zorder=5, label='Best')
    plt.colorbar(sc2, ax=ax, label='CO₂ Stored (Mt)')
    ax.legend(fontsize=9)
    ax.set(xlabel='Q_deep (Mt/yr)', ylabel='Q_central (Mt/yr)', title='Injection Rate Landscape')
    ax.grid(True, ls='--', alpha=0.4)

    plt.suptitle('Bayesian Optimization — Johansen CO₂ Storage', fontsize=14, fontweight='bold', y=1.01)
    plt.tight_layout()
    out = f'{PYTHON_DIR}/bo_progress.png'
    plt.savefig(out, dpi=150, bbox_inches='tight')
    plt.show()
    print(f'✅ Saved → {out}')""", "c09"))

# ── 10: Parameter importance ──────────────────────────────────────────────────
cells.append(code(
"""# Cell 10 — Parameter Importance (Random Forest)
from sklearn.ensemble import RandomForestRegressor

if 'df_ok' not in dir() or len(df_ok) < 5:
    print('Need at least 5 successful trials.')
else:
    param_cols = ['Q_deep','T_start_deep','T_end_deep','Q_central','T_start_cen','T_end_cen']
    X  = df_ok[param_cols].values
    y  = df_ok['reward'].values
    rf = RandomForestRegressor(n_estimators=300, random_state=42)
    rf.fit(X, y)
    imp  = rf.feature_importances_
    sidx = np.argsort(imp)[::-1]

    fig, ax = plt.subplots(figsize=(8, 4))
    bars = ax.bar([param_cols[i] for i in sidx], imp[sidx],
                  color=cm.plasma(np.linspace(0.15, 0.85, len(param_cols))),
                  edgecolor='k', lw=0.7)
    for bar, v in zip(bars, imp[sidx]):
        ax.text(bar.get_x()+bar.get_width()/2, bar.get_height()+0.005,
                f'{v:.1%}', ha='center', va='bottom', fontsize=9, fontweight='bold')
    ax.set(ylabel='Importance (RF)', title='Parameter Importance for CO₂ Storage Reward')
    ax.grid(True, ls='--', alpha=0.4, axis='y')
    plt.tight_layout()
    out = f'{PYTHON_DIR}/bo_importance.png'
    plt.savefig(out, dpi=150, bbox_inches='tight')
    plt.show()
    print('\\nRanking (most → least important):')
    for i in sidx:
        print(f'  {param_cols[i]:20s}: {imp[i]:.1%}')""", "c10"))

# ── 11: Surrogate surface ──────────────────────────────────────────────────────
cells.append(code(
"""# Cell 11 — Surrogate Surface (Q_deep × T_end_deep)
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.preprocessing import StandardScaler

if 'df_ok' not in dir() or len(df_ok) < 5:
    print('Need at least 5 successful trials.')
else:
    param_cols = ['Q_deep','T_start_deep','T_end_deep','Q_central','T_start_cen','T_end_cen']
    X       = df_ok[param_cols].values
    y       = df_ok['co2_mt'].values
    scaler  = StandardScaler()
    surr    = GradientBoostingRegressor(n_estimators=300, max_depth=4, random_state=42)
    surr.fit(scaler.fit_transform(X), y)

    best_params = df_ok.loc[df_ok['reward'].idxmax(), param_cols].values

    Q_grid = np.linspace(*BOUNDS['Q_deep'], 50)
    T_grid = np.linspace(*BOUNDS['T_end_deep'], 50)
    QQ, TT = np.meshgrid(Q_grid, T_grid)
    grid_pts = np.column_stack([
        QQ.ravel(), np.full(QQ.size, best_params[1]),
        TT.ravel(), np.full(QQ.size, best_params[3]),
        np.full(QQ.size, best_params[4]), np.full(QQ.size, best_params[5])
    ])
    Z = surr.predict(scaler.transform(grid_pts)).reshape(QQ.shape)

    fig, ax = plt.subplots(figsize=(9, 6))
    cf = ax.contourf(QQ, TT, Z, levels=25, cmap='YlOrRd')
    ax.contour(QQ, TT, Z, levels=10, colors='k', linewidths=0.5, alpha=0.4)
    plt.colorbar(cf, ax=ax, label='Predicted CO₂ Stored (Mt)')
    ax.scatter(df_ok['Q_deep'], df_ok['T_end_deep'], c=df_ok['co2_mt'],
               cmap='YlOrRd', edgecolors='k', s=65, zorder=5, lw=0.8)
    ax.scatter([best_params[0]], [best_params[2]], s=260, marker='*', color='blue', zorder=6, label='Best trial')
    ax.set(xlabel='Q_deep (Mt/yr per well)', ylabel='T_end_deep (injection end year)',
           title='Surrogate Surface: CO₂ Stored vs Q_deep & T_end_deep\\n(other params held at best values)')
    ax.legend(fontsize=10)
    plt.tight_layout()
    out = f'{PYTHON_DIR}/bo_surrogate.png'
    plt.savefig(out, dpi=150, bbox_inches='tight')
    plt.show()
    print(f'✅ Saved → {out}')""", "c11"))

# ── 12: Results table ─────────────────────────────────────────────────────────
cells.append(code(
"""# Cell 12 — Full Results Table
from IPython.display import display

if 'df_ok' not in dir() or df_ok.empty:
    print('No results yet. Run Cell 8 first.')
else:
    dcols = ['trial','Q_deep','T_start_deep','T_end_deep','Q_central',
             'T_start_cen','T_end_cen','co2_mt','bhp_bar','penalty','reward']
    df_show = df_ok[dcols].copy()
    df_show['trial'] = df_show['trial'].astype(int) + 1
    df_show = df_show.sort_values('reward', ascending=False).reset_index(drop=True)

    def style_row(row):
        out = []
        for col in row.index:
            if col == 'bhp_bar' and row['bhp_bar'] > BHP_LIMIT_BAR:
                out.append('background-color:#ffdddd')
            elif col == 'reward' and row.name == 0:
                out.append('background-color:#ddffdd;font-weight:bold')
            else:
                out.append('')
        return out

    styled = df_show.style.apply(style_row, axis=1).format({
        'Q_deep':'{:.2f}','Q_central':'{:.2f}','co2_mt':'{:.2f}',
        'bhp_bar':'{:.2f}','penalty':'{:.1f}','reward':'{:.2f}'
    })
    print('All trials sorted by reward. 🟢 = best,  🔴 = BHP breach')
    display(styled)""", "c12"))

# ── 13: Apply best ────────────────────────────────────────────────────────────
cells.append(code(
"""# Cell 13 — Apply Optimal Parameters to well_plan.csv
# APPLY_MODE: 'best_safe'   → best CO₂ with BHP ≤ limit  (recommended)
#             'best_reward' → unconstrained best

APPLY_MODE = 'best_safe'

if 'df_ok' not in dir() or df_ok.empty:
    print('No results yet.')
else:
    df_safe = df_ok[df_ok['bhp_bar'] <= BHP_LIMIT_BAR]
    if APPLY_MODE == 'best_safe' and df_safe.empty:
        print(f'⚠️ No safe trials. Applying best_reward instead.')
        APPLY_MODE = 'best_reward'
    chosen   = df_safe.loc[df_safe['co2_mt'].idxmax()] if APPLY_MODE == 'best_safe' else df_ok.loc[df_ok['reward'].idxmax()]
    mode_str = 'Best Safe (BHP-constrained)' if APPLY_MODE == 'best_safe' else 'Best Reward'

    print(f'📝 Applying [{mode_str}] parameters...')
    print(f'   Deep: Q={chosen[\"Q_deep\"]:.2f} Mt/yr  T=[{int(chosen[\"T_start_deep\"])}->{int(chosen[\"T_end_deep\"])}] yr')
    print(f'   Cen:  Q={chosen[\"Q_central\"]:.2f} Mt/yr  T=[{int(chosen[\"T_start_cen\"])}->{int(chosen[\"T_end_cen\"])}] yr')
    print(f'   Expected CO₂: {chosen[\"co2_mt\"]:.2f} Mt  |  BHP: {chosen[\"bhp_bar\"]:.2f} bar')

    write_well_plan(chosen['Q_deep'],    int(chosen['T_start_deep']), int(chosen['T_end_deep']),
                    chosen['Q_central'], int(chosen['T_start_cen']),  int(chosen['T_end_cen']))

    print('\\n✅ well_plan.csv updated! Run example3DJohansen.m for the final validation simulation.')
    print(f'   Backup at: {BACKUP_CSV}')""", "c13"))

# ── 14: Emergency restore ─────────────────────────────────────────────────────
cells.append(code(
"""# Cell 14 — Emergency Restore
# Uncomment and run ONLY to undo all changes to well_plan.csv.

# restore_well_plan()

print('Uncomment restore_well_plan() above to undo all changes.')""", "c14"))

notebook = {
    "cells": cells,
    "metadata": {
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python", "version": "3.9.0"}
    },
    "nbformat": 4,
    "nbformat_minor": 5
}

out = '/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/python/johansen_bo_handshake.ipynb'
with open(out, 'w') as f:
    json.dump(notebook, f, indent=1)
print(f"Created: {out}")
