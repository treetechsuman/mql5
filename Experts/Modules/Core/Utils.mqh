#ifndef UTILS_MQH
#define UTILS_MQH


#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>  // For multi-symbol tracking version
//+------------------------------------------------------------------+
//| Check for open positions                                         |
//+------------------------------------------------------------------+
bool IsTradeOpen(string symbol) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == symbol)
            return true;
      }
   }
   return false;
}

// Check if long position exists for symbol
bool IsLongPositionOpen(string symbol) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            return true;
      }
   }
   return false;
}

// Check if short position exists for symbol
bool IsShortPositionOpen(string symbol) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            return true;
      }
   }
   return false;
}

// Count positions for symbol (all/direction-specific)
int CountPositions(string symbol, ENUM_POSITION_TYPE type = WRONG_VALUE) {
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            (type == WRONG_VALUE || PositionGetInteger(POSITION_TYPE) == type))
            count++;
      }
   }
   return count;
}

// Close all positions for symbol
bool CloseAllPositions(string symbol, int deviation = 20) {
   bool closed = true;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == symbol) {
         CTrade trade;
         trade.SetDeviationInPoints(deviation);
         if(!trade.PositionClose(ticket))
            closed = false;
      }
   }
   return closed;
}

// Check if market is open for symbol


// Get spread in points
double GetSpreadPoints(string symbol) {
   return SymbolInfoInteger(symbol, SYMBOL_SPREAD) * 
          SymbolInfoDouble(symbol, SYMBOL_POINT);
}

// get atr 
double GetAtrBySymbole(string symbol,ENUM_TIMEFRAMES timeframe, int atrPeriod){
   
   int atrHandle = iATR(symbol, timeframe, atrPeriod);
    if (atrHandle == INVALID_HANDLE) {
        Print("Failed to create ATR handle for ", symbol);
        return -1;
    }

    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if (CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) != 1) {
        Print("Failed to copy ATR data for ", symbol);
        return -1;
    }
     // Print("ATR value ", atrBuffer[0]);
    return atrBuffer[0]; // Most recent ATR value
}
int AtrToPips(double atrValue, string symbol) {
    double pipValue = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5) ? 0.0001 : 0.01;
    return int(atrValue / pipValue);
}
//+------------------------------------------------------------------+
//| Bar Detection Functions                                          |
//+------------------------------------------------------------------+

// Single Symbol/Timeframe Version (most common use case)
bool IsNewBar() {
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    
    if(lastBarTime != currentBarTime) {
        lastBarTime = currentBarTime;
        return true;
    }
    return false;
}

// Multi-Symbol/Timeframe Tracking Version
class BarTracker : public CObject {
public:
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    datetime lastBarTime;
    
    BarTracker(string s, ENUM_TIMEFRAMES t) : symbol(s), timeframe(t), lastBarTime(0) {}
};

CArrayObj barTrackers;

bool IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe) {
    // Find existing tracker
    for(int i = 0; i < barTrackers.Total(); i++) {
        BarTracker* bt = barTrackers.At(i);
        if(bt.symbol == symbol && bt.timeframe == timeframe) {
            datetime currentBarTime = iTime(symbol, timeframe, 0);
            if(bt.lastBarTime != currentBarTime) {
                bt.lastBarTime = currentBarTime;
                return true;
            }
            return false;
        }
    }
    
    // Create new tracker if not found
    BarTracker* newTracker = new BarTracker(symbol, timeframe);
    newTracker.lastBarTime = iTime(symbol, timeframe, 0);// may create issue
    barTrackers.Add(newTracker);
    return false;  // First call never returns true
}

//+------------------------------------------------------------------+
//| Cleanup function to call in OnDeinit                             |
//+------------------------------------------------------------------+
void CleanupBarTrackers() {
    for(int i = barTrackers.Total()-1; i >= 0; i--)
        delete barTrackers.Detach(i);
}

//+------------------------------------------------------------------+
//| Prepares multiple symbols for use in Strategy Tester and live   |
//+------------------------------------------------------------------+
bool InitMultiSymbolData(string &symbols[], ENUM_TIMEFRAMES tf = PERIOD_M15, datetime from = 0, datetime to = 0) {
   if(from == 0) from = D'2023.01.01';
   if(to == 0) to = TimeCurrent();

   for(int i = 0; i < ArraySize(symbols); i++) {
      string sym = symbols[i];

      if(!SymbolSelect(sym, true)) {
         Print("❌ Failed to select symbol: ", sym);
         return false;
      }

      if(!HistorySelect(from, to)) {
         Print("❌ Failed to select history for ", sym);
         return false;
      }

      MqlRates rates[];
      if(CopyRates(sym, tf, from, to, rates) <= 0) {
         Print("❌ Failed to load rates for ", sym);
         return false;
      }

      Print("✅ Symbol initialized: ", sym, " [Bars: ", ArraySize(rates), "]");
   }

   return true;
}

double GetRecentSwingHigh(string symbol, ENUM_TIMEFRAMES tf, int barsBack = 20) {
   double high = -DBL_MAX;
   MqlRates rates[];
   if (CopyRates(symbol, tf, 1, barsBack, rates) <= 0) return -1;

   for (int i = 0; i < barsBack; i++) {
      if (rates[i].high > high)
         high = rates[i].high;
   }
   return high;
}

double GetRecentSwingLow(string symbol, ENUM_TIMEFRAMES tf, int barsBack = 20) {
   double low = DBL_MAX;
   MqlRates rates[];
   if (CopyRates(symbol, tf, 1, barsBack, rates) <= 0) return -1;

   for (int i = 0; i < barsBack; i++) {
      if (rates[i].low < low)
         low = rates[i].low;
   }
   return low;
}

string BoolToString(bool val) {
   return val ? "true" : "false";
}

//+------------------------------------------------------------------+
//| 📦 Calculates lot size based on risk % and ATR-based stop loss  |
//+------------------------------------------------------------------+
double CalculateLotSizeByRisk(string symbol, double riskPercent, double atrMultiplier, ENUM_TIMEFRAMES tf = PERIOD_H1) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

   // --- Get ATR value
   int atrPeriod = 14;
   int handle = iATR(symbol, tf, atrPeriod);
   if (handle == INVALID_HANDLE) {
      Print("❌ ATR handle invalid for ", symbol);
      return 0;
   }
   double atrBuffer[];
   if (CopyBuffer(handle, 0, 0, 1, atrBuffer) <= 0) {
      Print("❌ Failed to copy ATR for ", symbol);
      return 0;
   }
   double atr = atrBuffer[0];
   if (atr <= 0.0) return 0;

   // --- Calculate SL in price
   double stopLoss = atr * atrMultiplier;

   // --- Calculate pip value (in account currency)
   double slInMoney = stopLoss / tickSize * tickValue;

   // --- Risk in money
   double riskAmount = balance * (riskPercent / 100.0);

   // --- Calculate lot size
   double lotSize = riskAmount / slInMoney;

   // --- Adjust for broker limits
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);

   return NormalizeDouble(lotSize, 2);
}



#endif
