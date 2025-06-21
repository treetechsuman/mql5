//+------------------------------------------------------------------+
//|                                                      RecoveryEA.mq5 |
//|                  Copyright 2023, MetaQuotes Ltd.                 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Multi-symbol EA with advanced loss recovery"
#property description "Uses moving average crossover for entry signals"


#include "Modules/AdvanceLossRecovery.mqh";
#include "Modules/Utils.mqh";
#include "Modules/RiskManagement.mqh";
#include "Modules/InfoDashboard.mqh";


//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input string   Symbols             = "EURUSD,GBPUSD,USDJPY,XAUUSD"; // Trade symbols
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15;
input double   RiskPercent         = 1.0;        // Risk per trade (%)
input int      MAPeriod            = 20;         // MA Period
input int      MaxRecoveryAttempts = 3;          // Max Recovery Attempts
input int      RecoveryCooldown    = 3600;       // Recovery Cooldown (sec)
input int      AtrPeriod           = 14;
input int      MinAtrToTakeTrade   = 5;
input double   ProfitBuffer        = 2.0; 
       // Profit Buffer ($)
input bool     EnableRecovery      = true;       // Enable Recovery System
input int      MagicNumber         = 12345;      // Magic Number

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
string   tradeSymbols[];
datetime lastTradeTime[];
string Rows[] = {"EMA Signal", "RSI Signal", "ATR", "Other Info"};
CTrade   trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Parse symbol list
   StringSplit(Symbols, ',', tradeSymbols);
   ArrayResize(lastTradeTime, ArraySize(tradeSymbols));
   ArrayInitialize(lastTradeTime, 0);
   InitDashboard(tradeSymbols, Rows, 20, 20);
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Set up recovery dashboard
   EventSetTimer(1);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
   CleanupLossRecovery();
   CleanupBarTrackers();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   //DrawRecoveryDashboard(tradeSymbols, MaxRecoveryAttempts);
   for(int i = 0; i < ArraySize(tradeSymbols); i++) {
      string symbol = tradeSymbols[i];
      
      // Skip if market closed
      //if(!IsMarketOpen(symbol)) continue;
      //is 
      if(IsTradeOpen(symbol)) continue;
      // Generate trading signal
      string signal = MaSignal(symbol,Timeframe,MAPeriod);
      double atr = GetAtrBySymbole(symbol,Timeframe,AtrPeriod);
      int atrInpip = AtrToPips(atr,symbol);
      //Print("ATR in PIPs : ", atrInpip );
      
      SignalStatus s1;
      ArrayResize(s1.values, 4);
      s1.values[0] = signal;
      s1.values[1] = "SELL";
      s1.values[2] = atrInpip;
      s1.values[3] = symbol;
      UpdateDashboard(symbol, s1);
      
      if(atrInpip<MinAtrToTakeTrade) continue;
      // Handle recovery logic
      double recoveryLot = 0;
      if((EnableRecovery&&signal != "NoTrade") && ShouldAttemptRecovery(
         symbol, 
         signal, 
         TimeCurrent(), 
         MaxRecoveryAttempts,
         RecoveryCooldown,
         atrInpip,
         ProfitBuffer,
         recoveryLot
      )) {
         ExecuteRecoveryTrade(symbol, signal, recoveryLot);
      }
      // Normal trading logic
      else if(signal != "NoTrade" && !IsTradeOpen(symbol)) {
         ExecuteNormalTrade(symbol, signal);
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function for dashboard update                              |
//+------------------------------------------------------------------+
void OnTimer() {
   //Comment("OnTimer Working");
   DrawRecoveryDashboard(tradeSymbols, MaxRecoveryAttempts);
}

//+------------------------------------------------------------------+
//| MA Crossover Signal with Slope Confirmation                      |
//+------------------------------------------------------------------+
string MaSignal(string symbol,ENUM_TIMEFRAMES timeFrame,int maPeriod) {
   int maHandle = iMA(symbol, timeFrame, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE) return "NoTrade";

   double ma[3], close[1];
   if(CopyBuffer(maHandle, 0, 0, 3, ma) < 3) return "NoTrade";
   if(CopyClose(symbol, timeFrame, 0, 1, close) < 1) return "NoTrade";

   double slope = ma[0] - ma[2]; // Compare current MA to MA two bars back

   if(close[0] > ma[0] && slope > 0)
      return "BUY";
   else if(close[0] < ma[0] && slope < 0)
      return "SELL";
   else
      return "NoTrade";
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
//| Execute normal trade with risk-based sizing                      |
//+------------------------------------------------------------------+
void ExecuteNormalTrade(string symbol, string signal) {
   //double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   //double price = SymbolInfoDouble(symbol, signal == "Buy" ? SYMBOL_ASK : SYMBOL_BID);
   double sl,tp, price;
   
   
   // Calculate lot size
   //double stopDistPoints = CalculateStopDistPoints(symbol, price, sl);
   //double lot = CalculateLotSize(symbol, RiskPercent, stopDistPoints);
   double lot = 0.01;
   double atr = GetAtrBySymbole(symbol,Timeframe,AtrPeriod);
   // Execute trade
   if(signal == "BUY") {
      price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      CalculateDynamicSLTP(symbol,ORDER_TYPE_BUY,sl,tp);
      double StopLossInPips =GetPipDifference(symbol,sl,price); 
      lot = CalculateAtrBaseLotSize(symbol,RiskPercent,atr );
      trade.Buy(lot, symbol, price, sl, tp);
   } else if(signal=="SELL") {
      price = SymbolInfoDouble(symbol, SYMBOL_BID);
      CalculateDynamicSLTP(symbol,ORDER_TYPE_SELL,sl,tp);
      double StopLossInPips =GetPipDifference(symbol,sl,price); 
      lot = CalculateAtrBaseLotSize(symbol,RiskPercent,atr );
      trade.Sell(lot, symbol, price, sl, tp);
   }
}

//+------------------------------------------------------------------+
//| Execute recovery trade with custom sizing                        |
//+------------------------------------------------------------------+
void ExecuteRecoveryTrade(string symbol, string signal, double lot) {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   //double price = SymbolInfoDouble(symbol, signal == "Buy" ? SYMBOL_ASK : SYMBOL_BID);
   double sl,tp,price;
   RecoveryLossRecord* lossRec = GetLossRecord(symbol);
   if(!lossRec==NULL){ 
   // Execute recovery trade
   if(signal == "BUY") {
      
      price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      sl = price - 20*point;
      tp = price + 20*point;
      //trade.Buy(lot, symbol, price, sl, tp, "Recovery Trade");
      if(trade.Buy(lot, symbol, price, sl, tp, "Recovery Trade")){
         lossRec.IncrementAttempts();
      }
   } else if(signal=="SELL") {
      price = SymbolInfoDouble(symbol, SYMBOL_BID);
      sl = price + 20*point;
      tp = price - 20*point;
      
      if(trade.Sell(lot, symbol, price, sl, tp, "Recovery Trade")){
         lossRec.IncrementAttempts();
      }
   }
   
   PrintFormat("[RECOVERY] %s %s %.2f lots", signal, symbol, lot);
   }
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
   HandleTradeTransaction(trans);
}

//+------------------------------------------------------------------+