//+------------------------------------------------------------------+
//|                    MaCrossStrategy.mqh                          |
//|   Strategy logic for MA Crossover                              |
//+------------------------------------------------------------------+
#ifndef MA_CROSS_STRATEGY_MQH
#define MA_CROSS_STRATEGY_MQH

#include "Context.mqh"
#include "../../Core/Utils.mqh"
#include <Trade/Trade.mqh>

CTrade trade;
int TimeHour(datetime t) {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
}
void MaCrossOverStrategy(SymbolContext *ctx) {
    // === 1. MA Crossover Signal with Confirmation ===
    bool bullishCrossover = (ctx.sd.priceData[1].open < ctx.GetMA(1)) && 
                             (ctx.sd.priceData[1].close > ctx.GetMA(1)) &&
                             (ctx.sd.priceData[2].close < ctx.GetMA(2));  // Confirmed crossover

    bool bearishCrossover = (ctx.sd.priceData[1].open > ctx.GetMA(1)) && 
                             (ctx.sd.priceData[1].close < ctx.GetMA(1)) &&
                             (ctx.sd.priceData[2].close > ctx.GetMA(2));  // Confirmed crossover

    // === 2. Trend Confirmation using ADX (multi-candle) ===
    double adx0 = ctx.GetADX(0);
    double adx1 = ctx.GetADX(1);
    double adx2 = ctx.GetADX(2);
    bool isStrongTrend = (adx0 > 40 && adx1 > 40 && adx2 > 40);

    bool fastAboveSlow = (ctx.GetMA(0) > ctx.GetSlowMA(0));
    bool fastBelowSlow = (ctx.GetMA(0) < ctx.GetSlowMA(0));

    // === 3. Momentum Filter using RSI ===
    bool rsiBullish = (ctx.GetRSI(0) > 50 && ctx.GetRSI(0) < 70);
    bool rsiBearish = (ctx.GetRSI(0) < 50 && ctx.GetRSI(0) > 30);

    // === 4. Price Relative to Slow MA ===
    bool priceAboveSlowMA = (ctx.sd.ask > ctx.GetSlowMA(0));
    bool priceBelowSlowMA = (ctx.sd.bid < ctx.GetSlowMA(0));

    // === 5. Volatility Filter ===
    double multiplier = (adx0 >= 50) ? 1.5 : (adx0 >= 45) ? 1.2 : 1.0;
    double minDistance = multiplier * ctx.GetATR(0);
    double maDistance = MathAbs(ctx.GetMA(0) - ctx.GetSlowMA(0));
    bool isDistanceEnough = (maDistance >= minDistance);

    // === 6. Time Filter ===
    int hour = TimeHour(TimeCurrent());
    bool isEntryHour = (hour >= 13 && hour < 17);

    // === 7. Candle Strength Filter ===
    double body = MathAbs(ctx.sd.priceData[1].close - ctx.sd.priceData[1].open);
    double candleRange = ctx.sd.priceData[1].high - ctx.sd.priceData[1].low;
    bool isStrongCandle = (candleRange > 0 && body / candleRange > 0.6);

    // === 8. Multi-bar Breakout ===
    double high1 = ctx.sd.priceData[1].high;
    double high2 = ctx.sd.priceData[2].high;
    bool is2BarHighBreak = (ctx.sd.ask > MathMax(high1, high2));

    double low1 = ctx.sd.priceData[1].low;
    double low2 = ctx.sd.priceData[2].low;
    bool is2BarLowBreak = (ctx.sd.bid < MathMin(low1, low2));

    // === 9. Distance from MA ===
    bool isBuyNotTooExtended = (MathAbs(ctx.sd.ask - ctx.GetMA(0)) <= 2.5 * ctx.GetATR(0));
    bool isSellNotTooExtended = (MathAbs(ctx.sd.bid - ctx.GetMA(0)) <= 2.5 * ctx.GetATR(0));

    // === 10. Resistance/Support Check ===
    double recentHigh = GetRecentSwingHigh(ctx.sd.symbol, Timeframe, 10);
    bool isBelowResistance = ctx.sd.ask < (recentHigh - 2 * ctx.sd.point * 10);

    double recentLow = GetRecentSwingLow(ctx.sd.symbol, Timeframe, 10);
    bool isAboveSupport = ctx.sd.bid > (recentLow + 2 * ctx.sd.point * 10);

    // === 11. Spread Control ===
    bool isSpreadOK = ctx.sd.spread < (3 * ctx.sd.point * 10);

    // === 12. Volume Spike ===
    bool isVolumeSpike = ctx.sd.volumes[1] > ctx.sd.volumes[2] * 1.5;

    // === ✅ LONG ENTRY ===
    if (isStrongTrend &&
        bullishCrossover &&
        //is2BarHighBreak &&
        fastAboveSlow &&
        priceAboveSlowMA &&
        rsiBullish &&
        //isDistanceEnough &&
        isStrongCandle &&
        isEntryHour &&
        isBuyNotTooExtended &&
        isBelowResistance &&
        isSpreadOK &&
        isVolumeSpike //&&
        //!IsLongPositionOpen(ctx.sd.symbol)
        ) 
    {
        double sl = GetRecentSwingLow(ctx.sd.symbol, Timeframe, 4);
        double tp = ctx.sd.ask + 6 * ctx.GetATR(0);
        double lots = ctx.sd.dynamicLotSize("BUY", RiskPercent, sl);
        trade.Buy(lots, ctx.sd.symbol, ctx.sd.ask, sl, tp, "MA-Bull");
    }

    // === ✅ SHORT ENTRY ===
    if (isStrongTrend &&
        bearishCrossover &&
        //is2BarLowBreak &&
        fastBelowSlow &&
        priceBelowSlowMA &&
        rsiBearish &&
        //isDistanceEnough &&
        isStrongCandle &&
        isEntryHour &&
        isSellNotTooExtended &&
        isAboveSupport &&
        isSpreadOK &&
        isVolumeSpike //&&
        //!IsShortPositionOpen(ctx.sd.symbol)
        ) 
    {
        double sl = GetRecentSwingHigh(ctx.sd.symbol, Timeframe, 4);
        double tp = ctx.sd.bid - 6 * ctx.GetATR(0);
        double lots = ctx.sd.dynamicLotSize("SELL", RiskPercent, sl);
        trade.Sell(lots, ctx.sd.symbol, ctx.sd.bid, sl, tp, "MA-Bear");
    }
}


void UpdateTrailingSL(SymbolContext *ctx) {
   ulong ticket;
   if (!PositionSelect(ctx.sd.symbol))
      return;

   double sl, tp;
   double currentPrice = ctx.sd.bid;
   int pipToStartTrailing = 5;
   ticket = PositionGetTicket(0);

   double newSL;
   if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
      newSL = GetRecentSwingLow(ctx.sd.symbol,Timeframe, 5) - ctx.sd.point * pipToStartTrailing*10;
   } else {
      newSL = GetRecentSwingHigh(ctx.sd.symbol,Timeframe, 5) + ctx.sd.point * pipToStartTrailing*10;
   }

   // Only trail if newSL is better
   double oldSL = PositionGetDouble(POSITION_SL);
   if ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && newSL > oldSL) ||
       (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && newSL < oldSL)) {

      trade.PositionModify(ctx.sd.symbol, newSL, PositionGetDouble(POSITION_TP));
      Print("🔁 Trailing SL updated for ", ctx.sd.symbol, ": ", newSL);
   }
}
//+------------------------------------------------------------------+
void ManageExits(SymbolContext *ctx) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != ctx.sd.symbol) 
         continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);
      double size = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double atrBuffer = ctx.GetATR(0) * 0.5; // Wider buffer for trends
      double atr = ctx.GetATR(0);  // Always use current ATR
      double spread = SymbolInfoInteger(ctx.sd.symbol, SYMBOL_SPREAD) * ctx.sd.point;
      string symbol = PositionGetString(POSITION_SYMBOL);
      
      if (StringFind(comment, "Trend") != -1) {
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
         
            if (type == POSITION_TYPE_BUY) {
               double gain = ctx.sd.bid - entryPrice;
               double newSL = sl;
            
               
               // ✅ Ensure SL never moves backward
               if (newSL > sl && newSL > entryPrice && (MathAbs(newSL - sl) > ctx.sd.point)) {
                  trade.PositionModify(symbol, newSL, tp);
                  Print("🔵 SL Trailed (BUY): ", DoubleToString(newSL, _Digits));
               }
            }
         
            if (type == POSITION_TYPE_SELL) {
               double gain = entryPrice - ctx.sd.ask;
               double newSL = sl;
            
            
               if (newSL < sl && newSL < entryPrice && (MathAbs(newSL - sl) > ctx.sd.point)) {
                  trade.PositionModify(symbol, newSL, tp);
                  Print("🔴 SL Trailed (SELL): ", DoubleToString(newSL, _Digits));
               }
            }

         }//end of trend

      
      
    }//for close
      
      
}
#endif // MA_CROSS_STRATEGY_MQH
