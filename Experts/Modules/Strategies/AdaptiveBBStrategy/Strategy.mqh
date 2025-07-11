//+------------------------------------------------------------------+
//|                    MaCrossStrategy.mqh                          |
//|   Strategy logic for MA Crossover                              |
//+------------------------------------------------------------------+
#ifndef MA_CROSS_STRATEGY_MQH
#define MA_CROSS_STRATEGY_MQH

#include "Context.mqh"
#include "Function.mqh"
#include "../../Core/Core.mqh"
#include <Trade/Trade.mqh>

CTrade trade;
int TimeHour(datetime t) {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
}

void BBSqueezeStrategy(SymbolContext *ctx) {
   Print("BBSqueezeStrategy is active");
   // 1. Add SQUEEZE CONDITION (essential for this strategy)
    double bandwidth = (ctx.GetEntryBBUpper(1) - ctx.GetEntryBBLower(1)) / ctx.GetMiddleBB(1);
    bool isSqueeze = bandwidth < 0.05;  // Threshold varies by instrument
    double atr = ctx.GetATR(1);
    double breakoutBuffer = 1.5 * ctx.sd.point;
    
    
    
    bool bullishRSI = ctx.GetRSI(2) < 50 && ctx.GetRSI(1) > 50; // upward cross of RSI midpoint
    double rsiSlope = ctx.GetRSI(1) - ctx.GetRSI(3);  // 2-bar slope

      bool rsiBullishSlope = rsiSlope > 5;   // customizable threshold
      
      bool rsiBearishSlope = rsiSlope < -5;
      
      bool bullishDiv = false, bearishDiv = false;
      DetectRSIDivergence(ctx, 20, bullishDiv, bearishDiv);
      
      //if (!cooldown.CanTrade(sd.symbol))
      //return;  // skip due to cooldown
    // Final entry condition
   bool bull = isSqueeze
       && IsBreakoutConfirmed(ctx,"bull",breakoutBuffer)        // Breakout with buffer
       && ctx.sd.volumes[1] > ctx.sd.volumes[2]*1.2
       //&& bullishRSI
       && rsiBullishSlope
       && bullishDiv
       && ctx.GetRSI(0) < 70;
                                         // Avoid overbought
    
    bool bearishRSI = ctx.GetRSI(2) > 50 && ctx.GetRSI(1)< 50; // downward cross of RSI midpoint
    bool bear = isSqueeze 
       && IsBreakoutConfirmed(ctx, "bear", breakoutBuffer)
       && ctx.sd.volumes[1] > ctx.sd.volumes[2]*1.2
       //&& bearishRSI
       && rsiBearishSlope
       && bearishDiv
       && ctx.GetRSI(0) > 30;

    // 3. Improved Position Management
    if(bull&&IsNewBar(ctx.sd.symbol,Timeframe)) {
        double sl = ctx.sd.ask-1.5*atr; // Below recent low
        double tp = ctx.sd.ask + 3*atr;                        // 1:2 risk-reward
        
        double dist = ctx.sd.ask - sl;
        if(dist > 0) {
            double lotSize = ctx.sd.dynamicLotSize("BUY", RiskPercent, sl);
            if(lotSize > 0) trade.Buy(lotSize, ctx.sd.symbol, ctx.sd.ask, sl, tp, "Squeeze-Bull");
        }
    }
    else if(bear&&IsNewBar(ctx.sd.symbol,Timeframe)) {
        double sl = ctx.sd.bid + 1.5*atr;
        double tp = ctx.sd.bid-3*atr;
        
        double dist = sl - ctx.sd.bid;
        if(dist > 0) {
            double lotSize = ctx.sd.dynamicLotSize("SELL", RiskPercent, sl);
            if(lotSize > 0) trade.Sell(lotSize, ctx.sd.symbol, ctx.sd.bid, sl, tp, "Squeeze-Bear");
        }
    }
}

void BBRangingStrategy(SymbolContext *ctx) {
   
    double atr = ctx.GetATR(1);
    
    bool candleTouchesBelowBB = ctx.sd.priceData[1].low < ctx.GetEntryBBLower(1) && ctx.sd.priceData[1].low<ctx.sd.priceData[2].low;
    bool candleTouchesUpperBB = ctx.sd.priceData[1].high > ctx.GetEntryBBUpper(1)&& ctx.sd.priceData[1].high>ctx.sd.priceData[2].high;
    
    bool candleCloseBelowAndBulish = ctx.sd.priceData[2].open > ctx.GetEntryBBLower(2) && //previous candle open above and close bellow lowerBB
                                     ctx.sd.priceData[2].close < ctx.GetEntryBBLower(2) &&
                                     ctx.sd.priceData[1].open < ctx.GetEntryBBLower(1) && //current candle is bulish
                                     ctx.sd.priceData[1].close > ctx.GetEntryBBLower(1);
                                     
    bool candleCloseAboveAndBearish = ctx.sd.priceData[2].open < ctx.GetEntryBBUpper(2) && //previous candle open below and close above upperBB
                                     ctx.sd.priceData[2].close > ctx.GetEntryBBUpper(2) &&
                                     ctx.sd.priceData[1].open > ctx.GetEntryBBUpper(1) && //current candle is bearish
                                     ctx.sd.priceData[1].close < ctx.GetEntryBBUpper(1);
    bool bullishRsi = ctx.GetRSI(0)<30;
    bool bearishRsi = ctx.GetRSI(0)>70;
    double rsiSlope = ctx.GetRSI(1) - ctx.GetRSI(3);  // 2-bar slope
    bool rsiBullishSlope = rsiSlope > 1;   // customizable threshold  
    bool rsiBearishSlope = rsiSlope < -1;
    // === 3. ATR Filter ===
    double atrNow = ctx.GetATR(0);
    double atrPips = atrNow / ctx.sd.point / 10.0;
    bool atrConfirmation = atrPips > 10;
    bool adxConfirmation = ctx.GetADX(0)<20;
    
    
    bool bull = 
                //candleCloseBelowAndBulish&&
                candleTouchesBelowBB&&
                //IsBullishEngulfing(ctx)&&
                //adxConfirmation&&
                //atrConfirmation;//&&
                bullishRsi;//&&
                //rsiBullishSlope&&
                //!IsLongPositionOpen(ctx.sd.symbol);
       
                                    
    bool bear = 
                //candleCloseAboveAndBearish&&
                candleTouchesUpperBB&& 
                //IsBearishEngulfing(ctx);//&&            
                //adxConfirmation&&
                //atrConfirmation;//&&
                bearishRsi;//&&
                //rsiBearishSlope&&
                //!IsShortPositionOpen(ctx.sd.symbol);
    
    double SLMultiplier = 1;  
    if(bull&&IsNewBar(ctx.sd.symbol,Timeframe)) {
        double distanceToMid = MathAbs(ctx.sd.priceData[1].close - ctx.GetTakeProfitBBUpper(0)); 
        //double sl = GetRecentSwingLow(ctx.sd.symbol,Timeframe,5)-0.5*atr;
        double sl = ctx.sd.ask - distanceToMid * SLMultiplier;  // SLMultiplier = 1.2 or 1.5
        //double sl = ctx.GetExitLossBBLower(0);  // SLMultiplier = 1.2 or 1.5
        
        //double tp = ctx.GetMiddleBB(0);
        double tp = ctx.GetTakeProfitBBUpper(0);
        //double sl = ctx.sd.ask-1.5*atr; // Below recent low
        //double tp = ctx.sd.ask + 1.5*atr;      
        double lotSize = ctx.sd.dynamicLotSize("BUY", RiskPercent, sl);
        if(lotSize > 0) trade.Buy(lotSize, ctx.sd.symbol, ctx.sd.ask, sl, tp, "Ranging-Bull");
        
    }
    else if(bear&&IsNewBar(ctx.sd.symbol,Timeframe)) {
        double distanceToMid = MathAbs(ctx.sd.priceData[1].close - ctx.GetTakeProfitBBLower(0)); 
        //double sl = GetRecentSwingHigh(ctx.sd.symbol,Timeframe,5)+0.5*atr;
        double sl = ctx.sd.ask + distanceToMid * SLMultiplier;  // SLMultiplier = 1.2 or 1.5
        // double sl = ctx.GetExitLossBBUpper(0);  // SLMultiplier = 1.2 or 1.5
        //double tp = ctx.GetMiddleBB(0);
        double tp = ctx.GetTakeProfitBBLower(0); 
        //double sl = ctx.sd.bid+1.5*atr; // Below recent low
        //double tp = ctx.sd.bid - 1.5*atr;  
        double lotSize = ctx.sd.dynamicLotSize("SELL", RiskPercent, sl);
        if(lotSize > 0) trade.Sell(lotSize, ctx.sd.symbol, ctx.sd.bid, sl, tp, "Ranging-Bear");
       
    }
}



void UpdateTrailingSL(SymbolContext *ctx) {
   if (!PositionSelect(ctx.sd.symbol)) return;

   ulong ticket = PositionGetTicket(0);
   int type = (int)PositionGetInteger(POSITION_TYPE);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double slOld = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);

   double atr = ctx.GetATR(0);
   if (atr <= 0.0) return;

   double price = (type == POSITION_TYPE_BUY) ? ctx.sd.bid : ctx.sd.ask;
   double gain = MathAbs(price - entry);
   double newSL = slOld;
   double newTP = tp;
   newTP = (type == POSITION_TYPE_BUY)
           ? ctx.GetEntryBBUpper(0)
           : ctx.GetEntryBBLower(0);
   bool TpIsBetter = (type == POSITION_TYPE_BUY) ? (newTP > tp) : (newTP < tp);
   // === 🔐 Forced close if price moves too far against us
   bool lossTooBig = (type == POSITION_TYPE_BUY && price < entry - 5.0 * atr) ||
                     (type == POSITION_TYPE_SELL && price > entry + 5.0 * atr);

   if (lossTooBig) {
      Print("🛑 Forced close ticket #", ticket, " on ", ctx.sd.symbol,
            " | Entry=", entry, " Price=", price, " ATR=", atr);
      if (!trade.PositionClose(ticket))
         Print("❌ Close failed: ", trade.ResultRetcode());
      return; // prevent further SL modification after forced close
   }
   if (price > ctx.GetMiddleBB(0) && type == POSITION_TYPE_BUY && slOld<entry) {
    double partialLots = PositionGetDouble(POSITION_VOLUME) * 0.5;
    ClosePartial(ctx.sd.symbol, partialLots);
    newSL = entry + 0.1 * atr;  // Move SL for remaining 50%
   }
   
   if (price < ctx.GetMiddleBB(0) && type == POSITION_TYPE_SELL&& slOld>entry) {
       double partialLots = PositionGetDouble(POSITION_VOLUME) * 0.5;
       ClosePartial(ctx.sd.symbol, partialLots);
       newSL = entry - 0.1 * atr;  // Move SL for remaining 50%
   }
   //if (price > ctx.GetEntryBBUpper(0) + atr*0.2 || 
   //    price < ctx.GetEntryBBLower(0) - atr*0.2) {
   //    if (!trade.PositionClose(ticket)) {
   //      Print("❌ Failed to close position on ", ctx.sd.symbol, ". Error: ", GetLastError());
   //   } else {
   //      Print("✅ Closed position early on ", ctx.sd.symbol);
   //   }
   //}
   //if (gain > 1.8 * atr)
   //   newSL = (type == POSITION_TYPE_BUY) ? entry + 0.3 * atr : entry - 0.3 * atr;
   //// === 🧠 New SL: 1.5 × ATR from current price
   //if(gain > 2.5*atr)
   //   newSL = (type == POSITION_TYPE_BUY)
   //        ? price - 1.5 * atr
   //        : price + 1.5 * atr;

   // === ✅ Apply Only If SL Improves
   bool slIsBetter = (type == POSITION_TYPE_BUY) ? (newSL > slOld) : (newSL < slOld);
   if (slIsBetter && newSL > 0 ) {
      if(TpIsBetter)tp=newTP;
      if (trade.PositionModify(ctx.sd.symbol, newSL, tp)) {
         Print("🔁 SL Trailed: ", ctx.sd.symbol, " → ", DoubleToString(newSL, _Digits));
      } else {
         Print("❌ Failed to modify SL: ", GetLastError());
      }
   }
}

bool ClosePartial(string symbol, double lotsToClose) {
    if (PositionSelect(symbol)) {
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        if (trade.PositionClosePartial(ticket, lotsToClose)) {
            Print("✅ Partial close: Closed ", lotsToClose, " lots on ", symbol);
            return true;
        } else {
            Print("❌ Partial close failed. Error: ", GetLastError());
            return false;
        }
    } else {
        Print("⚠️ No position to partial close on ", symbol);
        return false;
    }
}
void BBRangingScalpingStrategy(SymbolContext *ctx) {
   // === Time Filter: Only trade during London & NY sessions ===
   //int hour = TimeHour(TimeCurrent());
   //if (!(hour >= 7 && hour <= 16)) return;  // UTC 07:00–16:00 (London+NY)
   // === 6. Time Filter ===
    int hour = TimeHour(TimeCurrent());
    //bool isEntryHour = (hour >= 13 && hour < 17);
    bool isLondonOpen = (hour >= 7 && hour <=17);
    bool isNYLondonOverlap = (hour >= 23 || hour < 2);
    bool isEntryHour = isLondonOpen || isNYLondonOverlap;
   // === Spread Filter ===
   //if (ctx.sd.spread > 2 * ctx.sd.point) return;  // Avoid high spreads

   // === Indicators ===
   double atr = ctx.GetATR(1);
   double atrNow = ctx.GetATR(0);
   double atrPips = atrNow / ctx.sd.point / 10.0;

   bool candleTouchesBelowBB = ctx.sd.priceData[1].low < ctx.GetEntryBBLower(1) && ctx.sd.priceData[1].low < ctx.sd.priceData[2].low;
   bool candleTouchesUpperBB = ctx.sd.priceData[1].high > ctx.GetEntryBBUpper(1) && ctx.sd.priceData[1].high > ctx.sd.priceData[2].high;

   double rsiSlope = ctx.GetRSI(1) - ctx.GetRSI(3);
   bool rsiBullishSlope = rsiSlope > 0.5;
   bool rsiBearishSlope = rsiSlope < -0.5;

   double adx = ctx.GetADX(0);
   bool adxConfirmation = adx < 20;

   // === ATR Confirmation (adjusted for scalping) ===
   bool atrConfirmation = atrPips > 1.5;

   bool bull = candleTouchesBelowBB && adxConfirmation && atrConfirmation && rsiBullishSlope&&isEntryHour;
   bool bear = candleTouchesUpperBB && adxConfirmation && atrConfirmation && rsiBearishSlope&&isEntryHour;

   if (bull && IsNewBar(ctx.sd.symbol, Timeframe)) {
      double sl = GetRecentSwingLow(ctx.sd.symbol,Timeframe,5)-1*ctx.sd.point;
      //double sl = ctx.sd.bid - 2 * atr- ctx.sd.spread;
      double tp = ctx.sd.ask + 4 * atr+ ctx.sd.spread;
      //double tp = ctx.GetMiddleBB(0); 
      double lotSize = ctx.sd.dynamicLotSize("BUY", RiskPercent, sl);
      if (lotSize > 0) trade.Buy(lotSize, ctx.sd.symbol, ctx.sd.ask, sl, tp, "Scalp-Bull");
   }
   else if (bear && IsNewBar(ctx.sd.symbol, Timeframe)) {
      double sl = GetRecentSwingHigh(ctx.sd.symbol,Timeframe,5)+1*ctx.sd.point;
      //double sl = ctx.sd.ask + 2 * atr+ ctx.sd.spread;
      double tp = ctx.sd.bid - 4 * atr- ctx.sd.spread;
      //double tp = ctx.GetMiddleBB(0);
      double lotSize = ctx.sd.dynamicLotSize("SELL", RiskPercent, sl);
      if (lotSize > 0) trade.Sell(lotSize, ctx.sd.symbol, ctx.sd.bid, sl, tp, "Scalp-Bear");
   }
}

#endif // MA_CROSS_STRATEGY_MQH
