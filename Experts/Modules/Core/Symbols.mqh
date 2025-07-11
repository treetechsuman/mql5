//+------------------------------------------------------------------+
//|                        Symbols.mqh                                |
//|   Core symbol structure, plugin-agnostic                         |
//+------------------------------------------------------------------+
#ifndef SYMBOLS_MQH
#define SYMBOLS_MQH

#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>


class SymbolData : public CObject {
public:
   string symbol;
   datetime lastTradeTime;
   MqlRates priceData[];
   long volumes[];
   double ask, bid, point, spread, balance;


   bool Init(string sym) {
      symbol = sym;
      ArraySetAsSeries(priceData, true);
      ArraySetAsSeries(volumes, true);
      lastTradeTime = 0;
      return true;
   }
   bool LoadVolume(ENUM_TIMEFRAMES tf, int count) {
      if (CopyTickVolume(symbol, tf, 0, count, volumes) <= 0) {
         Print("❌ Failed to load volume for ", symbol);
         return false;
      }
      return true;
   }
   void LoadMarketData(ENUM_TIMEFRAMES tf, int count) {
       CopyRates(symbol, tf, 0, count, priceData);
       CopyTickVolume(symbol, tf, 0, count, volumes);
       UpdateMarketInfo();
   }
   void UpdateMarketInfo() {
      ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
      balance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   double dynamicLotSize(string direction, double riskPercent, double sl) {
      double riskAmount = balance * (riskPercent / 100.0);
      double riskPoints = 20.0;
   
      if (sl <= 0) {
         Print("⚠️ Invalid SL, fallback risk points = 20");
      } else if (direction == "BUY") {
         riskPoints = MathMax((ask - sl) / point, 10.0);
      } else if (direction == "SELL") {
         riskPoints = MathMax((sl - bid) / point, 10.0);
      }
   
      if (riskPoints < 10) riskPoints = 10.0;  // safety floor
   
      double lotSize = riskAmount / riskPoints;
   
      // Normalize and cap based on broker limits
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
      lotSize = MathFloor(lotSize / lotStep) * lotStep;  // round down to valid step
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
      Print("🧮 RiskAmount=", riskAmount, " RiskPoints=", riskPoints, " Final LotSize=", lotSize);
      return lotSize;
   }

   bool IsNewCandle(ENUM_TIMEFRAMES tf) {
      datetime current = iTime(symbol, tf, 0);
      if (current != lastTradeTime) {
         lastTradeTime = current;
         return true;
      }
      return false;
   }

   double CalculateLotSizeByRisk(double riskPercent, double atrMultiplier, double atr, ENUM_TIMEFRAMES tf) {
      //double atr = iATR(symbol, tf, 14, 0);
      //if (atr <= 0) return 0.0;

      double slInPoints = atr * atrMultiplier / point;
      double riskAmount = balance * (riskPercent / 100.0);
      double rawLot = riskAmount / slInPoints;

      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      double finalLot = MathFloor(rawLot / lotStep) * lotStep;
      return MathMax(minLot, MathMin(maxLot, finalLot));
   }
};

#endif // SYMBOLS_MQH
