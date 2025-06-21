//+------------------------------------------------------------------+
//|                   Zone Recovery RSI EA (Multi-Currency)          |
//|                       Copyright 2024, MetaQuotes Ltd.            |
//+------------------------------------------------------------------+
#property strict
#include "Modules/ZoneRecovery.mqh"
#include <Arrays/ArrayObj.mqh>

input string SymbolsList = "EURUSD:700:1400,GBPUSD:800:1600,USDJPY:600:1200"; // Format: SYMBOL:ZonePts:TargetPts
input int rsiPeriod = 14;
input double initialLotSize = 0.1;
input int minRsiDelta = 5;                 // Minimum RSI change to trigger signal
input int minSignalCooldownBars = 2;       // Minimum bars between signals

string symbolsRaw[];
CArrayObj symbolContexts;

// Helper to split and trim symbol names
void ParseSymbols(string csv) {
   StringSplit(csv, ',', symbolsRaw);
   for (int i = 0; i < ArraySize(symbolsRaw); i++) {
      StringTrimLeft(symbolsRaw[i]);
      StringTrimRight(symbolsRaw[i]);
   }
}

void DrawHorizontalLine(string sym, string lineName, double priceLevel, color lineColor = clrRed) {
   string fullName = sym + ":" + lineName;
   long chartId = ChartFirst();
   while (chartId >= 0) {
      if (ChartSymbol(chartId) == sym) {
         if (ObjectFind(chartId, fullName) != -1)
            ObjectDelete(chartId, fullName);
         ObjectCreate(chartId, fullName, OBJ_HLINE, 0, 0, priceLevel);
         ObjectSetInteger(chartId, fullName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(chartId, fullName, OBJPROP_WIDTH, 2);
      }
      chartId = ChartNext(chartId);
   }
}

// Structure to hold per-symbol context
class SymbolContext : public CObject {
public:
   string symbol;
   int rsiHandle;
   double rsiBuffer[];
   datetime lastBarTime;
   datetime lastSignalTime;
   ZoneRecovery zoneRecovery;

   SymbolContext(string sym, int zonePts, int targetPts) : symbol(sym), zoneRecovery(initialLotSize, zonePts, targetPts, 2.0, sym) {
      rsiHandle = iRSI(sym, PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE);
      ArrayResize(rsiBuffer, 2);
      ArraySetAsSeries(rsiBuffer, true);
      lastBarTime = 0;
      lastSignalTime = 0;
   }
};

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit() {
   ParseSymbols(SymbolsList);
   for (int i = 0; i < ArraySize(symbolsRaw); i++) {
      string entry = symbolsRaw[i];
      string parts[];
      StringSplit(entry, ':', parts);
      if (ArraySize(parts) < 3) {
         Print("Invalid symbol format: ", entry);
         continue;
      }
      string sym = parts[0];
      int zonePts = (int)StringToInteger(parts[1]);
      int targetPts = (int)StringToInteger(parts[2]);

      SymbolContext *ctx = new SymbolContext(sym, zonePts, targetPts);
      if (ctx.rsiHandle == INVALID_HANDLE) {
         Print("Failed to create RSI for ", sym, " Error: ", GetLastError());
         delete ctx;
         continue;
      }
      symbolContexts.Add(ctx);
   }

   Print("Multi-symbol Zone Recovery RSI EA initialized.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   for (int i = 0; i < symbolContexts.Total(); i++) {
      SymbolContext *ctx = (SymbolContext*)symbolContexts.At(i);
      if (ctx.rsiHandle != INVALID_HANDLE)
         IndicatorRelease(ctx.rsiHandle);
   }
   symbolContexts.Clear();
}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick() {
   for (int i = 0; i < symbolContexts.Total(); i++) {
      SymbolContext *ctx = (SymbolContext*)symbolContexts.At(i);
      string sym = ctx.symbol;

      datetime currentBarTime = iTime(sym, PERIOD_CURRENT, 0);
      if (currentBarTime == ctx.lastBarTime)
         continue;

      ctx.lastBarTime = currentBarTime;

      if (CopyBuffer(ctx.rsiHandle, 0, 1, 2, ctx.rsiBuffer) <= 0) {
         Print(sym, ": Failed to copy RSI buffer. Error: ", GetLastError());
         continue;
      }

      double rsiPrev = ctx.rsiBuffer[1];
      double rsiCurr = ctx.rsiBuffer[0];
      double rsiDelta = MathAbs(rsiCurr - rsiPrev);
      int barsSinceLastSignal = (int)((TimeCurrent() - ctx.lastSignalTime) / PeriodSeconds(PERIOD_CURRENT));

      if (barsSinceLastSignal >= minSignalCooldownBars) {
         if (rsiPrev > 30 && rsiCurr <= 30 && rsiDelta >= minRsiDelta) {
            Print(sym, ": BUY SIGNAL");
            ctx.lastSignalTime = TimeCurrent();
            ctx.zoneRecovery.HandleSignal(ORDER_TYPE_BUY);
            DrawHorizontalLine(sym, "ZoneTargetHigh", ctx.zoneRecovery.getZoneTargetHigh(), clrGreen);
            DrawHorizontalLine(sym, "ZoneHigh", ctx.zoneRecovery.getZoneHigh(), clrRed);
            DrawHorizontalLine(sym, "ZoneLow", ctx.zoneRecovery.getZoneLow(), clrRed);
            DrawHorizontalLine(sym, "ZoneTargetLow", ctx.zoneRecovery.getZoneTargetLow(), clrGreen);
         } else if (rsiPrev < 70 && rsiCurr >= 70 && rsiDelta >= minRsiDelta) {
            Print(sym, ": SELL SIGNAL");
            ctx.lastSignalTime = TimeCurrent();
            ctx.zoneRecovery.HandleSignal(ORDER_TYPE_SELL);
            DrawHorizontalLine(sym, "ZoneTargetHigh", ctx.zoneRecovery.getZoneTargetHigh(), clrGreen);
            DrawHorizontalLine(sym, "ZoneHigh", ctx.zoneRecovery.getZoneHigh(), clrRed);
            DrawHorizontalLine(sym, "ZoneLow", ctx.zoneRecovery.getZoneLow(), clrRed);
            DrawHorizontalLine(sym, "ZoneTargetLow", ctx.zoneRecovery.getZoneTargetLow(), clrGreen);
         }
      }

      ctx.zoneRecovery.ManageZones();
      ctx.zoneRecovery.CheckCloseAtTargets();
   }
}
