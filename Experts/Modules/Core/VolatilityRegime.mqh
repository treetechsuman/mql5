//+------------------------------------------------------------------+
//| VolatilityRegime.mqh                                             |
//| Module: Adapts SL/TP, LotSize, or Trade Filtering                |
//+------------------------------------------------------------------+
#ifndef __VOLATILITY_REGIME_MQH__
#define __VOLATILITY_REGIME_MQH__

// Enum for regimes
enum VolatilityRegime {
   RegimeLow,
   RegimeNormal,
   RegimeHigh
};

// Get volatility regime from ATR ratio
VolatilityRegime GetVolatilityRegime(double atr, double price) {
   double atrRatio = atr / price;

   if (atrRatio < 0.0004)
      return RegimeLow;
   else if (atrRatio > 0.0010)
      return RegimeHigh;
   else
      return RegimeNormal;
}

// Adapt SL/TP multipliers
void AdaptStopTP(VolatilityRegime regime, double &slMult, double &tpMult) {
   slMult = 1.5;
   tpMult = 2;

   if (regime == RegimeHigh) {
      slMult = 1;
      tpMult = 2.5;
   } else if (regime == RegimeLow) {
      slMult = 1.0;
      tpMult = 2.5;
   }
}

// Adapt lot size
void AdaptLotSize(VolatilityRegime regime, double &lotSize) {
   if (regime == RegimeHigh)
      lotSize *= 0.5;
   else if (regime == RegimeLow)
      lotSize *= 0.75;
}

// Optional filter: should we trade?
bool ShouldTrade(VolatilityRegime regime) {
   return regime != RegimeLow;  // Block during quiet ranges
}

// Print regime
string RegimeToString(VolatilityRegime regime) {
   switch(regime) {
      case RegimeLow: return "Low";
      case RegimeNormal: return "Normal";
      case RegimeHigh: return "High";
   }
   return "Unknown";
}

#endif
