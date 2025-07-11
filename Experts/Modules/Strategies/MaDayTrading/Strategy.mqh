//+------------------------------------------------------------------+
//|                    MaCrossStrategy.mqh                          |
//|   Strategy logic for MA Crossover                              |
//+------------------------------------------------------------------+
#ifndef MA_CROSS_STRATEGY_MQH
#define MA_CROSS_STRATEGY_MQH

#include "Context.mqh"
#include "../../Core/Utils.mqh"
#include "../../Core/Core.mqh"
#include "../../Core/VolatilityRegime.mqh"
#include "Functions.mqh"
#include <Trade/Trade.mqh>

CTrade trade;
int TimeHour(datetime t) {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
}
// === Track H1 Trend Changes ===
static bool lastH1BullTrend = false;
static bool lastH1BearTrend = false;
static bool isNewH1Trend = false;           // Persist between ticks
static bool firstPullbackTriggered = false; // Persist between ticks
static datetime trendFlipTime = 0;

void MaDayTradingStrategy(SymbolContext *ctx) {
    

    double ema1HNow = ctx.Get1HMA(0);
    double ema1H3 = ctx.Get1HMA(3);
    // === 1️⃣ Calculate rise/run ===
   double rise1H = (ema1HNow - ema1H3)/ ctx.sd.point; // Difference in points; ;              // EMA value difference
   double run1H  = 3;                  // 6 candles (time step)
   
   // === 2️⃣ Calculate slope angle in degrees ===
   double slopeAngle1H = MathArctan(rise1H / run1H) * 180.0 / M_PI; // Convert to degrees

    bool emaSlopingUp = (slopeAngle1H > 50.0);  // Slope steeper than +25°
    bool emaSlopingDown = (slopeAngle1H < -50.0); // Slope steeper than -25°
    
    double ema15MNow = ctx.Get15MMA(0); // EMA at current bar
   double ema15M3   = ctx.Get15MMA(3); // EMA 3 bars ago
   
   // === 1️⃣ Calculate rise/run ===
   double rise = (ema15MNow - ema15M3)/ ctx.sd.point; // Difference in points;              // EMA value difference
   double run  = 3;                  // 3 candles (time step)
   
   // === 2️⃣ Calculate slope angle in degrees ===
   double slopeAngle15M = MathArctan(rise / run) * 180.0 / M_PI; // Convert to degrees
   
   
  // === 3️⃣ Define "nice slope" (only angles steeper than 25°)
   bool ema15MSlopingUp   = (slopeAngle15M > 60.0);  // Slope steeper than +25°
   bool ema15MSlopingDown = (slopeAngle15M < -60.0); // Slope steeper than -25°
   double ema15MNowSlow = ctx.Get15MMASlow(0);
   // === 1️⃣ Trend Filter (H1 EMA + Slope) ===
    double priceClose = ctx.sd.priceData[1].close;
    bool isBullTrend = emaSlopingUp&&(ema15MNow>ema15MNowSlow)&&priceClose>ctx.Get1HMA(0);
    bool isBearTrend = emaSlopingDown&&(ema15MNow<ema15MNowSlow)&&priceClose<ctx.Get1HMA(0);

    // === 2️⃣ RSI Filter (M15) ===
    bool rsiBullish = (ctx.GetRSI(1) > 50);
    bool rsiBearish = (ctx.GetRSI(1) < 50);

    // === 3️⃣ ATR Volatility Filter (M15) ===
    double atrNow = ctx.GetATR(0);
    double atrPips = atrNow / ctx.sd.point / 10.0;
    bool atrConfirmation = (atrPips > 5.0); // Minimum volatility required

    // === 4️⃣ ADX Filter (H1) ===
    double adx = ctx.Get1HADX(1);
    bool adxConfirmation = (adx > 20); // Only trade when trending

    // === 5️⃣ Session Time Filter ===
    int hour = TimeHour(TimeCurrent());
    bool isLondonSession = (hour >= 8 && hour < 12);  // London 08:00–12:00
    bool isNYSession = (hour >= 13 && hour < 17);     // NY 13:00–17:00
    bool isEntryHour = isLondonSession || isNYSession;



    // === 7️⃣ Spread Filter ===
    bool isSpreadOK = ctx.sd.spread < (2 * ctx.sd.point * 10); // Avoid high spread

    // === 8️⃣ Pullback Detection (M15) ===
    bool pullbackBullish = IsBullishPullbackToEMA(ctx); // Price pulled to 20 EMA
    bool pullbackBearish = IsBearishPullbackToEMA(ctx);
    
    bool cleanPullBackBulish = IsCleanBullishPullbackToEMA(ctx);
    bool cleanPullBackBearish = IsCleanBearishPullbackToEMA(ctx);
    
   
   if (isBullTrend && !lastH1BullTrend) {
       isNewH1Trend = true;             // New bullish trend detected
       firstPullbackTriggered = false;  // Reset pullback trigger
       trendFlipTime = TimeCurrent();
   }
   if (isBearTrend && !lastH1BearTrend) {
       isNewH1Trend = true;             // New bearish trend detected
       firstPullbackTriggered = false;  // Reset pullback trigger
       trendFlipTime = TimeCurrent();
   }

   // Update trend state
   lastH1BullTrend = isBullTrend;
   lastH1BearTrend = isBearTrend;

   // 2️⃣ Block if pullback is too late (max 6 M15 candles)
 
    int barsSinceFlip = (TimeCurrent() - trendFlipTime) / PeriodSeconds(PERIOD_M15);
    bool isPullBackInTime = (barsSinceFlip>3 && barsSinceFlip < 10);
    if(ema15MSlopingUp){
      trendFlipTime = TimeCurrent();
      //firstPullbackTriggered = false;
    }
    if(ema15MSlopingDown){
      trendFlipTime = TimeCurrent();
      //firstPullbackTriggered = false;
    }
    
    bool bullishPrice = ctx.sd.ask>ctx.Get15MMA(0);
    bool bearishPrice = ctx.sd.bid<ctx.Get15MMA(0);
    // === 9️⃣ Entry Triggers (M15) ===
    bool bullishTrigger = 
        isBullTrend&&
        //emaSlopingUp &&
        ema15MSlopingUp&&
        rsiBullish &&
        //pullbackBullish &&
        //cleanPullBackBulish;//&& 
        //isPullBackInTime&&
        //bullishPrice&&
        adxConfirmation && 
        atrConfirmation&&
        isEntryHour&&
        IsBullishEngulfing(ctx)&&
        isSpreadOK;

    bool bearishTrigger = 
        isBearTrend&&
        //emaSlopingDown &&
        ema15MSlopingDown&&
        rsiBearish &&
        //pullbackBearish &&
        //cleanPullBackBearish;//&&
        //isPullBackInTime&&
        //bearishPrice&&
        adxConfirmation &&
        atrConfirmation&&
        isEntryHour&&
        IsBearishEngulfing(ctx)&&
        isSpreadOK;

    // === 🔔 Dashboard Display ===
    //{"EntryHour","H1 Trend","EmaSlop","Rsi","Info","Engulfing"};
    SignalStatus s1;
    AddSignalValue(s1, "| " + hour + " " + BoolToString(isEntryHour));
    AddSignalValue(s1, "| " + IsSignalBuy(isBullTrend)+IsSignalSell(isBearTrend));
    AddSignalValue(s1, "| " + DoubleToString(slopeAngle1H,1) + " | " + DoubleToString(slopeAngle15M,1) + IsSignalBuy(ema15MSlopingUp)+IsSignalSell(ema15MSlopingDown));
    AddSignalValue(s1, "| " + DoubleToString(ctx.GetRSI(1),1)  + IsSignalBuy(rsiBullish)+IsSignalSell(rsiBearish));
    AddSignalValue(s1, "|ADX" + DoubleToString(adx, 1)+"| ATR"+ DoubleToString(atrPips, 1));
    AddSignalValue(s1, "| " + IsSignalBuy(IsBullishEngulfing(ctx))+IsSignalSell(IsBearishEngulfing(ctx)));
    UpdateDashboard(ctx.sd.symbol, s1);
    //AddSignalValue(s1, "|" + barsSinceFlip + BoolToString(isPullBackInTime));
    // === 🔥 Entry Logic ===
    if (
          bullishTrigger &&
          //!firstPullbackTriggered&&
          !IsLongPositionOpen(ctx.sd.symbol)
          ) {
        //double sl = GetRecentSwingLow(ctx.sd.symbol, PERIOD_M15, 10);
        //double sl = ctx.sd.ask - 1.5 * atrNow;
        double sl = ctx.Get15MMASlow(0) - 2 * atrNow;
        double tp = ctx.sd.ask + 4 * atrNow; // RRR = 1:1.5
        double lots = ctx.sd.CalculateLotSizeByRisk(RiskPercent, 2, atrNow, PERIOD_M15);
        trade.Buy(lots, ctx.sd.symbol, ctx.sd.ask, sl, tp, "MA-Bull");
        firstPullbackTriggered = true;  // ✅ Mark pullback as used
        Print("EMA Slope Angle: ", slopeAngle15M);
        
    }

    if (
         bearishTrigger &&
         //!firstPullbackTriggered&& 
         !IsShortPositionOpen(ctx.sd.symbol)
         ) {
        //double sl = GetRecentSwingHigh(ctx.sd.symbol, PERIOD_M15, 10);
        //double sl = ctx.sd.ask + 1.5 * atrNow;
        double sl = ctx.Get15MMASlow(0) + 2 * atrNow;
        double tp = ctx.sd.bid - 4 * atrNow; // RRR = 1:1.5
        double lots = ctx.sd.CalculateLotSizeByRisk(RiskPercent, 2, atrNow, PERIOD_M15);
        trade.Sell(lots, ctx.sd.symbol, ctx.sd.bid, sl, tp, "MA-Bear");
        firstPullbackTriggered = true;  // ✅ Mark pullback as used
        Print("EMA Slope Angle: ", slopeAngle15M);
        
    }
}

bool IsBullishPullbackToEMA(SymbolContext *ctx) {
    // Get EMA value
    double ema = ctx.Get15MMA(1); // EMA(20) at previous candle
   
    // Get candle high/low
    double candleHigh = ctx.sd.priceData[1].high;
    double candleLow = ctx.sd.priceData[1].low;

    // Check if EMA is within candle range (price touched EMA)
    if (
    ema >= candleLow &&
    ema <= candleHigh&&
    ctx.sd.priceData[2].low>ctx.sd.priceData[1].low&&
    ctx.sd.priceData[2].low>ctx.Get15MMA(2)
    ) {
        return true;
    }

    return false;
}
bool IsBearishPullbackToEMA(SymbolContext *ctx) {
    // Get EMA value
    double ema = ctx.Get15MMA(1); // EMA(20) at previous candle
   
    // Get candle high/low
    double candleHigh = ctx.sd.priceData[1].high;
    double candleLow = ctx.sd.priceData[1].low;

    // Check if EMA is within candle range (price touched EMA)
    if (
    ema >= candleLow &&
    ema <= candleHigh&&
    ctx.sd.priceData[2].high<ctx.sd.priceData[1].high&&
    ctx.sd.priceData[2].high<ctx.Get15MMA(2)
    ) {
        return true;
    }

    return false;
}

bool IsCleanBullishPullbackToEMA(SymbolContext *ctx) {
    // Get EMA value (M15)
    double ema = ctx.Get15MMA(1); // EMA(20) at previous candle
   
    // Get candle high/low
    double candleHigh = ctx.sd.priceData[1].high;
    double candleLow = ctx.sd.priceData[1].low;

    // === Clean pullback check ===
    if (
        ema >= candleLow &&                    // EMA touched
        ema <= candleHigh //&&
        //ctx.sd.priceData[3].low > ctx.sd.priceData[2].low &&
        //ctx.sd.priceData[2].low > ctx.sd.priceData[1].low && // Prior low > current low (no deep dip)
        //ctx.sd.priceData[2].low > ctx.Get15MMA(2)        // Prior candle above EMA
        
    ) {
        return true;
    }

    return false;
}

bool IsCleanBearishPullbackToEMA(SymbolContext *ctx) {
    // Get EMA value (M15)
    double ema = ctx.Get15MMA(1); // EMA(20) at previous candle
   
    // Get candle high/low
    double candleHigh = ctx.sd.priceData[1].high;
    double candleLow = ctx.sd.priceData[1].low;

    // === Clean pullback check ===
    if (
        ema >= candleLow &&                     // EMA touched
        ema <= candleHigh //&&
        //ctx.sd.priceData[3].high < ctx.sd.priceData[2].high &&
        //ctx.sd.priceData[2].high < ctx.sd.priceData[1].high && // Prior high < current high (no deep spike)
        //ctx.sd.priceData[2].high < ctx.Get15MMA(2)        // Prior candle below EMA
        
    ) {
        return true;
    }

    return false;
}


void AddSignalValue(SignalStatus &s, string value) {
   int size = ArraySize(s.values);
   ArrayResize(s.values, size + 1);
   s.values[size] = value;
}
string IsSignalBuy(bool signal){
   if(signal)return "BUY";
   else return "";
}
string IsSignalSell(bool signal){
   if(signal)return "SELL";
   else return "";
}



void ClosePositionsOnMACross(SymbolContext *ctx) {
   if (!PositionSelect(ctx.sd.symbol)) return;
    double ma15M = ctx.Get15MMA(0);
    double maSlow15M = ctx.Get15MMASlow(0);

    // Check for open positions
    if (PositionSelect(ctx.sd.symbol)) {
        int type = (int)PositionGetInteger(POSITION_TYPE);

        if (type == POSITION_TYPE_BUY && ma15M < maSlow15M) {
            // Close BUY if fast MA drops below slow MA
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            trade.PositionClose(ticket);
        }

        if (type == POSITION_TYPE_SELL && ma15M > maSlow15M) {
            // Close SELL if fast MA crosses above slow MA
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            trade.PositionClose(ticket);
        }
    }
}





//+------------------------------------------------------------------+
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
   double spread = ctx.sd.spread;
   double point = ctx.sd.point;
   double newSL = slOld;

   // === 🔐 Forced close if price moves too far against us
   bool lossTooBig = (type == POSITION_TYPE_BUY && price < entry - 5.0 * atr) ||
                     (type == POSITION_TYPE_SELL && price > entry + 5.0 * atr);

   if (lossTooBig) {
      Print("🛑 Forced close ticket #", ticket, " on ", ctx.sd.symbol,
            " | Entry=", entry, " Price=", price, " ATR=", atr);
      if (!trade.PositionClose(ticket))
         Print("❌ Close failed: ", trade.ResultRetcode());
   }

   //// === Breakeven logic
   if (gain > 2 * atr)
      newSL = (type == POSITION_TYPE_BUY) ? entry + 0.3 * atr : entry - 0.3 * atr;

   if (gain > 2.5 * atr) {
      // === 📉 MA-based Trailing SL (2 pips buffer from slow MA)
      double slowMA = ctx.Get15MMASlow(0);  // Assuming this gives slow MA on current candle
      //double swingLow = GetRecentSwingLow(ctx.sd.symbol, Timeframe, 4);
      //double swingHign = GetRecentSwingHigh(ctx.sd.symbol, Timeframe, 4);
      double pip = 10 * point;       // 1 pip = 10 points on most brokers
      double maTrailSL = (type == POSITION_TYPE_BUY)
                         ? ctx.sd.ask - 2 * atr
                         : ctx.sd.bid + 2 * atr;
      
      // Pick the better SL: tighter of MA trail or existing newSL
      newSL = (type == POSITION_TYPE_BUY)
              ? MathMax(newSL, maTrailSL)
              : MathMin(newSL, maTrailSL);
              
      //newSL = (type == POSITION_TYPE_BUY)? swingLow: swingHign;
   }

   

   // === ✅ Apply Only If SL Improves ===
   bool slIsBetter = (type == POSITION_TYPE_BUY) ? (newSL > slOld) : (newSL < slOld);
   if (slIsBetter && newSL > 0 && tp == 0) {
      if (trade.PositionModify(ctx.sd.symbol, newSL, tp)) {
         Print("🔁 SL Trailed: ", ctx.sd.symbol, " → ", DoubleToString(newSL, _Digits));
      } else {
         Print("❌ Failed to modify SL: ", GetLastError());
      }
   }
   if (tp != 0 && gain > 1.5 * atr && slOld!= entry) {
      //double updateStoploss= (type == POSITION_TYPE_BUY) ? entry + 0.3 * atr : entry - 0.3 * atr;
      if (trade.PositionModify(ctx.sd.symbol, entry, tp)) {
         Print("🔁 SL Trailed: ", ctx.sd.symbol, " → ", DoubleToString(newSL, _Digits));
      } else {
         Print("❌ Failed to modify SL: ", GetLastError());
      }
   }
   
}
#endif // MA_CROSS_STRATEGY_MQH
