#include "Context.mqh"



bool GetRsiConformationSignal(SymbolContext *ctx){
     if((ctx.GetRSI(0) > 50)) return true;
     else return false;
}


bool IsVolumeSpike(SymbolContext *ctx, double multiplier = 1.2) {
   double avgVolume = (ctx.sd.volumes[2] + ctx.sd.volumes[3] + ctx.sd.volumes[4]) / 3.0;
   return (avgVolume > 0) && (ctx.sd.volumes[1] > multiplier * avgVolume);
}

// candle------------------------------------------------------------
bool IsBullishEngulfing(SymbolContext *ctx) {
   return (ctx.sd.priceData[2].close < ctx.sd.priceData[2].open &&               // Previous candle bearish
           ctx.sd.priceData[1].close > ctx.sd.priceData[1].open &&               // Current candle bullish
           ctx.sd.priceData[1].open < ctx.sd.priceData[2].close &&               // Current open below prev close
           ctx.sd.priceData[1].close > ctx.sd.priceData[2].open);                // Current close above prev open
}
bool IsBearishEngulfing(SymbolContext *ctx) {
   return (ctx.sd.priceData[2].close > ctx.sd.priceData[2].open &&               // Previous candle bullish
           ctx.sd.priceData[1].close < ctx.sd.priceData[1].open &&               // Current candle bearish
           ctx.sd.priceData[1].open > ctx.sd.priceData[2].close &&               // Current open above prev close
           ctx.sd.priceData[1].close < ctx.sd.priceData[2].open);                // Current close below prev open
}
string IsPinbar(SymbolContext *ctx,double wickRatio = 2.0) {
   double body = MathAbs(ctx.sd.priceData[1].close - ctx.sd.priceData[1].open);
   double upperWick = ctx.sd.priceData[1].high - MathMax(ctx.sd.priceData[1].close, ctx.sd.priceData[1].open);
   double lowerWick = MathMin(ctx.sd.priceData[1].close, ctx.sd.priceData[1].open) - ctx.sd.priceData[1].low;

   if (upperWick > wickRatio * body && lowerWick < 0.3 * body)
      return "BearishPinbar";  // Long upper wick
   else if (lowerWick > wickRatio * body && upperWick < 0.3 * body)
      return "BullishPinbar";  // Long lower wick
   return "";
}
string IsHammer(SymbolContext *ctx, double wickRatio = 2.0) {
   double body = MathAbs(ctx.sd.priceData[1].close - ctx.sd.priceData[1].open);
   double upperWick = ctx.sd.priceData[1].high - MathMax(ctx.sd.priceData[1].close, ctx.sd.priceData[1].open);
   double lowerWick = MathMin(ctx.sd.priceData[1].close, ctx.sd.priceData[1].open) - ctx.sd.priceData[1].low;

   // Classic Hammer: long lower wick, small body near top
   if (lowerWick > wickRatio * body && upperWick < 0.3 * body)
      return "Hammer";

   // Inverted Hammer: long upper wick, small body near bottom
   if (upperWick > wickRatio * body && lowerWick < 0.3 * body)
      return "InvertedHammer";

   return "";
}
string IsShootingStar(SymbolContext *ctx, double wickRatio = 2.0) {
   double body = MathAbs(ctx.sd.priceData[1].close - ctx.sd.priceData[1].open);
   double upperWick = ctx.sd.priceData[1].high - MathMax(ctx.sd.priceData[1].close, ctx.sd.priceData[1].open);
   double lowerWick = MathMin(ctx.sd.priceData[1].close, ctx.sd.priceData[1].open) - ctx.sd.priceData[1].low;

   // Shooting Star: long upper wick, small body near bottom of range
   if (upperWick > wickRatio * body && lowerWick < 0.3 * body)
      return "ShootingStar";

   return "";
}




//bool UpdateHybridTrailingSL(SymbolContext *ctx, int swingLookback = 7, double atrMultiplier = 1.2) {
//   if (!PositionSelect(ctx.sd.symbol)) return false;
//
//   ulong ticket = PositionGetTicket(0);
//   int type = (int)PositionGetInteger(POSITION_TYPE);
//   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
//   double slOld = PositionGetDouble(POSITION_SL);
//   double tp = PositionGetDouble(POSITION_TP);
//   double atr = ctx.GetATR(0);
//   ENUM_TIMEFRAMES tf = Timeframe;
//   double newSL = slOld;
//
//   if (atr <= 0.0) return false;
//   double price = (type == POSITION_TYPE_BUY) ? ctx.sd.bid : ctx.sd.ask;
//   // === 🔐 Forced close if price moves too far against us
//   bool lossTooBig = (type == POSITION_TYPE_BUY && price < entry - 5.0 * atr) ||
//                     (type == POSITION_TYPE_SELL && price > entry + 5.0 * atr);
//
//   if (lossTooBig) {
//      Print("🛑 Forced close ticket #", ticket, " on ", ctx.sd.symbol,
//            " | Entry=", entry, " Price=", price, " ATR=", atr);
//      if (!trade.PositionClose(ticket))
//         Print("❌ Close failed: ", trade.ResultRetcode());
//   }
//
//   double maTrail = ctx.GetSlowMA(0);
//   double swingTrail = (type == POSITION_TYPE_BUY) ? 
//                       GetRecentSwingLow(ctx.sd.symbol, tf, swingLookback) : 
//                       GetRecentSwingHigh(ctx.sd.symbol, tf, swingLookback);
//
//   double atrTrail = (type == POSITION_TYPE_BUY) ? 
//                     entry + atr * atrMultiplier : 
//                     entry - atr * atrMultiplier;
//
//   if (type == POSITION_TYPE_BUY)
//      newSL = MathMax(swingTrail, MathMax(atrTrail, maTrail));
//   else
//      newSL = MathMin(swingTrail, MathMin(atrTrail, maTrail));
//
//   bool slIsBetter = (type == POSITION_TYPE_BUY) ? (newSL > slOld) : (newSL < slOld);
//   if (slIsBetter && newSL > 0) {
//      if (trade.PositionModify(ctx.sd.symbol, newSL, tp)) {
//         Print("🔁 SL Trailed: ", ctx.sd.symbol, " → ", DoubleToString(newSL, _Digits));
//         return true;
//      } else {
//         Print("❌ Failed to modify SL: ", GetLastError());
//         return false;
//      }
//   }
//   return false;
//}

//void UpdateTrailingSL(SymbolContext *ctx) {
//   if (!PositionSelect(ctx.sd.symbol)) return;
//
//   ulong ticket = PositionGetTicket(0);
//   int type = (int)PositionGetInteger(POSITION_TYPE);
//   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
//   double slOld = PositionGetDouble(POSITION_SL);
//   double tp = PositionGetDouble(POSITION_TP);
//   
//   
//   double atr = ctx.GetATR(0);
//   if (atr <= 0.0) return; // 🔐 protect against bad data
//   double price = (type == POSITION_TYPE_BUY) ? ctx.sd.bid : ctx.sd.ask;
//   double gain = MathAbs(price - entry);
//   double spread = ctx.sd.spread;
//   double newSL = slOld;
//   double point = ctx.sd.point;
//   
////   // === Check if SL is missing or too tight
////   bool slInvalid = (slOld <= 0);
////   double slDistance = MathAbs(entry - slOld);
////   bool slTooTight = (slDistance < 3.0 * atr);
////
////   if (slInvalid || slTooTight) {
////      Print("🚨 SL invalid or too tight → Closing trade manually");
////      trade.PositionClose(ctx.sd.symbol);
////   }
//   
//   
//   if (gain > 1.5 * atr)
//   newSL = (type == POSITION_TYPE_BUY) ? entry + 0.3 * atr : entry - 0.3 * atr;
//
//   double trailRatio = 0.0;
//   if (gain > 2.0 * atr) trailRatio = 0.50;
//   if (gain > 3.0 * atr) trailRatio = 0.65;
//   if (gain > 4.0 * atr) trailRatio = 0.75;
//   
//   if (trailRatio > 0.0) {
//      double dynSL = (type == POSITION_TYPE_BUY) 
//                     ? entry + gain * trailRatio 
//                     : entry - gain * trailRatio;
//      newSL = (type == POSITION_TYPE_BUY) 
//              ? MathMax(newSL, dynSL) 
//              : MathMin(newSL, dynSL);
//   }
//
//   // === ✅ Apply Only If SL Improves ===
//   bool slIsBetter = (type == POSITION_TYPE_BUY) ? (newSL > slOld) : (newSL < slOld);
//   if (slIsBetter && newSL > 0 && tp==0&&trailRatio > 0.0) {
//      if (trade.PositionModify(ctx.sd.symbol, newSL, tp)) {
//         Print("🔁 SL Trailed: ", ctx.sd.symbol, " → ", DoubleToString(newSL, _Digits));
//      } else {
//         Print("❌ Failed to modify SL: ", GetLastError());
//      }
//   }
//}
