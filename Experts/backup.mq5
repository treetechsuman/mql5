//+------------------------------------------------------------------+
//|                     ModularEA_Refactored.mq5                     |
//|     Refactored EA using SymbolData and per-symbol indicators   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>

#include "Modules/Core/Symbols.mqh"
#include "Modules/Indicators/RSIIndicator.mqh"
#include "Modules/Indicators/MaIndicator.mqh"

#include "Modules/Strategies/MaCrossOver/Context.mqh"
#include "Modules/Strategies/MaCrossOver/inputs.mqh"
#include "Modules/Strategies/MaCrossOver/Strategy.mqh"


CArrayObj contexts;
CTrade trade;

//+------------------------------------------------------------------+
int OnInit() {
   contexts.Clear();

   string list[];
   StringSplit(Symbols, ',', list);

   for (int i = 0; i < ArraySize(list); i++) {
      SymbolData *sd = new SymbolData;
      if (sd.Init(list[i])) {
         SymbolContext *ctx = new SymbolContext(sd);
         contexts.Add(ctx);
      } else {
         delete sd;
      }
   }

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

      ctx.LoadIndicators();
      ProcessSymbol(ctx);
   }
}

//+------------------------------------------------------------------+
void ProcessSymbol(SymbolContext *ctx) {
   double rsi = ctx.GetRSI();
   double ma  = ctx.GetMA();
   Print(ctx.sd.symbol, " call crossover strategy ");
   //MaCrossOverStrategy(ctx);
}
