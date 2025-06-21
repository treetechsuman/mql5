//+------------------------------------------------------------------+
//|                     ModularEA_Refactored.mq5                     |
//|     Refactored EA using SymbolData and per-symbol indicators   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>

#include "Modules/Core/Core.mqh"
#include "Modules/Indicators/RSIIndicator.mqh"
#include "Modules/Indicators/MaIndicator.mqh"

#include "Modules/Strategies/MaCrossOver/Context.mqh"
#include "Modules/Strategies/MaCrossOver/Strategy.mqh"

CArrayObj contexts;
CTrade trade;

string Rows[] = {"Symbol"};
datetime lastTradeTime[];
//+------------------------------------------------------------------+
int OnInit() {
   contexts.Clear();

   string list[];
   StringSplit(Symbols, ',', list);

   for (int i = 0; i < ArraySize(list); i++) {
      SymbolData *sd = new SymbolData;
      if (sd.Init(list[i])) {
         SymbolContext *ctx = new SymbolContext(sd,RSIPeriod, MaPeriod, VolLookback, Timeframe);
         contexts.Add(ctx);
      } else {
         delete sd;
      }
   }
   ArrayResize(lastTradeTime, ArraySize(list));
   InitDashboard(list, Rows, 20, 20);
   ArrayInitialize(lastTradeTime, 0);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   for (int i = 0; i < contexts.Total(); i++) {
      SymbolContext *ctx = (SymbolContext*)contexts.At(i);
      delete ctx;
   }
   contexts.Clear();
}

//+------------------------------------------------------------------+
void OnTick() {
   for (int i = 0; i < contexts.Total(); i++) {
      SymbolContext *ctx = (SymbolContext*)contexts.At(i);
      SymbolData *sd = ctx.sd;

      if (!sd.IsNewCandle()) continue;

      CopyRates(sd.symbol, Timeframe, 0, VolLookback, sd.priceData);
      CopyTickVolume(sd.symbol, Timeframe, 0, VolLookback, sd.volumes);
      sd.UpdateMarketInfo();
      
      //display infor in dashboard
      SignalStatus s1;
      ArrayResize(s1.values, 1);
      s1.values[0] = sd.symbol;
      
      UpdateDashboard(sd.symbol, s1);

      ctx.LoadIndicators();
      ProcessSymbol(ctx);
   }
}

//+------------------------------------------------------------------+
//this is for git test after setup
void ProcessSymbol(SymbolContext *ctx) {
   double rsi = ctx.GetRSI();
   double ma  = ctx.GetMA();
   Print(ctx.sd.symbol, " | RSI=", rsi, " | MA=", ma);
   MaCrossOverStrategy(ctx);
}
