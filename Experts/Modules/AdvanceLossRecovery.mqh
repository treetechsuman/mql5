//+------------------------------------------------------------------+
//| LossRecovery.mqh - Advanced loss recovery management             |
//+------------------------------------------------------------------+
#ifndef __LOSS_TRACKER_MQH__
#define __LOSS_TRACKER_MQH__

#include <Arrays\ArrayObj.mqh>
#include <Trade\Trade.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//+------------------------------------------------------------------+
//| RecoveryLossRecord Class                                         |
//+------------------------------------------------------------------+
class RecoveryLossRecord : public CObject {
public:
   string            symbol;
   double            lossAmount;
   int               recoveryAttempts;
   datetime          lastAttemptTime;

                     RecoveryLossRecord(string sym, double loss) :
                      symbol(sym),
                      lossAmount(loss),
                      recoveryAttempts(0),
                      lastAttemptTime(0) {}

   void              IncrementAttempts() {
      recoveryAttempts++;
      lastAttemptTime = TimeCurrent();
   }
};

CArrayObj lossHistory;

//+------------------------------------------------------------------+
//| Get loss record for a symbol                                     |
//+------------------------------------------------------------------+
RecoveryLossRecord* GetLossRecord(string symbol) {
   for(int i = lossHistory.Total()-1; i >= 0; i--) {
      RecoveryLossRecord* rec = dynamic_cast<RecoveryLossRecord*>(lossHistory.At(i));
      if(rec != NULL && rec.symbol == symbol) return rec;
   }
   return NULL;
}

//+------------------------------------------------------------------+
//| Handle trade transactions to track losses                        |
//+------------------------------------------------------------------+
void HandleTradeTransaction(const MqlTradeTransaction &trans) {
   // Only process deal completion events
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   
   // Get deal details
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) {
      Print("Failed to select deal: ", dealTicket);
      return;
   }
   
   string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

   // Track stop-loss hits
   if(reason == DEAL_REASON_SL && profit < 0 && entry == DEAL_ENTRY_OUT) {
      RecoveryLossRecord* record = GetLossRecord(symbol);
      double absLoss = MathAbs(profit);
      
      if(record) {
         record.lossAmount += absLoss;
         PrintFormat("[%s] Accumulated loss: $%.2f (Total: $%.2f)", 
                     symbol, absLoss, record.lossAmount);
      } else {
         RecoveryLossRecord* newRecord = new RecoveryLossRecord(symbol, absLoss);
         if(lossHistory.Add(newRecord)) {
            PrintFormat("[%s] New loss recorded: $%.2f", symbol, absLoss);
         } else {
            Print("Failed to add loss record for ", symbol);
            delete newRecord;
         }
      }
   }
   // Clear record on profit-taking
   else if(profit > 0) {
      for(int i = lossHistory.Total()-1; i >= 0; i--) {
         RecoveryLossRecord* rec = dynamic_cast<RecoveryLossRecord*>(lossHistory.At(i));
         if(rec != NULL && rec.symbol == symbol) {
            PrintFormat("[%s] Profit realized. Removing loss record ($%.2f)", 
                        symbol, rec.lossAmount);
            delete lossHistory.Detach(i);
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate recovery lot size safely                               |
//+------------------------------------------------------------------+
double CalculateRecoveryLot(string symbol, double takeProfitPips, double profitBuffer, double baseLotSize) {
   RecoveryLossRecord* lossRec = GetLossRecord(symbol);
   if(!lossRec) return baseLotSize;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(point <= 0 || tickValue <= 0 || takeProfitPips <= 0) {
      Print("Invalid market data for ", symbol);
      return baseLotSize;
   }
   
   // Calculate required profit
   double requiredProfit = lossRec.lossAmount + profitBuffer;
   double profitPerLot = takeProfitPips * tickValue;
   
   if(profitPerLot <= 0) {
      Print("Invalid profit calculation for ", symbol);
      return baseLotSize;
   }
   
   // Calculate and normalize lot size
   double lot = requiredProfit / profitPerLot;
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   int lotDigits = (int)MathRound(MathLog10(1.0/step));
   
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   lot = NormalizeDouble(lot, lotDigits);
   
   PrintFormat("[%s] Recovery lot: %.2f (Required: $%.2f)", 
               symbol, lot, requiredProfit);
   return lot;
}

//+------------------------------------------------------------------+
//| Draw recovery dashboard with multiple panels                     |
//+------------------------------------------------------------------+
void DrawRecoveryDashboard(string &symbols[], int maxAttempts) {
   int yOffset = 400;
   int xOffset = 20;
   int panelWidth = 500;
   int panelHeight = 60;
   int spacing = 10;
   int fontSize = 10;
   color textColor = clrWhite;
   color bgColor = C'30,30,30';
   
   string commentText = "Recovery Dashboard:\n";
   
   for(int i = 0; i < ArraySize(symbols); i++) {
      string symbol = symbols[i];
      string panelName = "RecoveryPanel_" + symbol;
      string labelName = "RecoveryLabel_" + symbol;
      
      //--- Create or update panel ---//
      if(ObjectFind(0, panelName) < 0) {
         ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, bgColor);
         ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, panelName, OBJPROP_BORDER_COLOR, clrGray);
         ObjectSetInteger(0, panelName, OBJPROP_BACK, true);
         ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, panelName, OBJPROP_HIDDEN, false);  // FIX: Make visible
      }
      
      //--- Position panel ---//
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, xOffset);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, yOffset + i * (panelHeight + spacing));
      ObjectSetInteger(0, panelName, OBJPROP_XSIZE, panelWidth);
      ObjectSetInteger(0, panelName, OBJPROP_YSIZE, panelHeight);
      
      //--- Get loss record ---//
      RecoveryLossRecord* rec = GetLossRecord(symbol);
      string statusText = rec ? "ACTIVE" : "INACTIVE";
      color statusColor = rec ? 
             (rec.recoveryAttempts >= maxAttempts ? clrOrangeRed : clrLimeGreen) : clrSilver;
      
      //--- Update panel color ---//
      ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, statusColor);
      
      //--- Create info text ---//
      string info = StringFormat("%s | Status: %s\nAttempts: %d/%d\nLoss: $%.2f",
         symbol, statusText,
         rec ? rec.recoveryAttempts : 0, maxAttempts,
         rec ? rec.lossAmount : 0.0);
      
      //--- Build comment ---//
      commentText += info + "\n\n";
      
      //--- Create/update text label ---//
      if(ObjectFind(0, labelName) < 0) {
         ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, textColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, fontSize);
         ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);  // FIX: Make visible
      }
      
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xOffset + 5);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yOffset + 5 + i * (panelHeight + spacing));
      ObjectSetString(0, labelName, OBJPROP_TEXT, info);
   }
   
   //Comment(commentText);  // Show all symbols in comment
}

//+------------------------------------------------------------------+
//| Determines if recovery should be attempted                       |
//+------------------------------------------------------------------+
bool ShouldAttemptRecovery(
   string symbol,
   string signal,
   datetime currentTime,
   int maxAttempts,
   int recoveryCooldown,
   int takeProfitPips,
   double profitBuffer,
   double &lotSizeOut
) {
   // Check valid signal
   if(signal == "NoTrade") return false;
   
   RecoveryLossRecord* lossRec = GetLossRecord(symbol);
   if(!lossRec) return false;
   
   // Check max attempts
   if(lossRec.recoveryAttempts >= maxAttempts) {
      PrintFormat("[%s] Max recovery attempts reached (%d)", symbol, maxAttempts);
      return false;
   }
   
   // Check cooldown period
   if(recoveryCooldown > 0 && 
      (currentTime - lossRec.lastAttemptTime) < recoveryCooldown) {
      PrintFormat("[%s] Recovery in cooldown (%d seconds remaining)", 
                symbol, recoveryCooldown - (currentTime - lossRec.lastAttemptTime));
      return false;
   }
   
   // Calculate lot size
   lotSizeOut = CalculateRecoveryLot(symbol, takeProfitPips, profitBuffer, 0.1);
   
   // Validate lot size
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if(lotSizeOut < minLot) {
      PrintFormat("[%s] Calculated lot (%.2f) below minimum (%.2f)", 
                 symbol, lotSizeOut, minLot);
      return false;
   }
   Print("recoveryatttampt --- ",lossRec.recoveryAttempts);
   //lossRec.IncrementAttempts();
   return true;
}

//+------------------------------------------------------------------+
//| Cleanup resources on expert deinit                               |
//+------------------------------------------------------------------+
void CleanupLossRecovery() {
   for(int i = lossHistory.Total()-1; i >= 0; i--) {
      RecoveryLossRecord* rec = dynamic_cast<RecoveryLossRecord*>(lossHistory.Detach(i));
      if(rec) delete rec;
   }
   ObjectsDeleteAll(0, "RecoveryPanel_");
   ObjectsDeleteAll(0, "RecoveryLabel_");
}

#endif // __LOSS_TRACKER_MQH__