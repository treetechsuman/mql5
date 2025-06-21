#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>

#include "Modules/Core/Symbols.mqh"
#include "Modules/Indicators/RSIIndicator.mqh"
#include "Modules/Indicators/MaIndicator.mqh"
#include "Modules/Strategies/MaCrossOver/Context.mqh"
#include "Modules/Strategies/MaCrossOver/SetupSymbol.mqh"
#include "Modules/Strategies/MaCrossOver/Strategy.mqh"

input string Symbols = "EURUSD,GBPUSD";
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input int FastPeriod = 9;
input int SlowPeriod = 21;
input int Lookback = 30;

CArrayObj contexts;

//+------------------------------------------------------------------+
int OnInit() {
   contexts.Clear();
   SetupSymbol(Symbols, Timeframe, FastPeriod, SlowPeriod, Lookback, contexts);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   for (int i = 0; i < contexts.Total(); i++) {
      MaCrossContext *ctx = (MaCrossContext*)contexts.At(i);
      delete ctx;
   }
   contexts.Clear();
}

//+------------------------------------------------------------------+
void OnTick() {
   for (int i = 0; i < contexts.Total(); i++) {
      MaCrossContext *ctx = (MaCrossContext*)contexts.At(i);
      RunMaCrossStrategy(ctx);
   }
}
