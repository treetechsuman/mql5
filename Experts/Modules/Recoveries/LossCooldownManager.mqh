//+------------------------------------------------------------------+
//|                      LossCooldownManager.mqh                     |
//+------------------------------------------------------------------+
#include <Arrays\ArrayObj.mqh>

class SymbolLossRecord : public CObject {
public:
   string symbol;
   int lossCount;
   datetime lastTradeTime;

   SymbolLossRecord(string sym) {
      symbol = sym;
      lossCount = 0;
      lastTradeTime = 0;
   }
};

class LossCooldownManager {
private:
   CArrayObj records;
   int maxLosses;
   int cooldownMinutes;

public:
   LossCooldownManager(int maxLosses_ = 2, int cooldownMins_ = 60) {
      maxLosses = maxLosses_;
      cooldownMinutes = cooldownMins_;
   }

   SymbolLossRecord* GetRecord(string symbol) {
      for(int i = 0; i < records.Total(); i++) {
         SymbolLossRecord* rec = (SymbolLossRecord*)records.At(i);
         if(rec.symbol == symbol)
            return rec;
      }

      SymbolLossRecord* newRec = new SymbolLossRecord(symbol);
      records.Add(newRec);
      return newRec;
   }

   bool CanTrade(string symbol) {
      SymbolLossRecord* rec = GetRecord(symbol);
      if(rec.lossCount >= maxLosses) {
         datetime now = TimeCurrent();
         if(now - rec.lastTradeTime < cooldownMinutes * 60)
            return false;
      }
      return true;
   }

   void RecordTrade(string symbol, double profit) {
      SymbolLossRecord* rec = GetRecord(symbol);
      rec.lastTradeTime = TimeCurrent();

      if(profit < 0)
         rec.lossCount++;
      else
         rec.lossCount = 0;  // reset after a win
   }
};
