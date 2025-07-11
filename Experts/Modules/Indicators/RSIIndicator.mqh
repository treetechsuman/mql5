//+------------------------------------------------------------------+
#ifndef RSI_INDICATOR_MQH
#define RSI_INDICATOR_MQH

#include "..\Core\Symbols.mqh"

class RSIIndicator {
private:
   int handle;
   double buffer[];
   int rsiPeriod, lookback;
   ENUM_TIMEFRAMES tf;

public:
   RSIIndicator(int _period, int _lookback, ENUM_TIMEFRAMES _tf) {
      rsiPeriod = _period;
      lookback = _lookback;
      tf = _tf;
   }

   bool Init(SymbolData *sd) {
      handle = iRSI(sd.symbol, tf, rsiPeriod, PRICE_CLOSE);
      if (handle == INVALID_HANDLE) {
         Print("❌ RSI handle failed for ", sd.symbol);
         return false;
      }
      // FIX: Properly resize buffer before setting as series
      ArrayResize(buffer, lookback); // UNCOMMENTED CRITICAL LINE
      ArraySetAsSeries(buffer, true);
      return true;
   }

   void Load(SymbolData *sd) {
      // Ensure we request only available data
      int copied = CopyBuffer(handle, 0, 0, lookback, buffer);
      if (copied <= 0) {
         Print("⚠️ Failed to load RSI for ", sd.symbol, " Copied: ", copied);
      }
   }

   string Name() {
      return "RSI";
   }

   double GetRSI(int index = 0) {
      if(index < 0 || index >= lookback) {
         Print("Invalid RSI index: ", index, " (Valid 0-", lookback-1, ")");
         return 0.0;
      }
      return buffer[index];
   }
};

#endif // RSI_INDICATOR_MQH