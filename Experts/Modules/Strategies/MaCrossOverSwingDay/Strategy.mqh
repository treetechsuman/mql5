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


void MaCrossOverDayStrategy(SymbolContext *ctx) {
    // === 2. RSI Filter ===
    bool rsiBullish = (ctx.GetRSI(1) > 50);// && (ctx.GetRSI(1) > ctx.GetRSI(2));
    bool rsiBearish = (ctx.GetRSI(1) < 50); //&& (ctx.GetRSI(1) < ctx.GetRSI(2));

    // === 3. ATR Filter ===
    double atrNow = ctx.GetATR(0);
    double atrPips = atrNow / ctx.sd.point / 10.0;
    bool atrConfirmation = atrPips > 5.0;

    // === 4. ADX Filter ===
    double adx = ctx.GetADX(1);
    bool adxConfirmation = (adx > 20);  // Filter weak trends
    //bool adxConfirmation = (adx > 20 && adx < 60);  // Prevent chasing exhausted trends

    // === 6. Time Filter ===
    int hour = TimeHour(TimeCurrent());
    //bool isEntryHour = (hour >= 10 && hour < 18);
    bool isEntryHour = (hour >= 9 && hour <= 12) || (hour >= 15 && hour <= 18);

    // === 7. Candle Strength Filter ===
    double body = MathAbs(ctx.sd.priceData[1].close - ctx.sd.priceData[1].open);
    double candleRange = ctx.sd.priceData[1].high - ctx.sd.priceData[1].low;
    bool isStrongCandle = (candleRange > 0 && body / candleRange > 0.6);

    // === 8. Spread Control ===
    bool isSpreadOK = ctx.sd.spread < (3 * ctx.sd.point * 10);

    // === 9. Volume Spike (optional) ===
    bool isVolumeSpike = IsVolumeSpike(ctx,1.2);
    //bool isVolumeSpike = ctx.sd.volumes[1] > ctx.sd.volumes[2] * 1.2;
    
    
    //Display information in chart
    double atr = ctx.GetATR(0);  // Your method to get ATR
      double price = ctx.sd.bid;  // or mid-price
    //VolatilityRegime regime = GetVolatilityRegime(atr, price);
    MACrossType cross = DidMACrossoverHappen(ctx, 3);
    
    bool bull = (cross==BULLISH) &&
        //(IsHammer(ctx)=="Hammer")&&
        //rsiBullish &&
        //adxConfirmation &&
        isEntryHour &&
        (IsBullishEngulfing(ctx)||(IsPinbar(ctx)=="BullishPinbar")||(IsHammer(ctx)=="Hammer"))&&
        //!IsLongPositionOpen(ctx.sd.symbol)&&
        isVolumeSpike&&
        //(regime=="High")&&
        isSpreadOK;
        
    bool bear = (cross==BEARISH) &&
        //(IsShootingStar(ctx)=="ShootingStar")&&
        //rsiBearish &&
        //adxConfirmation &&
        isEntryHour &&
        (IsBearishEngulfing(ctx)||(IsPinbar(ctx)=="BearishPinbar")||(IsShootingStar(ctx)=="ShootingStar"))&&
        //!IsShortPositionOpen(ctx.sd.symbol)&&
        isVolumeSpike&&
        //(regime=="High")&&
        isSpreadOK;
    
      //string Rows[] = {"Candle","Volume","CrossOver"};
      
      SignalStatus s1;
      //AddSignalValue(s1,ctx.sd.symbol);
      //AddSignalValue(s1,RegimeToString(regime));
      //AddSignalValue(s1,DoubleToString(NormalizeDouble(ctx.GetRSI(0),2),1)+"  "+IsSignalBuy(rsiBullish)+IsSignalSELL(rsiBearish));
      //AddSignalValue(s1,BoolToString(isStrongCandle)+"  "+IsSignalBuy(bullishCandleCrossover)+IsSignalSELL(bearishCandleCrossover));
      //AddSignalValue(s1,DoubleToString(NormalizeDouble(atrPips,2),1) +" > 5 "+BoolToString(atrConfirmation));
      //AddSignalValue(s1,DoubleToString(NormalizeDouble(adx,2),1) +" > 20 "+BoolToString(adxConfirmation)); 
      //AddSignalValue(s1, "8 < " + hour +" < 17 "+BoolToString(isEntryHour));
      AddSignalValue(s1,"|" +IsSignalBuy((IsBullishEngulfing(ctx)||(IsPinbar(ctx)=="BullishPinbar")||(IsHammer(ctx)=="Hammer")))+IsSignalSELL((IsBearishEngulfing(ctx)||(IsPinbar(ctx)=="BearishPinbar")||(IsShootingStar(ctx)=="ShootingStar"))));
      AddSignalValue(s1, BoolToString(isVolumeSpike));
      AddSignalValue(s1, MACrossTypeToString(cross));  
        
      UpdateDashboard(ctx.sd.symbol, s1);
    
    // === ✅ LONG ENTRY ===
    if (bull) {
        if(atrNow<0)atrNow=1;
        double sl = ctx.sd.ask - 2 * atrNow;
        sl = GetRecentSwingLow(ctx.sd.symbol,Timeframe,7);
        double tp = ctx.sd.ask + 3 * atrNow;
        //double lots = ctx.sd.dynamicLotSize("BUY", RiskPercent, sl);
        double lots = ctx.sd.CalculateLotSizeByRisk(RiskPercent,2,atrNow,Timeframe);
        //lots = AdjustLotByADX(adx,lots);
        //if(lots>0){
            trade.Buy(lots, ctx.sd.symbol, ctx.sd.ask, sl, 0, "MA-Bull-SC");
            trade.Buy(lots, ctx.sd.symbol, ctx.sd.ask, sl, tp, "MA-Bull-SC");
        //}
    }

    // === ✅ SHORT ENTRY ===
    if (bear) {
        if(atrNow<0)atrNow=1;
        double sl = ctx.sd.bid + 2 * atrNow;
        sl = GetRecentSwingHigh(ctx.sd.symbol,Timeframe,7);
        double tp = ctx.sd.bid - 3 * atrNow;
        //double lots = ctx.sd.dynamicLotSize("SELL", RiskPercent, sl);
        double lots = ctx.sd.CalculateLotSizeByRisk(RiskPercent,2,atrNow,Timeframe);
        //lots = AdjustLotByADX(adx,lots);
        //if(lots>0){
            trade.Sell(lots, ctx.sd.symbol, ctx.sd.bid, sl, 0, "MA-Bear-SC");
            trade.Sell(lots, ctx.sd.symbol, ctx.sd.bid, sl, tp, "MA-Bear-SC");
        //}
    }
    
    
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
string IsSignalSELL(bool signal){
   if(signal)return "SELL";
   else return "";
}
// Calculates the slope (in pips per bar) of the Fast MA over N bars
bool SlopeBasedMAFilter(SymbolContext *ctx, int maPeriod = 20, int slopeLookback = 5, double minSlopePips = 3.0) {
    double slope = 0;
    double priceDiff = ctx.GetFastMA(0) - ctx.GetFastMA(slopeLookback);
    double pips = priceDiff / ctx.sd.point;  // Convert to pips
    slope = MathAbs(pips / slopeLookback);   // Normalize slope per candle

    PrintFormat("📐 Slope: %.2f pips/bar (MinRequired: %.2f)", slope, minSlopePips);
    return slope >= minSlopePips;
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

   // === Breakeven logic
   if (gain > 2 * atr)
      newSL = (type == POSITION_TYPE_BUY) ? entry + 0.3 * atr : entry - 0.3 * atr;

   if (gain > 2.5 * atr) {
      // === 📉 MA-based Trailing SL (2 pips buffer from slow MA)
      double slowMA = ctx.GetSlowMA(0);  // Assuming this gives slow MA on current candle
      //double swingLow = GetRecentSwingLow(ctx.sd.symbol, Timeframe, 4);
      //double swingHign = GetRecentSwingHigh(ctx.sd.symbol, Timeframe, 4);
      double pip = 10 * point;       // 1 pip = 10 points on most brokers
      double maTrailSL = (type == POSITION_TYPE_BUY)
                         ? slowMA - 3 * pip
                         : slowMA + 3 * pip;
      
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
      
      if (StringFind(comment, "MA") != -1) {
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
