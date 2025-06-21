//+------------------------------------------------------------------+
//|                                                  AdaptiveBB.mq5  |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh> // Required for CArrayObj
#include "Modules/InfoDashboard.mqh"
#include "Modules/SymbolReport.mqh"
#include "Modules/Utils.mqh"
#include "Modules/SymbolManager.mqh"

// Input parameters
input string   Symbols        = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,NZDUSD"; // Comma-separated symbols
input ENUM_TIMEFRAMES Timeframe    = PERIOD_H1;
input double   RiskPercent    = 1.0;             // Risk per trade (% of balance)
input int      BBPeriod       = 20;              // Bollinger Bands period
input double   BBDeviation    = 2.0;             // Bollinger Bands deviation
input int      BBEntryDeviation = 2;
input int      BBProfitExitDeviation = 1;
input int      BBLossExitDeviation = 6;

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
   int fastMaHandle, slowMaHandle,rsiHandle, bbEntryHandle,bbProfitExitHandle,bbLossExitHandle, adxHandle, atrHandle;
   double fastMa[],slowMa[],atr[], upperLossExitBand[], lowerLossExitBand[], upperProfitExitBand[],lowerProfitExitBand[], upperEntryBand[],lowerEntryBand[], middleBand[], rsi[], adx[], plusDI[], minusDI[];
   long volumes[];
   datetime lastTradeTime;
   MqlRates priceData[];

   bool Init(string sym) {
      symbol = sym;
      rsiHandle = iRSI(symbol, Timeframe, RSIPeriod, PRICE_CLOSE);
      bbEntryHandle = iBands(symbol, Timeframe, BBPeriod, 0, BBEntryDeviation, PRICE_CLOSE);
      bbProfitExitHandle = iBands(symbol, Timeframe, BBPeriod, 0, BBProfitExitDeviation, PRICE_CLOSE);
      bbLossExitHandle = iBands(symbol, Timeframe, BBPeriod, 0, BBLossExitDeviation, PRICE_CLOSE);
      adxHandle = iADX(symbol, Timeframe, ADXPeriod);
      atrHandle = iATR(symbol,Timeframe,20);
      fastMaHandle = iMA(symbol,Timeframe,fastMaPeriod,0,MODE_EMA,PRICE_CLOSE);
      slowMaHandle = iMA(symbol,Timeframe,slowMaPeriod,0,MODE_EMA,PRICE_CLOSE);

      ArraySetAsSeries(upperEntryBand, true);
      ArraySetAsSeries(middleBand, true);
      ArraySetAsSeries(lowerEntryBand, true);
      ArraySetAsSeries(upperProfitExitBand, true);
      ArraySetAsSeries(lowerProfitExitBand, true);
      ArraySetAsSeries(upperLossExitBand, true);
      ArraySetAsSeries(lowerLossExitBand, true);
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(adx, true);
      ArraySetAsSeries(plusDI, true);
      ArraySetAsSeries(minusDI, true);
      ArraySetAsSeries(volumes, true);
      ArraySetAsSeries(priceData, true);
      ArraySetAsSeries(slowMa, true);
      ArraySetAsSeries(fastMa, true);
      return (rsiHandle != INVALID_HANDLE && bbEntryHandle != INVALID_HANDLE &&bbProfitExitHandle != INVALID_HANDLE &&bbLossExitHandle != INVALID_HANDLE && adxHandle != INVALID_HANDLE);
   }
};

CArrayObj contexts;
CTrade trade;
string   tradeSymbols[];
datetime lastTradeTime[];
string Rows[] = {"MarketSignal", "CandelSignal", "RsiSignal","ADX Confirmation", "Symbol"};
CSymbolReportManager reportManager;
SymbolManager sm;
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
   
   //string symbols[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF"};
   sm.Init(list, Timeframe);
   sm.PrepareSymbols();
   return INIT_SUCCEEDED;
  
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   for(int i = 0; i < contexts.Total(); i++) {
      SymbolData *sd = (SymbolData*)contexts.At(i);
      IndicatorRelease(sd.rsiHandle);
      IndicatorRelease(sd.bbEntryHandle);
      IndicatorRelease(sd.bbProfitExitHandle);
      IndicatorRelease(sd.bbLossExitHandle);
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
      if(reportManager.HasReport("EURUSD")) {
         CSymbolReportData *data = reportManager.GetReport(symbol);
         //Print("Win Rate: ", data.WinRate(), "%");
         symbolReport = "Trade:";// + DoubleToString(data.WinRate(), 2);  // 2 = number of decimals;
         
      }
      string marketSignal = GetMarketState(sd);
      string candleSignal = CandelSignal(sd);
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
   CopyBuffer(sd.bbEntryHandle, 1, 0, VolLookback, sd.upperEntryBand);
   CopyBuffer(sd.bbEntryHandle, 0, 0, VolLookback, sd.middleBand);
   CopyBuffer(sd.bbEntryHandle, 2, 0, VolLookback, sd.lowerEntryBand);
   CopyBuffer(sd.bbProfitExitHandle, 1, 0, VolLookback, sd.upperProfitExitBand);
   CopyBuffer(sd.bbProfitExitHandle, 2, 0, VolLookback, sd.lowerProfitExitBand);
    CopyBuffer(sd.bbLossExitHandle, 1, 0, VolLookback, sd.upperLossExitBand);
   CopyBuffer(sd.bbLossExitHandle, 2, 0, VolLookback, sd.lowerLossExitBand);
   
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
      //HandleTrendingState(sd, ask, bid, point, spread, riskAmount, lotSize);
      //HandleRangingState(sd, ask, bid, point, spread, riskAmount, lotSize);
   }
   if(marketState=="Ranging") {
      HandleRangingState(sd, ask, bid, point, spread, riskAmount, lotSize);
   }
      

   ManageExits(sd, ask, bid, point);
}


string GetMarketState(SymbolData *sd) {
   // === Trending Detection with ADX Buffer ===
   double adx = sd.adx[0];
   double plusDI = sd.plusDI[0];
   double minusDI = sd.minusDI[0];
   double price = sd.priceData[0].close;
   double midBand = sd.middleBand[0];
   double atr = sd.atr[0];  // assume you're storing ATR per symbol in sd 
   if(adx > (ADXTradeValue+2)) {
      if(plusDI > minusDI && price > midBand) return "Trending";
      if(minusDI > plusDI && price < midBand) return "Trending";
   }

   // === Ranging Detection with ATR-based Band Stability ===
   if(adx < (ADXTradeValue-2)&&
      MathAbs(sd.upperEntryBand[0] - sd.upperEntryBand[1]) < atr * 0.1 &&
      MathAbs(sd.lowerEntryBand[0] - sd.lowerEntryBand[1]) < atr * 0.1)
      return "Ranging";
      

   // === Neutral fallback ===
   return "Neutral";
}

bool IsTradingHour() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= 12 && dt.hour < 17);
}
//+------------------------------------------------------------------+
void HandleTrendingState(
    SymbolData *sd, double ask, double bid, double point, 
    double spread, double riskAmount, double &lotSize
) {
    // 1. Trend Direction Check (using EMA slope)
    bool isUptrend = sd.middleBand[0] > sd.middleBand[1] && sd.middleBand[1] > sd.middleBand[2];
    bool isDowntrend = sd.middleBand[0] < sd.middleBand[1] && sd.middleBand[1] < sd.middleBand[2];
    
    // 2. Buy Setup (Uptrend Pullback)
    if(isUptrend && sd.priceData[1].close > sd.middleBand[1]) {
        bool isPullback = sd.priceData[1].low <= sd.middleBand[1]; // Valid pullback
        bool isBullishConfirmation = ask > sd.middleBand[0];       // Price above MA
        
        if(isPullback && isBullishConfirmation && sd.rsi[0] > 40) { // RSI filter
            // Dynamic SL: Lower Bollinger Band (adjusts to volatility)
            double sl = sd.lowerEntryBand[0] - spread;
            double riskPoints = MathMax((ask - sl) / point, 10.0); // Avoid zero/negative
            lotSize = NormalizeDouble(riskAmount / riskPoints, 2);
            
            if(lotSize > 0) trade.Buy(lotSize, sd.symbol, ask, sl, 0, "BB-Trend-Bull");
        }
    }
    // 3. Sell Setup (Downtrend Pullback)
    else if(isDowntrend && sd.priceData[1].close < sd.middleBand[1]) {
        bool isPullback = sd.priceData[1].high >= sd.middleBand[1]; // Valid pullback
        bool isBearishConfirmation = bid < sd.middleBand[0];        // Price below MA
        
        if(isPullback && isBearishConfirmation && sd.rsi[0] < 60) { // RSI filter
            // Dynamic SL: Upper Bollinger Band (adjusts to volatility)
            double sl = sd.upperEntryBand[0] + spread;
            double riskPoints = MathMax((sl - bid) / point, 10.0);
            lotSize = NormalizeDouble(riskAmount / riskPoints, 2);
            
            if(lotSize > 0) trade.Sell(lotSize, sd.symbol, bid, sl, 0, "BB-Trend-Bear");
        }
    }
}
void HandleMaTrendingState(
    SymbolData *sd, double ask, double bid, double point, 
    double spread, double riskAmount, double &lotSize
) {
    // 1. Trend Direction Check (using EMA slope)
    bool isUptrend = sd.middleBand[0] > sd.middleBand[1] && sd.middleBand[1] > sd.middleBand[2];
    bool isDowntrend = sd.middleBand[0] < sd.middleBand[1] && sd.middleBand[1] < sd.middleBand[2];
    bool isFastCrossOverAbove = sd.fastMa[1] > sd.slowMa[1]&&sd.fastMa[2]<sd.slowMa[2]; 
    bool isFastCrossOverBellow = sd.fastMa[1] < sd.slowMa[1]&&sd.fastMa[2]>sd.slowMa[2]; 
    // 2. Buy Setup (Uptrend Pullback)
    if(isUptrend&&!IsTradeOpen(sd.symbol)) {
        
        
        if(isUptrend && isFastCrossOverAbove) { // RSI filter
            // Dynamic SL: Lower Bollinger Band (adjusts to volatility)
            double sl = sd.lowerEntryBand[0] - spread;
            double riskPoints = MathMax((ask - sl) / point, 10.0); // Avoid zero/negative
            lotSize = NormalizeDouble(riskAmount / riskPoints, 2);
            
            if(lotSize > 0) trade.Buy(lotSize, sd.symbol, ask, sl, 0, "BB-maT-Bull");
        }
    }
    // 3. Sell Setup (Downtrend Pullback)
    else if(isDowntrend&&!IsTradeOpen(sd.symbol)) {
        
        if(isDowntrend && isFastCrossOverBellow) { // RSI filter
            // Dynamic SL: Upper Bollinger Band (adjusts to volatility)
            double sl = sd.upperEntryBand[0] + spread;
            double riskPoints = MathMax((sl - bid) / point, 10.0);
            lotSize = NormalizeDouble(riskAmount / riskPoints, 2);
            
            if(lotSize > 0) trade.Sell(lotSize, sd.symbol, bid, sl, 0, "BB-maT-Bear");
        }
    }
}


//+------------------------------------------------------------------+
void HandleRangingState(SymbolData *sd, double ask, double bid, double point, double spread, double riskAmount, double &lotSize) {
      string marketSignal = GetMarketState(sd);
      string candleSignal = CandelSignal(sd);
      string rsiSignal = RsiSignal(sd);
   if(
      candleSignal=="SELL"
      &&rsiSignal =="SELL"
      &&IsTradingHour()) {
      double sl = sd.upperLossExitBand[0] + 1*point + spread;
      //double sl = sd.priceData[1].high+10*point+spread;
      
      lotSize = NormalizeDouble(riskAmount / ((sl - bid) / point), 2);
      Print("stoploss",sl);
      Print("lotSize",lotSize);
      if(lotSize > 0) trade.Sell(lotSize, sd.symbol, bid, sl, sd.lowerProfitExitBand[0], "BB-Range-Short");
   }
   if(
      candleSignal=="BUY"
      &&rsiSignal =="BUY"
      &&IsTradingHour()
      ) {
      double sl = sd.lowerLossExitBand[0] - 1*point - spread;
      //double sl = sd.priceData[1].low-10*point-spread;
      
      lotSize = NormalizeDouble(riskAmount / ((ask - sl) / point), 2);
      Print("stoploss",sl);
      Print("lotSize",lotSize);
      if(lotSize > 0) trade.Buy(lotSize, sd.symbol, ask, sl, sd.upperProfitExitBand[0], "BB-Range-Long");
   }
}

//+------------------------------------------------------------------+
string CandelSignal(SymbolData *sd) {
   //default buy 70 ,sell 30
   if(//price cross above the lower entry bb band
      sd.priceData[1].open <= sd.lowerEntryBand[1] 
      &&sd.priceData[1].close >= sd.lowerEntryBand[1] 
      //&& sd.rsi[0] > 40
      ) {
      return "BUY";
   } else if(//price cross below the upper entry bb band
      sd.priceData[1].open >= sd.upperEntryBand[1]
      &&sd.priceData[1].close <= sd.upperEntryBand[1] 
      //&& sd.rsi[0] < 40
      ) {
      return "SELL";
   }else{
      return "NoTrade";
   }
}
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
      double positionTakeProfit = PositionGetDouble(POSITION_TP);
      double postionStopLoss = PositionGetDouble(POSITION_SL);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double atrBuffer = sd.atr[0] * 0.5; // Wider buffer for trends
      
      int digits = (int)SymbolInfoInteger(sd.symbol, SYMBOL_DIGITS);
      double pipSize = (digits == 3 || digits == 5) ? 10 * _Point : _Point;

     
      double optimalTakeProfit;
      // 2. Trend Trade Exits (momentum-based)
       if(StringFind(comment, "Range") != -1) {
         
         if(type == POSITION_TYPE_BUY) {
             optimalTakeProfit = NormalizeDouble(sd.upperProfitExitBand[0],digits);
             
         }
         else {
             optimalTakeProfit = NormalizeDouble(sd.lowerProfitExitBand[0],digits);
         }
         double tPDistance = MathAbs(positionTakeProfit - optimalTakeProfit) / pipSize;
          double diffBtntakeProfitAndEntryPrice=MathAbs(entryPrice-optimalTakeProfit)/pipSize;
          Print("tpDistance",tPDistance);
          if(
            positionTakeProfit!=optimalTakeProfit
            &&tPDistance>=5
            &&diffBtntakeProfitAndEntryPrice>=15
            
            ) {
               Print("tpDistance",tPDistance);
               Print("DiffBetnTakeProfit and entry",diffBtntakeProfitAndEntryPrice);
              if(trade.PositionModify(ticket,postionStopLoss ,optimalTakeProfit)){
               Print("position modified");
              }
              
              //trade.PositionClosePartial(ticket, NormalizeDouble(closeSize, 2));
          }
      }
   }
}
double GetPipValue(string symbol) {
   double lotSize = 1.0;
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipSize   = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || 
                       SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5) 
                       ? 10 * SymbolInfoDouble(symbol, SYMBOL_POINT)
                       : SymbolInfoDouble(symbol, SYMBOL_POINT);
   return (tickValue / tickSize) * pipSize;
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
