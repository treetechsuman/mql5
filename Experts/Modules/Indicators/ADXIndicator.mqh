//+------------------------------------------------------------------+
//|                      ADXIndicator.mqh                            |
//|   ADX with ADX, +DI, -DI support                                 |
//+------------------------------------------------------------------+
#ifndef ADX_INDICATOR_MQH
#define ADX_INDICATOR_MQH

#include "..\Core\Symbols.mqh"

class ADXIndicator {
private:
   int adxHandle;
   double adxBuffer[];
   double plusDIBuffer[];
   double minusDIBuffer[];
   int period, lookback;
   ENUM_TIMEFRAMES tf;

public:
   ADXIndicator(int _period, int _lookback, ENUM_TIMEFRAMES _tf) {
      period = _period;
      lookback = _lookback;
      tf = _tf;
   }

   bool Init(SymbolData *sd) {
      adxHandle = iADX(sd.symbol, tf, period);
      if (adxHandle == INVALID_HANDLE) {
         Print("❌ ADX handle failed for ", sd.symbol);
         return false;
      }
      ArraySetAsSeries(adxBuffer, true);
      ArraySetAsSeries(plusDIBuffer, true);
      ArraySetAsSeries(minusDIBuffer, true);
      return true;
   }

   void Load(SymbolData *sd) {
      if (CopyBuffer(adxHandle, 0, 0, lookback, adxBuffer) <= 0 ||
          CopyBuffer(adxHandle, 1, 0, lookback, plusDIBuffer) <= 0 ||
          CopyBuffer(adxHandle, 2, 0, lookback, minusDIBuffer) <= 0) {
         Print("⚠️ Failed to load ADX/+DI/-DI for ", sd.symbol);
      }
   }

   double GetADX(int index = 0) {
      if(index < 0 || index >= lookback) return 0.0;
      return adxBuffer[index];
   }

   double GetPlusDI(int index = 0) {
      if(index < 0 || index >= lookback) return 0.0;
      return plusDIBuffer[index];
   }

   double GetMinusDI(int index = 0) {
      if(index < 0 || index >= lookback) return 0.0;
      return minusDIBuffer[index];
   }
};

#endif // ADX_INDICATOR_MQH
