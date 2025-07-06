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
   ADXIndicator *adx1H;
   MaIndicator  *ma15M;
   MaIndicator  *ma15MSlow;
   MaIndicator  *ma1H;

public:
   SymbolData *sd;

   SymbolContext(SymbolData *s, int rsiPeriod, int atrPeriod,int adxPeriod, int ma15MPeriod, int ma1HPeriod, int volLookback, ENUM_TIMEFRAMES tf) {
      sd = s;
      rsi = new RSIIndicator(rsiPeriod, volLookback, tf);
      ma15M  = new MaIndicator(ma15MPeriod, volLookback, tf);
      ma15MSlow  = new MaIndicator(50, volLookback, tf);
      ma1H  = new MaIndicator(ma1HPeriod, volLookback, PERIOD_H1);
      atr = new ATRIndicator(atrPeriod,volLookback,tf);
      adx = new ADXIndicator(adxPeriod,volLookback,tf);
      adx1H = new ADXIndicator(adxPeriod,volLookback,PERIOD_H1);
      rsi.Init(sd);
      atr.Init(sd);
      adx.Init(sd);
      ma15M.Init(sd);
      ma15MSlow.Init(sd);
      ma1H.Init(sd);
      adx1H.Init(sd);
   }

   void LoadIndicators() {
      rsi.Load(sd);
      atr.Load(sd);
      adx.Load(sd);
      ma15M.Load(sd);
      ma15MSlow.Load(sd);
      ma1H.Load(sd);
      adx1H.Load(sd);
   }

   double GetRSI(int index=0) { return rsi.GetRSI(index); }
   double GetATR(int index=0) { return atr.GetATR(index); }
   double GetADX(int index=0) { return adx.GetADX(index); }
   double Get15MMA(int index=0 )  { return ma15M.GetMA(index); }
   double Get15MMASlow(int index=0 )  { return ma15MSlow.GetMA(index); }
   double Get1HMA(int index=0 )  { return ma1H.GetMA(index); }
   double Get1HADX(int index=0 )  { return adx1H.GetADX(index); }

   ~SymbolContext() {
      delete rsi;
      delete atr;
      delete ma15M;
      delete ma15MSlow;
      delete adx;
      delete ma1H;
      delete sd;
   }
};

#endif
