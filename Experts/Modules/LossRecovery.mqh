//+------------------------------------------------------------------+
//| LossRecovery.mqh - Manages loss recovery records                 |
//+------------------------------------------------------------------+
#ifndef __LOSS_TRACKER_MQH__
#define __LOSS_TRACKER_MQH__

#include <Arrays/ArrayObj.mqh>

//+------------------------------------------------------------------+
//| RecoveryLossRecord Class                                        |
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
//| Handle trade transactions to track losses                        |
//+------------------------------------------------------------------+
void HandleTradeTransaction(const MqlTradeTransaction &trans,
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
         Print("Accumulated loss for ", symbol, ": $", existingRecord.lossAmount);
      } else {
         RecoveryLossRecord* newRecord = new RecoveryLossRecord(symbol, MathAbs(profit));
         lossHistory.Add(newRecord);
         Print("New loss recorded for ", symbol, ": $", newRecord.lossAmount);
      }
   }
   else if(profit > 0) {
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
//| Calculate recovery lot size based on loss amount                |
//+------------------------------------------------------------------+
double CalculateRecoveryLot(string symbol, double takeProfitPips, double profitBuffer, double baseLotSize) {
   RecoveryLossRecord* lossRec = GetLossRecord(symbol);
   if(lossRec != NULL) {
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tickValue <= 0 || point <= 0 || takeProfitPips <= 0)
      return baseLotSize;

   double profitPerLot = tickValue * takeProfitPips;
   double requiredProfit = lossRec.lossAmount + profitBuffer;
   double lot = requiredProfit / profitPerLot;

   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   lot = NormalizeDouble(lot / step, 0) * step;

   return lot;}else{ return 0.01; }
}

//+------------------------------------------------------------------+
//| Draw large, clear recovery info on chart                         |
//+------------------------------------------------------------------+
void DrawRecoveryInfo(string symbol, int attempts, int maxAttempts, double lossAmount, string &symbols[]) {
   string label = "RecoveryInfo_" + symbol;
   ObjectDelete(0, label);

   string message = symbol + " | Attempts: " + IntegerToString(attempts) + "/" + IntegerToString(maxAttempts) +
                    " | Loss: $" + DoubleToString(lossAmount, 2);

   int index = 0;
   for(int i = 0; i < ArraySize(symbols); i++) {
      if(symbols[i] == symbol) {
         index = i;
         break;
      }
   }

   ObjectCreate(0, label, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, label, OBJPROP_XDISTANCE, 40);
   ObjectSetInteger(0, label, OBJPROP_YDISTANCE, 40 + 30 * index);
   ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 16);
   ObjectSetInteger(0, label, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, label, OBJPROP_HIDDEN, true);
   ObjectSetString(0, label, OBJPROP_TEXT, message);
}

//+------------------------------------------------------------------+
//| Determines if recovery should be attempted for this symbol      |
//+------------------------------------------------------------------+
bool ShouldAttemptRecovery(string symbol,
                           string signal,
                           datetime currentBarTime,
                           int maxAttempts,
                           string &symbols[],
                           datetime &lastTradeTimeRef,
                           double &lotSizeOut,
                           double takeProfitPips = 20,
                           double profitBuffer = 2.0,
                           double baseLotSize = 0.1) {

   RecoveryLossRecord* lossRec = GetLossRecord(symbol);
   if(lossRec == NULL) return false;

   DrawRecoveryInfo(symbol, lossRec.recoveryAttempts, maxAttempts, lossRec.lossAmount, symbols);

   if(signal == "NoTrade") return false;

   if(lossRec.recoveryAttempts >= maxAttempts) {
      Print(symbol, ": Max recovery attempts reached. Removing record.");
      for(int i = 0; i < lossHistory.Total(); i++) {
         RecoveryLossRecord* rec = (RecoveryLossRecord*)lossHistory.At(i);
         if(rec != NULL && rec.symbol == symbol) {
            lossHistory.Delete(i);
            break;
         }
      }
      return false;
   }

   lotSizeOut = CalculateRecoveryLot(symbol, takeProfitPips, profitBuffer, baseLotSize);
   lossRec.IncrementAttempts();
   lastTradeTimeRef = currentBarTime;
   return true;
}

#endif // __LOSS_TRACKER_MQH__
