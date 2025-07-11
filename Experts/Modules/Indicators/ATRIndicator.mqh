//+------------------------------------------------------------------+
//|                        ATRIndicator.mqh                          |
//|   Average True Range Indicator for modular EA                   |
//+------------------------------------------------------------------+
#ifndef ATR_INDICATOR_MQH
#define ATR_INDICATOR_MQH

#include "..\Core\Symbols.mqh"

class ATRIndicator {
private:
   int handle;
   double buffer[];
   int atrPeriod, lookback;
   ENUM_TIMEFRAMES tf;

public:
   ATRIndicator(int _period, int _lookback, ENUM_TIMEFRAMES _tf) {
      atrPeriod = _period;
      lookback = _lookback;
      tf = _tf;
   }

   bool Init(SymbolData *sd) {
      handle = iATR(sd.symbol, tf, atrPeriod);
      if (handle == INVALID_HANDLE) {
         Print("❌ ATR handle failed for ", sd.symbol);
         return false;
      }
      if (!ArrayResize(buffer, lookback)) {
         Print("❌ Failed to resize ATR buffer for ", sd.symbol);
         return false;
      }
      ArraySetAsSeries(buffer, true);
      return true;
   }

   void Load(SymbolData *sd) {
      ArraySetAsSeries(buffer, true);  // Just in case
      int copied = CopyBuffer(handle, 0, 0, lookback, buffer);
      if (copied != lookback) {
         PrintFormat("⚠️ Incomplete ATR data: copied=%d, expected=%d", copied, lookback);
      }
   }

   double GetATR(int index = 0) {
      if (index < 0 || index >= lookback) {
         Print("Invalid ATR index: ", index);
         return 0.0;
      }
      return buffer[index];
   }

   string Name() {
      return "ATR";
   }
};

#endif // ATR_INDICATOR_MQH
