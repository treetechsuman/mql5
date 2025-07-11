//+------------------------------------------------------------------+
//|                        MaIndicator.mqh                              |
//|   Single Moving Average Indicator for modular EA                   |
//+------------------------------------------------------------------+
#ifndef MA_INDICATOR_MQH
#define MA_INDICATOR_MQH

#include "..\Core\Symbols.mqh"

class MaIndicator  {
private:
   int handle;
   double buffer[];
   int maPeriod, lookback;
   ENUM_TIMEFRAMES tf;

public:
   MaIndicator(int _period, int _lookback, ENUM_TIMEFRAMES _tf) {
      maPeriod = _period;
      lookback = _lookback;
      tf = _tf;
   }

   bool Init(SymbolData *sd) {
      handle = iMA(sd.symbol, tf, maPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if (handle == INVALID_HANDLE) {
         Print("❌ MA handle failed for ", sd.symbol);
         return false;
      }
      //ArrayResize(buffer, lookback);
      ArraySetAsSeries(buffer, true);
      return true;
   }

   void Load(SymbolData *sd) {
      ArraySetAsSeries(buffer, true);  // Make sure buffer is series before copying
   
      int copied = CopyBuffer(handle, 0, 0, lookback, buffer);
      if (copied <= 0) {
         Print("⚠️ Failed to load MA buffer for ", sd.symbol, ", copied=", copied);
      }
   }


   string Name() {
      return "MA";
   }

   double GetMA(int index = 0) {
      if(index < 0 || index >= lookback) {
         Print("Invalid MA index: ", index);
         return 0.0;
      }
      return buffer[index]; // Access pre-loaded buffer
   }
};

#endif // MA_Indicator_MQH
