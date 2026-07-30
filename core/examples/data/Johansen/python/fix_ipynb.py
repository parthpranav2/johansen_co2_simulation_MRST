import json

with open('/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/python/johansen_eda.ipynb', 'r') as f:
    content = f.read()

content = content.replace(
    "        except: pass\\n\\n        ax1.set_ylabel('Pressure (bar)', fontsize=11, fontweight='bold')",
    "        except: pass\\n\\n        ax1.axhline(380, color='red', ls='--', lw=1.5, label='P=380 psi limit')\\n        ax1.set_ylabel('Pressure (bar)', fontsize=11, fontweight='bold')"
)

content = content.replace(
    "    ax.set_xlabel('Time (years)', fontsize=11)\\n    ax.set_ylabel(ylabel, fontsize=11)",
    "    ax.set_xlabel('Time (years)', fontsize=11)\\n    if 'Pressure' in ylabel:\\n        ax.axhline(380, color='red', ls='--', lw=1.5, label='P=380 psi limit')\\n    ax.set_ylabel(ylabel, fontsize=11)"
)

content = content.replace(
    "ax.set_xlabel('Time (years)', fontsize=11)\\nax.set_ylabel('Mean Layer Pressure (bar)', fontsize=11)",
    "ax.set_xlabel('Time (years)', fontsize=11)\\nax.axhline(380, color='red', ls='--', lw=1.5, label='P=380 psi limit')\\nax.set_ylabel('Mean Layer Pressure (bar)', fontsize=11)"
)

content = content.replace(
    "axes[0].set_xlabel('Injection Rate (Mt/yr)', fontsize=11)\\naxes[0].set_ylabel('Peak Reservoir Pressure (bar)', fontsize=11)",
    "axes[0].set_xlabel('Injection Rate (Mt/yr)', fontsize=11)\\naxes[0].axhline(380, color='red', ls='--', lw=1.5, label='P=380 psi limit')\\naxes[0].set_ylabel('Peak Reservoir Pressure (bar)', fontsize=11)"
)

content = content.replace(
    "axes[2].axhline(df_cap['P_init'].mean(), color='k', ls='--', label='Initial P')\\naxes[2].set_xlabel('Injection Rate (Mt/yr)', fontsize=11)",
    "axes[2].axhline(df_cap['P_init'].mean(), color='k', ls='--', label='Initial P')\\naxes[2].axhline(380, color='red', ls='--', lw=1.5, label='P=380 psi limit')\\naxes[2].set_xlabel('Injection Rate (Mt/yr)', fontsize=11)"
)

content = content.replace(
    "        metrics_used = ['Pressure','CO2 Saturation'] if metric=='Both' else [metric]\\n        for ax, m in zip(axes, metrics_used):\\n            ax.set_ylabel(m, fontsize=11)",
    "        metrics_used = ['Pressure','CO2 Saturation'] if metric=='Both' else [metric]\\n        for ax, m in zip(axes, metrics_used):\\n            if 'Pressure' in m:\\n                ax.axhline(380, color='red', ls='--', lw=1.5, label='P=380 psi limit')\\n            ax.set_ylabel(m, fontsize=11)"
)

with open('/Users/apple/Desktop/study/programming/Matlab/Plugins/MRST-2026a/core/examples/data/Johansen/python/johansen_eda.ipynb', 'w') as f:
    f.write(content)

