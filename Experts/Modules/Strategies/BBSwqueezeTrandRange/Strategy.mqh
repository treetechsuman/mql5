//+------------------------------------------------------------------+
//|                    MaCrossStrategy.mqh                          |
//|   Strategy logic for MA Crossover                              |
//+------------------------------------------------------------------+
#ifndef MA_CROSS_STRATEGY_MQH
#define MA_CROSS_STRATEGY_MQH

#include "Context.mqh"
#include <Trade/Trade.mqh>

//CTrade trade;

void MaCrossOverStrategy(SymbolContext *ctx) {
   double rsi = ctx.GetRSI();
   double ma  = ctx.GetMA();
   Print(ctx.sd.symbol, " | RSI=", rsi, " | MA=", ma);
   Print("MaCrossOverStrategy is active");
}

#endif // MA_CROSS_STRATEGY_MQH
