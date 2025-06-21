# 📈 MQL5 Modular Strategy Framework

This repository implements a modular and scalable Expert Advisor (EA) structure for MetaTrader 5 using object-oriented practices in MQL5. It allows clean separation of concerns and easy strategy expansion.

---

## 📁 Folder Structure

```
Modules/
│
├── Core/                  # Shared core utilities
│   ├── Symbols.mqh
│   ├── SymbolManager.mqh
│   ├── InfoDashboard.mqh
│   ├── RiskManagement.mqh
│   └── Utils.mqh
│
├── Indicators/            # Indicator wrappers
│   ├── MaIndicator.mqh
│   └── RSIIndicator.mqh
│
├── Recoveries/            # Loss recovery mechanisms
│   ├── ZoneRecovery.mqh
│   ├── AdvanceLossRecovery.mqh
│   └── LossCooldownManager.mqh
│
├── Reports/
│   └── SymbolReport.mqh
│
├── Signals/               # Trade signal generators
│   ├── RsiSignal.mqh
│   ├── EmaSignal.mqh
│   ├── BollingerBandSignal.mqh
│   └── ...
│
└── Strategies/            # Each strategy has its own folder
    ├── MaCrossOver/
    │   ├── Context.mqh
    │   ├── Inputs.mqh
    │   └── Strategy.mqh
    └── BBSqueezeTrendRange/
        ├── Context.mqh
        ├── Inputs.mqh
        └── Strategy.mqh
```

---

## 🧩 How to Add a New Strategy

1. **Create a Folder**  
   Inside `Modules/Strategies/`, make a folder like `MyNewStrategy`.

2. **Add Three Files**  
   - `Context.mqh`: Stores per-symbol indicator objects.
   - `Inputs.mqh`: All input parameters for the strategy.
   - `Strategy.mqh`: Core logic of entry/exit/trade handling.

3. **Reference in EA**  
   Include these files inside your main `.mq5` EA file.

---

## 🧠 Benefits of This Approach

✅ **Modularity**: Each strategy is self-contained  
✅ **Reusability**: Common indicators and utilities reused  
✅ **Scalability**: Add new strategies without breaking others  
✅ **Maintainability**: Clean object-based code design  

---

## 🚀 Getting Started

Clone the repo, open your EA in MetaEditor, and attach to chart.

```bash
git clone https://github.com/yourname/mql5-modular-framework.git
```

---

## 📜 License

MIT – free to use, modify, and distribute.
