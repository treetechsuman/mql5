//+------------------------------------------------------------------+
//|      RecentMACrossoverTracker.mqh                                |
//|   Tracks and recalls last crossover time for each symbol         |
//+------------------------------------------------------------------+
#ifndef __MA_CROSSOVER_TRACKER_MQH__
#define __MA_CROSSOVER_TRACKER_MQH__

datetime lastBullishCrossoverTime = 0;
datetime lastBearishCrossoverTime = 0;

// 🟡 Call this once per candle or in OnTick()
void UpdateCrossoverTimestamps(SymbolContext *ctx, int lookback = 1) {
   int cross = DidMACrossoverHappen(ctx, lookback);
   if (cross == BULLISH)
      lastBullishCrossoverTime = TimeCurrent();
   else if (cross == BEARISH)
      lastBearishCrossoverTime = TimeCurrent();
}

// ✅ Call before entry logic
bool IsRecentBullishCrossover(int secondsBack = 6 * 3600) {
   return (lastBullishCrossoverTime > 0 &&
           (TimeCurrent() - lastBullishCrossoverTime) <= secondsBack);
}

bool IsRecentBearishCrossover(int secondsBack = 6 * 3600) {
   return (lastBearishCrossoverTime > 0 &&
           (TimeCurrent() - lastBearishCrossoverTime) <= secondsBack);
}

#endif // __MA_CROSSOVER_TRACKER_MQH__
