// File: Modules/Strategies/MaCrossOver/Context.mqh
#ifndef CONTEXT_MQH
#define CONTEXT_MQH

#include <Arrays/ArrayObj.mqh>
#include "../../Core/Symbols.mqh"
#include "../../Indicators/MaIndicator.mqh"
#include "../../Indicators/RSIIndicator.mqh"
#include "../../Indicators/ATRIndicator.mqh"
#include "../../Indicators/ADXIndicator.mqh"
#include "../../Indicators/BBIndicator.mqh"
#include "Inputs.mqh"
// Indicator context structure
class SymbolContext : public CObject {
private:
   RSIIndicator *rsi;
   ATRIndicator *atr;
   ADXIndicator *adx;
   BollingerBandIndicator  *exitLossBB;
   BollingerBandIndicator  *entryBB;
   BollingerBandIndicator  *takeProfitBB;

public:
   SymbolData *sd;

   SymbolContext(SymbolData *s, int rsiPeriod, int atrPeriod,int adxPeriod, int bbPeriod, int exitLossBBDeviation, int entryBBDeviation, int takeProfitBBDeviation, int volLookback, ENUM_TIMEFRAMES tf) {
      sd = s;
      rsi = new RSIIndicator(rsiPeriod, volLookback, tf);
      atr = new ATRIndicator(atrPeriod,volLookback,tf);
      adx = new ADXIndicator(adxPeriod,volLookback,tf);
      exitLossBB  = new BollingerBandIndicator(bbPeriod,exitLossBBDeviation, volLookback, tf);
      entryBB  = new BollingerBandIndicator(bbPeriod,entryBBDeviation, volLookback, tf);
      takeProfitBB  = new BollingerBandIndicator(bbPeriod,takeProfitBBDeviation, volLookback, tf);

      rsi.Init(sd);
      atr.Init(sd);
      adx.Init(sd);
      exitLossBB.Init(sd);
      entryBB.Init(sd);
      takeProfitBB.Init(sd);
   }

   void LoadIndicators() {
      rsi.Load(sd);
      atr.Load(sd);
      adx.Load(sd);
      exitLossBB.Load(sd);
      entryBB.Load(sd);
      takeProfitBB.Load(sd);
   }

   double GetRSI(int index=0) { return rsi.GetRSI(index); }
   double GetATR(int index=0) { return atr.GetATR(index); }
   double GetADX(int index=0) { return adx.GetADX(index); }
   double GetPlusDI(int index=0) { return adx.GetPlusDI(index); }
   double GetMinusDI(int index=0) { return adx.GetMinusDI(index); }
   double GetExitLossBBUpper(int index=0 )  { return exitLossBB.GetUpper(index); }
   double GetExitLossBBLower(int index=0 )  { return exitLossBB.GetLower(index); }
   double GetTakeProfitBBUpper(int index=0 )  { return takeProfitBB.GetUpper(index); }
   double GetTakeProfitBBLower(int index=0 )  { return takeProfitBB.GetLower(index); }
   double GetEntryBBUpper(int index=0 )  { return entryBB.GetUpper(index); }
   double GetEntryBBLower(int index=0 )  { return entryBB.GetLower(index); }
   double GetMiddleBB(int index=0 )  { return entryBB.GetMiddle(index); }

   ~SymbolContext() {
      delete rsi;
      delete atr;
      delete exitLossBB;
      delete adx;
      delete entryBB;
      delete takeProfitBB;
      delete sd;
   }
};

#endif
