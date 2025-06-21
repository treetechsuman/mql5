//+------------------------------------------------------------------+
//|               Zone Recovery EA - Fixed Version                   |
//|               Multi-Symbol MA-Based Recovery System              |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>


// Input parameters
input string   SymbolsList = "EURUSD,GBPUSD,USDJPY";
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15;
input double   TakeProfitPips = 20;
input double   StopLossPips = 20;
input double   ProfitBuffer = 2.0;
input int      MaxRecoveryAttempts = 3;
input double   BaseLotSize = 0.1;
input int      MAPeriod = 14;

CTrade trade;
string symbols[];
datetime lastTradeTime[];

//+------------------------------------------------------------------+
//| Loss Tracking Class                                              |
//+------------------------------------------------------------------+
class RecoveryLossRecord : public CObject {
public:
   string symbol;
   double lossAmount;
   int recoveryAttempts;

   RecoveryLossRecord(string sym, double loss) {
      symbol = sym;
      lossAmount = loss;
      recoveryAttempts = 0;
   }
   void IncrementAttempts() {
      recoveryAttempts++;
   }
   
};

CArrayObj lossHistory;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   StringSplit(SymbolsList, ',', symbols);
   ArrayResize(lastTradeTime, ArraySize(symbols));
   ArrayInitialize(lastTradeTime, 0);
   lossHistory.Clear();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Calculate recovery lot size                                      |
//+------------------------------------------------------------------+
double CalculateRecoveryLot(string symbol, double lossAmount) {
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tickValue <= 0 || point <= 0 || TakeProfitPips <= 0)
      return BaseLotSize;
   double profitPerLot = tickValue * TakeProfitPips;
   double requiredProfit = lossAmount + ProfitBuffer;
   double lot = requiredProfit / profitPerLot;
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   lot = NormalizeDouble(lot / step, 0) * step;
   return lot;
}


//+------------------------------------------------------------------+
//| MA Crossover Signal with Slope Confirmation                      |
//+------------------------------------------------------------------+
string MaSignal(string symbol) {
   int maHandle = iMA(symbol, Timeframe, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE) return "NoTrade";

   double ma[3], close[1];
   if(CopyBuffer(maHandle, 0, 0, 3, ma) < 3) return "NoTrade";
   if(CopyClose(symbol, Timeframe, 0, 1, close) < 1) return "NoTrade";

   double slope = ma[0] - ma[2]; // Compare current MA to MA two bars back

   if(close[0] > ma[0] && slope > 0)
      return "BUY";
   else if(close[0] < ma[0] && slope < 0)
      return "SELL";
   else
      return "NoTrade";
}


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

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result) {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;
   string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);

   if(reason == DEAL_REASON_SL && profit < 0) {
      RecoveryLossRecord* existingRecord = NULL;
      for(int i = 0; i < lossHistory.Total(); i++) {
         RecoveryLossRecord* rec = (RecoveryLossRecord*)lossHistory.At(i);
         if(rec != NULL && rec.symbol == symbol) {
            existingRecord = rec;
            break;
         }
      }
      if(existingRecord != NULL) {
         existingRecord.lossAmount += MathAbs(profit);
         //existingRecord.recoveryAttempts = 0;
         Print("Accumulated loss for ", symbol, ": $", existingRecord.lossAmount);
      } else {
         RecoveryLossRecord* newRecord = new RecoveryLossRecord(symbol, MathAbs(profit));
         lossHistory.Add(newRecord);
         Print("New loss recorded for ", symbol, ": $", newRecord.lossAmount);
      }
   }
   else if(profit > 0) {
   // Remove recovery record for this symbol (profit hit regardless of comment)
   for(int i = 0; i < lossHistory.Total(); i++) {
      RecoveryLossRecord* rec = (RecoveryLossRecord*)lossHistory.At(i);
      if(rec != NULL && rec.symbol == symbol) {
         lossHistory.Delete(i);
         Print("Profit hit for ", symbol, ". Recovery record removed.");
         break;
      }
   }
}
   
}

//+------------------------------------------------------------------+
//| Get loss record for a symbol                                     |
//+------------------------------------------------------------------+
RecoveryLossRecord* GetLossRecord(string symbol) {
   for(int i = 0; i < lossHistory.Total(); i++) {
      RecoveryLossRecord* rec = (RecoveryLossRecord*)lossHistory.At(i);
      if(rec != NULL && rec.symbol == symbol) return rec;
   }
   return NULL;
}
//+------------------------------------------------------------------+
//| Calculate dynamic SL/TP based on ATR or percentage              |
//+------------------------------------------------------------------+
void CalculateDynamicSLTP(string symbol, ENUM_ORDER_TYPE direction, double &sl, double &tp) {
   double price = (direction == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   // Example: Use 1.5x ATR as SL/TP
   int atrPeriod = 14;
   double atrMultiplierSL = 1.5;
   double atrMultiplierTP = 2.0;
   int atrHandle = iATR(symbol, Timeframe, atrPeriod);
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) {
      sl = 20*point;
      tp = 40*point;
      return;
   }

   double atrValue = atr[0];

   if(direction == ORDER_TYPE_BUY) {
      sl = price - atrValue * atrMultiplierSL;
      tp = price + atrValue * atrMultiplierTP;
   } else {
      sl = price + atrValue * atrMultiplierSL;
      tp = price - atrValue * atrMultiplierTP;
   }
}
//+------------------------------------------------------------------+
//| Main trading function                                            |
//+------------------------------------------------------------------+

void OnTick() {
   for(int s = 0; s < ArraySize(symbols); s++) {
      string symbol = symbols[s];
      datetime currentBarTime = iTime(symbol, Timeframe, 0);
      if(lastTradeTime[s] == currentBarTime) continue;
      if(IsTradeOpen(symbol)) continue;

      RecoveryLossRecord* lossRec = GetLossRecord(symbol);
      
      // Always get signals early
      string maSignal = MaSignal(symbol);
      if(lossRec != NULL) {
         DrawRecoveryInfo(symbol, lossRec.recoveryAttempts, MaxRecoveryAttempts, lossRec.lossAmount);
         // Wait for a valid signal
         if(maSignal=="NoTrade") continue; // no recovery signal

         if(lossRec.recoveryAttempts >= MaxRecoveryAttempts) {
            Print(symbol, ": Max recovery attempts reached. Removing record.");
            for(int i = 0; i < lossHistory.Total(); i++) {
               RecoveryLossRecord* rec = (RecoveryLossRecord*)lossHistory.At(i);
               if(rec != NULL && rec.symbol == symbol) {
                  lossHistory.Delete(i);
                  break;
               }
            }
            continue;
         }
         ENUM_ORDER_TYPE direction;
         double sl,tp,price;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double lotSize = CalculateRecoveryLot(symbol, lossRec.lossAmount);
         if(maSignal=="BUY"){
            price = SymbolInfoDouble(symbol, SYMBOL_ASK);
            //sl =  price - StopLossPips * point;
            //tp =  price + TakeProfitPips* point;
            direction =  ORDER_TYPE_BUY;
            CalculateDynamicSLTP(symbol,direction, sl, tp);
            if(trade.PositionOpen(symbol, direction, lotSize, price, sl, tp, "Recovery")) {
               lossRec.IncrementAttempts();
               lastTradeTime[s] = currentBarTime; 
            }
         }
         if(maSignal=="SELL"){
            price = SymbolInfoDouble(symbol, SYMBOL_BID);
            //sl =  price + StopLossPips * point;
            //tp =  price - TakeProfitPips* point;
            direction =  ORDER_TYPE_SELL;
            CalculateDynamicSLTP(symbol,direction, sl, tp);
            if(trade.PositionOpen(symbol, direction, lotSize, price, sl, tp, "Recovery")) {
               lossRec.IncrementAttempts();
               lastTradeTime[s] = currentBarTime;
               
            }
         }
         
      } else {
         // Normal trading logic
         if(maSignal=="NoTrade") continue;

         //ENUM_ORDER_TYPE direction = buySignal ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         ENUM_ORDER_TYPE direction;
         double sl,tp,price;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(maSignal=="BUY"){
            price = SymbolInfoDouble(symbol, SYMBOL_ASK);
            //sl =  price - StopLossPips * point;
            //tp =  price + TakeProfitPips* point;
            direction =  ORDER_TYPE_BUY;
            CalculateDynamicSLTP(symbol,direction, sl, tp);
            if(trade.PositionOpen(symbol, direction, BaseLotSize, price, sl, tp, "Normal")) {
               lastTradeTime[s] = currentBarTime;
               //Print(symbol, ": Normal trade opened.");
            }
         }
         if(maSignal=="SELL"){
            price = SymbolInfoDouble(symbol, SYMBOL_BID);
            //sl =  price + StopLossPips * point;
            //tp =  price - TakeProfitPips* point;
            direction =  ORDER_TYPE_SELL;
            CalculateDynamicSLTP(symbol,direction, sl, tp);
            if(trade.PositionOpen(symbol, direction, BaseLotSize, price, sl, tp, "Normal")) {
               lastTradeTime[s] = currentBarTime;
               //Print(symbol, ": Normal trade opened.");
            }
         }
         
      }
   }
}


//+------------------------------------------------------------------+
//| Draw large, clear recovery info on chart                         |
//+------------------------------------------------------------------+
void DrawRecoveryInfo(string symbol, int attempts, int maxAttempts, double lossAmount) {
   string label = "RecoveryInfo_" + symbol;

   // Remove existing label
   ObjectDelete(0, label);

   // Compose message
   string message = symbol + " | Attempts: " + IntegerToString(attempts) + "/" + IntegerToString(maxAttempts) +
                    " | Loss: $" + DoubleToString(lossAmount, 2);

   // Get index manually to avoid ArrayBsearch
   int index = 0;
   for(int i = 0; i < ArraySize(symbols); i++) {
      if(symbols[i] == symbol) {
         index = i;
         break;
      }
   }

   // Create label
   ObjectCreate(0, label, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, label, OBJPROP_XDISTANCE, 40);
   ObjectSetInteger(0, label, OBJPROP_YDISTANCE, 40 + 30 * index);
   ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 16);
   ObjectSetInteger(0, label, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, label, OBJPROP_HIDDEN, true);
   ObjectSetString(0, label, OBJPROP_TEXT, message);
}
