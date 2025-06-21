// File: Modules/Strategies/MaCrossOver/Context.mqh
#ifndef CONTEXT_MQH
#define CONTEXT_MQH

#include <Arrays/ArrayObj.mqh>
#include "../../Core/Symbols.mqh"
#include "../../Indicators/MaIndicator.mqh"
#include "../../Indicators/RSIIndicator.mqh"
#include "Inputs.mqh"
// Indicator context structure
class SymbolContext : public CObject {
private:
   RSIIndicator *rsi;
   MaIndicator  *ma;

public:
   SymbolData *sd;

   SymbolContext(SymbolData *s, int rsiPeriod, int maPeriod, int volLookback, ENUM_TIMEFRAMES tf) {
      sd = s;
      rsi = new RSIIndicator(rsiPeriod, volLookback, tf);
      ma  = new MaIndicator(maPeriod, volLookback, tf);
      rsi.Init(sd);
      ma.Init(sd);
   }

   void LoadIndicators() {
      rsi.Load(sd);
      ma.Load(sd);
   }

   double GetRSI() { return rsi.GetRSI(); }
   double GetMA()  { return ma.GetMA(); }

   ~SymbolContext() {
      delete rsi;
      delete ma;
      delete sd;
   }
};

#endif
