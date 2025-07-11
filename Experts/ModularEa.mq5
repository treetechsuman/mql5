//+------------------------------------------------------------------+
//|                                                  Modular.mq5  |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh> // Required for CArrayObj
#include "Modules/Core/Core.mqh"
#include "Modules/Reports/SymbolReport.mqh"
#include "Modules/Recoveries/LossCooldownManager.mqh"


// Input parameters
input string   Symbols        = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,NZDUSD"; // Comma-separated symbols
input ENUM_TIMEFRAMES Timeframe    = PERIOD_H1;
input double   RiskPercent    = 1.0;             // Risk per trade (% of balance)

input int      RSIPeriod      = 14;              // RSI period
input int      RSIUpperLevel    = 55;
input int      RSILowerLevel    = 45;

input int      ADXPeriod      = 14;              // ADX period
input int      ADXTradeValue = 25;

input int      fastMaPeriod   =9;
input int      slowMaPeriod   =21;

input int      VolLookback    = 30;              // Volatility lookback periods
input double   SqueezeFactor  = 0.85;            // Squeeze threshold factor
input bool     UseVolume      = true;            // Use volume confirmation

// Global objects
class SymbolData : public CObject {
public:
   string symbol;
   int fastMaHandle, slowMaHandle,rsiHandle, adxHandle, atrHandle;
   double fastMa[],slowMa[],atr[],  rsi[], adx[], plusDI[], minusDI[];
   long volumes[];
   datetime lastTradeTime;
   MqlRates priceData[];

   bool Init(string sym) {
      symbol = sym;
      rsiHandle = iRSI(symbol, Timeframe, RSIPeriod, PRICE_CLOSE);
      adxHandle = iADX(symbol, Timeframe, ADXPeriod);
      atrHandle = iATR(symbol,Timeframe,20);
      fastMaHandle = iMA(symbol,Timeframe,fastMaPeriod,0,MODE_EMA,PRICE_CLOSE);
      slowMaHandle = iMA(symbol,Timeframe,slowMaPeriod,0,MODE_EMA,PRICE_CLOSE);

      
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(adx, true);
      ArraySetAsSeries(plusDI, true);
      ArraySetAsSeries(minusDI, true);
      ArraySetAsSeries(volumes, true);
      ArraySetAsSeries(priceData, true);
      ArraySetAsSeries(slowMa, true);
      ArraySetAsSeries(fastMa, true);
      return (rsiHandle != INVALID_HANDLE && adxHandle != INVALID_HANDLE && fastMaHandle != INVALID_HANDLE&& slowMaHandle != INVALID_HANDLE  && atrHandle != INVALID_HANDLE);
   }
};

CArrayObj contexts;
CTrade trade;
string   tradeSymbols[];
datetime lastTradeTime[];
string Rows[] = {"MarketSignal", "CandelSignal", "RsiSignal","ADX Confirmation", "Symbol"};
CSymbolReportManager reportManager;
LossCooldownManager cooldown(2, 60);  // Max 2 losses, 60 min cooldown

int TimeHour(datetime t) {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
}

//+------------------------------------------------------------------+
int OnInit() {
   contexts.Clear();
   string list[];
   StringSplit(Symbols, ',', list);
   for(int i = 0; i < ArraySize(list); i++) {
      SymbolData *sd = new SymbolData;
      if(sd.Init(list[i]))
         contexts.Add(sd);
      else
         delete sd;
   }
   ArrayResize(lastTradeTime, ArraySize(list));
   InitDashboard(list, Rows, 20, 20);
   ArrayInitialize(lastTradeTime, 0);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   for(int i = 0; i < contexts.Total(); i++) {
      SymbolData *sd = (SymbolData*)contexts.At(i);
      IndicatorRelease(sd.rsiHandle);
      IndicatorRelease(sd.atrHandle);
      IndicatorRelease(sd.adxHandle);
      IndicatorRelease(sd.fastMaHandle);
      IndicatorRelease(sd.slowMaHandle);
      
   }
   reportManager.PrintAll();  // This prints to Experts log
   contexts.Clear();
}

//+------------------------------------------------------------------+
void OnTick() {
   for(int i = 0; i < contexts.Total(); i++) {
      SymbolData *sd = (SymbolData*)contexts.At(i);
      ProcessSymbol(sd);
      string symbol = sd.symbol;
      string symbolReport="No report yet";
      string marketSignal = GetMarketState(sd);
      string candleSignal = "CandelSignal(sd)";
      string rsiSignal = RsiSignal(sd);
      string adxValue = NormalizeDouble(sd.adx[0],2);
      SignalStatus s1;
      ArrayResize(s1.values, 5);
      s1.values[0] = marketSignal;
      s1.values[1] = candleSignal;
      s1.values[2] = rsiSignal;
      s1.values[3] = adxValue;
      s1.values[4] = symbol;
      UpdateDashboard(symbol, s1);
   }
}

//+------------------------------------------------------------------+
void ProcessSymbol(SymbolData *sd) {
   if(sd.lastTradeTime == iTime(sd.symbol, Timeframe, 0)) return;
   sd.lastTradeTime = iTime(sd.symbol, Timeframe, 0);

   CopyRates(sd.symbol, Timeframe, 0, VolLookback, sd.priceData);
   CopyTickVolume(sd.symbol, Timeframe, 0, VolLookback, sd.volumes);
   
   CopyBuffer(sd.rsiHandle, 0, 0, VolLookback, sd.rsi);
   CopyBuffer(sd.adxHandle, 0, 0, VolLookback, sd.adx);
   CopyBuffer(sd.adxHandle, 1, 0, VolLookback, sd.plusDI);
   CopyBuffer(sd.adxHandle, 2, 0, VolLookback, sd.minusDI);
   CopyBuffer(sd.atrHandle, 0, 0, VolLookback, sd.atr);
   CopyBuffer(sd.slowMaHandle, 0, 0, VolLookback, sd.slowMa);
   CopyBuffer(sd.fastMaHandle, 0, 0, VolLookback, sd.fastMa);

   double ask = SymbolInfoDouble(sd.symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sd.symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(sd.symbol, SYMBOL_POINT);
   double spread = SymbolInfoInteger(sd.symbol, SYMBOL_SPREAD) * point;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100);
   double lotSize = 0.1;

   string marketState = GetMarketState(sd);

   if(marketState=="Trending") {
      HandleTrendingState(sd, ask, bid, point, spread, riskAmount, lotSize);
      //HandleMaTrendingState(sd, ask, bid, point, spread, riskAmount, lotSize);
      //HandleRangingState(sd, ask, bid, point, spread, riskAmount, lotSize);
   }
   if(marketState=="Ranging") {
      //HandleRangingState(sd, ask, bid, point, spread, riskAmount, lotSize);
   }
      

   ManageExits(sd, ask, bid, point);
}


string GetMarketState(SymbolData *sd) {
   
   return "Neutral";
   
}



//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void HandleTrendingState(
    SymbolData *sd, double ask, double bid, double point, 
    double spread, double riskAmount, double &lotSize
) {
   lotSize=0.01;
    Print("Trending market condition we will hendel here");
}



//+------------------------------------------------------------------+
void HandleRangingState(SymbolData *sd, double ask, double bid, double point, double spread, double riskAmount, double &lotSize) {
      Print("Ranging market condition we will hendel here");
}

//+------------------------------------------------------------------+

string RsiSignal(SymbolData *sd) {
   //default buy 70 ,sell 30
   if( sd.rsi[0] < RSILowerLevel
      ) {
      return "BUY";
   } else if( sd.rsi[0] > RSIUpperLevel
      ) {
      return "SELL";
   }else{
      return "NoTrade";
   }
}
string AdxRangeSignal(SymbolData *sd) {
   //default buy 70 ,sell 30
   if( sd.adx[0] < ADXTradeValue
      ) {
      return "Go";
   }else{
      return "Wait";
   }
}

//+------------------------------------------------------------------+
void ManageExits(SymbolData *sd, double ask, double bid, double point) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != sd.symbol) 
         continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);
      double size = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double atrBuffer = sd.atr[0] * 0.5; // Wider buffer for trends
      double atr = sd.atr[0];  // Always use current ATR
      double spread = SymbolInfoInteger(sd.symbol, SYMBOL_SPREAD) * point;
      string symbol = PositionGetString(POSITION_SYMBOL);
          
          
            
      // 1. Squeeze Trade Exits (mean-reversion)
      if(StringFind(comment, "Range") != -1) {
         Print("range exit logic will go here");
      }
      
      if (StringFind(comment, "Trend") != -1) {
         Print("Trend exit logic will go here");
            

         }//end of trend

      
      
    }//for close
      
      
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res) {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD &&
      (trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)) {

      string sym = trans.symbol;
      double profit = 0;
      datetime closeTime = TimeCurrent();

      datetime now = TimeCurrent();
      HistorySelect(now - 60, now + 60);

      ulong ticket = trans.deal;
      if(ticket > 0 && HistoryDealSelect(ticket)) {
         profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      }

      reportManager.UpdateReport(sym, profit, closeTime);
   }
}
