//+------------------------------------------------------------------+
//|                       BollingerBandIndicator.mqh                |
//|   Bollinger Bands Indicator for modular EA                      |
//+------------------------------------------------------------------+
#ifndef BOLLINGER_BAND_INDICATOR_MQH
#define BOLLINGER_BAND_INDICATOR_MQH

#include "..\Core\Symbols.mqh"

class BollingerBandIndicator {
private:
   int handle;
   double upperBuffer[];
   double middleBuffer[];
   double lowerBuffer[];
   int bbPeriod, lookback;
   double deviation;
   ENUM_TIMEFRAMES tf;

public:
   BollingerBandIndicator(int _period, double _deviation, int _lookback, ENUM_TIMEFRAMES _tf) {
      bbPeriod = _period;
      deviation = _deviation;
      lookback = _lookback;
      tf = _tf;
   }

   bool Init(SymbolData *sd) {
      handle = iBands(sd.symbol, tf, bbPeriod, 0, deviation, PRICE_CLOSE);
      if (handle == INVALID_HANDLE) {
         Print("❌ BB handle failed for ", sd.symbol);
         return false;
      }

      ArrayResize(upperBuffer, lookback);
      ArrayResize(middleBuffer, lookback);
      ArrayResize(lowerBuffer, lookback);

      ArraySetAsSeries(upperBuffer, true);
      ArraySetAsSeries(middleBuffer, true);
      ArraySetAsSeries(lowerBuffer, true);

      return true;
   }

   void Load(SymbolData *sd) {
      ArraySetAsSeries(upperBuffer, true);
      ArraySetAsSeries(middleBuffer, true);
      ArraySetAsSeries(lowerBuffer, true);

      int copied1 = CopyBuffer(handle, 1, 0, lookback, upperBuffer);
      int copied2 = CopyBuffer(handle, 0, 0, lookback, middleBuffer);
      int copied3 = CopyBuffer(handle, 2, 0, lookback, lowerBuffer);

      if (copied1 != lookback || copied2 != lookback || copied3 != lookback) {
         PrintFormat("⚠️ Incomplete BB data: upper=%d, mid=%d, lower=%d, expected=%d", copied1, copied2, copied3, lookback);
      }
   }

   double GetUpper(int index = 0) {
      if (index < 0 || index >= lookback) return 0.0;
      return upperBuffer[index];
   }

   double GetMiddle(int index = 0) {
      if (index < 0 || index >= lookback) return 0.0;
      return middleBuffer[index];
   }

   double GetLower(int index = 0) {
      if (index < 0 || index >= lookback) return 0.0;
      return lowerBuffer[index];
   }

   string Name() {
      return "BollingerBands";
   }
};

#endif // BOLLINGER_BAND_INDICATOR_MQH
