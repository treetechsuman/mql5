//+------------------------------------------------------------------+
//|                     Multi-Currency RSI Trend EA                  |
//|           Backtest-Ready with Symbol Info Display on Chart      |
//+------------------------------------------------------------------+
#property strict

datetime lastBarTime[];
#include <Trade/Trade.mqh>
#include <ChartObjects/ChartObjectsTxtControls.mqh>
CTrade trade;

input string SymbolsList = "EURUSD,AUDUSD,GBPUSD,USDJPY";//"EURUSD,GBPUSD,USDJPY,EURJPY";

input int MinVolumeThreshold = 100; 
input ENUM_TIMEFRAMES Timeframe = PERIOD_M5;
input int RSI_Period=       7;
input int Rsi_BuyLevel = 30;
input int Rsi_SellLevel = 70;
input int EMA_Period=       20;
input double ATRMultiplierSL=   1.5;
input double ATRMultiplierTP=   1.5;
input int Atr_Period = 7;
input double RiskPercent =       0.5;
input int MACDFastEMA=      6;
input int MACDSlowEMA=       13;
input int MACDSignalSMA=     5;
input bool UseMACDFilter=     true;
input bool UseRSIFilter=      true;
input bool RequireBothSignals = false;

string symbolsRaw[];

input int SessionStartHour = 6;
input int SessionEndHour = 20;

int OnInit() {
   StringSplit(SymbolsList, ',', symbolsRaw);
   ArrayResize(lastBarTime, ArraySize(symbolsRaw));
   return INIT_SUCCEEDED;
}

void OnTick() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   if (hour < SessionStartHour || hour > SessionEndHour) return;

   for (int i = 0; i < ArraySize(symbolsRaw); i++) {
      MqlRates volRates[];
      if (CopyRates(symbolsRaw[i], Timeframe, 0, 3, volRates) < 3) continue;
      if (volRates[1].tick_volume < MinVolumeThreshold) continue;
      string symbol = symbolsRaw[i];
      if (!SymbolSelect(symbol, true)) continue;
      MqlRates rates[];
      if (CopyRates(symbol, Timeframe, 0, 3, rates) < 3) continue;

      int rsiHandle = iRSI(symbol, Timeframe, RSI_Period, PRICE_CLOSE);
      int emaHandle = iMA(symbol, Timeframe, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      int atrHandle = iATR(symbol, Timeframe, Atr_Period);

      if (rsiHandle == INVALID_HANDLE || emaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE) continue;

      double rsi[], ema[3], atr[];
      if (CopyBuffer(rsiHandle, 0, 0, 2, rsi) != 2) continue;
      if (CopyBuffer(emaHandle, 0, 0, 3, ema) != 3) continue;
      if (CopyBuffer(atrHandle, 0, 0, 2, atr) != 2) continue;

      double macdMain[2], macdSignal[2];
      bool macdUp = true, macdDown = true;

      if (UseMACDFilter) {
         int macdHandle = iMACD(symbol, Timeframe, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE);
         if (macdHandle == INVALID_HANDLE) continue;
         if (CopyBuffer(macdHandle, 0, 0, 2, macdMain) != 2 || CopyBuffer(macdHandle, 1, 0, 2, macdSignal) != 2) continue;
         macdUp = macdMain[1] > macdSignal[1];
         macdDown = macdMain[1] < macdSignal[1];
      }

      bool trendUp = rates[1].close > ema[1] && ema[1] > ema[2];
      bool trendDown = rates[1].close < ema[1] && ema[1] < ema[2];

      bool isNewBar = (lastBarTime[i] != rates[1].time);
      if (isNewBar) {
         lastBarTime[i] = rates[1].time;
         if (PositionSelect(symbol)) continue;

         bool rsiBuyOk = !UseRSIFilter || rsi[1] < Rsi_BuyLevel;
         bool rsiSellOk = !UseRSIFilter || rsi[1] > Rsi_SellLevel;
         bool macdBuyOk = !UseMACDFilter || macdUp;
         bool macdSellOk = !UseMACDFilter || macdDown;

         bool buySignal = RequireBothSignals ? (rsiBuyOk && macdBuyOk) : (rsiBuyOk || macdBuyOk);
         bool sellSignal = RequireBothSignals ? (rsiSellOk && macdSellOk) : (rsiSellOk || macdSellOk);

         bool buyCondition = trendUp && buySignal;
         bool sellCondition = trendDown && sellSignal;

         if (buyCondition) OpenTrade(symbol, ORDER_TYPE_BUY, SymbolInfoDouble(symbol, SYMBOL_ASK), atr[1]);
         else if (sellCondition) OpenTrade(symbol, ORDER_TYPE_SELL, SymbolInfoDouble(symbol, SYMBOL_BID), atr[1]);
      }
   }
}
// Rest of the code remains unchanged


void OpenTrade(string symbol, ENUM_ORDER_TYPE type, double price, double atr) {
   double sl = (type == ORDER_TYPE_BUY) ? price - atr * ATRMultiplierSL : price + atr * ATRMultiplierSL;
   double tp = (type == ORDER_TYPE_BUY) ? price + atr * ATRMultiplierTP : price - atr * ATRMultiplierTP;
   double lotSize = CalculateLotSize(symbol, RiskPercent, atr);

   trade.SetExpertMagicNumber(1001);

   bool result = false;
   if (type == ORDER_TYPE_BUY)
      result = trade.Buy(lotSize, symbol, price, sl, tp);
   else
      result = trade.Sell(lotSize, symbol, price, sl, tp);

   if (result)
      Print(symbol, ": Trade opened ", EnumToString(type), " Lot: ", lotSize);
   else
      Print(symbol, ": Trade failed. Error: ", GetLastError());
}

double CalculateLotSize(string symbol, double riskPercent, double atr) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   if (tickValue <= 0 || tickSize <= 0 || atr <= 0) return 0.01;
   double pipValue = (tickValue / tickSize) * 10; // Approximate pip value
   double stopLossPips = atr * 10;

   double lot = NormalizeDouble(riskAmount / (stopLossPips * pipValue), 2);
   return MathMax(lot, 0.01);
}

string EnumToString(ENUM_ORDER_TYPE type) {
   if (type == ORDER_TYPE_BUY) return "BUY";
   if (type == ORDER_TYPE_SELL) return "SELL";
   return "UNKNOWN";
}

void OnDeinit(const int reason) {
   if (MQLInfoInteger(MQL_TESTER)) {
      Print("Logging backtest results...");
      for (int i = 0; i < ArraySize(symbolsRaw); i++) {
         string s = symbolsRaw[i];
         double profit = 0.0;
         double maxDrawdown = 0.0;
         int totalDeals = HistoryDealsTotal();
         string fileName = "Backtest_Results.csv";

         if (i == 0 && FileIsExist(fileName)) {
            string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
            string archiveName = "Backtest_Results_" + StringReplace(timestamp, ":", "-") + ".csv";
            FileCopy(fileName, FILE_COMMON, archiveName, FILE_COMMON);
            FileDelete(fileName);
         }

         int handle = FileOpen(fileName, FILE_CSV | FILE_WRITE | FILE_COMMON | FILE_ANSI);
         if (handle != INVALID_HANDLE && i == 0) {
            FileSeek(handle, 0, SEEK_SET);
            FileWrite(handle, "Symbol", "NetProfit", "TotalTrades", "MaxDrawdown", "WinRate(%)", "ProfitFactor", "Timestamp");
            Print("Symbol, NetProfit, TotalTrades, MaxDrawdown, WinRate(%), ProfitFactor, Timestamp");
         }

         if (handle != INVALID_HANDLE) {
            FileSeek(handle, 0, SEEK_END);
            int trades = 0;
            double maxEquity = 0, maxLoss = 0;
            double equity = 0;

            for (int d = totalDeals - 1; d >= 0; d--) {
               ulong ticket = HistoryDealGetTicket(d);
               if (HistoryDealGetString(ticket, DEAL_SYMBOL) == s) {
                  double p = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                  profit += p;
                  equity += p;
                  trades++;
                  if (equity > maxEquity) maxEquity = equity;
                  double drawdown = maxEquity - equity;
                  if (drawdown > maxLoss) maxLoss = drawdown;
               }
            }

            double wins = 0, losses = 0;
            for (int d = totalDeals - 1; d >= 0; d--) {
               ulong ticket = HistoryDealGetTicket(d);
               if (HistoryDealGetString(ticket, DEAL_SYMBOL) == s) {
                  double p = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                  if (p > 0) wins++;
                  else if (p < 0) losses++;
               }
            }

            double winRate = (trades > 0) ? (wins / trades) * 100.0 : 0.0;
            double pf = (losses == 0) ? wins : (profit / MathAbs(profit - (wins - trades)));
            string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
            FileWrite(handle, s, profit, trades, maxLoss, winRate, pf, ts);
            Print(s, ", ", profit, ", ", trades, ", ", maxLoss, ", ", winRate, ", ", pf, ", ", ts);
            FileClose(handle);
         } else {
            Print("[Error] Could not open file for logging: ", GetLastError());
         }
      }
   }
}
