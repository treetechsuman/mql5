// File: Modules/Strategies/MaCrossOver/Context.mqh
#ifndef CONTEXT_MQH
#define CONTEXT_MQH

#include <Arrays/ArrayObj.mqh>
#include "../../Core/Symbols.mqh"
#include "../../Indicators/MaIndicator.mqh"
#include "../../Indicators/RSIIndicator.mqh"
#include "../../Indicators/ATRIndicator.mqh"
#include "../../Indicators/ADXIndicator.mqh"
#include "Inputs.mqh"
// Indicator context structure
class SymbolContext : public CObject {
private:
   RSIIndicator *rsi;
   ATRIndicator *atr;
   ADXIndicator *adx;
   MaIndicator  *ma;
   MaIndicator  *maSlow;

public:
   SymbolData *sd;

   SymbolContext(SymbolData *s, int rsiPeriod, int atrPeriod,int adxPeriod, int maPeriod, int volLookback, ENUM_TIMEFRAMES tf) {
      sd = s;
      rsi = new RSIIndicator(rsiPeriod, volLookback, tf);
      ma  = new MaIndicator(maPeriod, volLookback, tf);
      maSlow  = new MaIndicator(maPeriod+15, volLookback, tf);
      atr = new ATRIndicator(atrPeriod,volLookback,tf);
      adx = new ADXIndicator(adxPeriod,volLookback,tf);
      rsi.Init(sd);
      atr.Init(sd);
      adx.Init(sd);
      ma.Init(sd);
      maSlow.Init(sd);
   }

   void LoadIndicators() {
      rsi.Load(sd);
      atr.Load(sd);
      adx.Load(sd);
      ma.Load(sd);
      maSlow.Load(sd);
   }

   double GetRSI(int index=0) { return rsi.GetRSI(); }
   double GetATR(int index=0) { return atr.GetATR(); }
   double GetADX(int index=0) { return adx.GetADX(); }
   double GetMA(int index=0 )  { return ma.GetMA(); }
   double GetSlowMA(int index=0 )  { return maSlow.GetMA(); }

   ~SymbolContext() {
      delete rsi;
      delete atr;
      delete ma;
      delete maSlow;
      delete sd;
   }
};

#endif
