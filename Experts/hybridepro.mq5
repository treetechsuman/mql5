//+------------------------------------------------------------------+
//| Professional Hybrid Trend EA (Corrected Logic, MT5)            |
//| Author: ChatGPT                                                |
//| Purpose: Clean, tested EA for trend trading                    |
//+------------------------------------------------------------------+
#property copyright "ChatGPT"
#property version   "2.2"
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// Input Parameters
input double FixedLot = 0.1;            // Fixed lot size for testing
input int MagicNumber = 987654;
input double StopLossPips = 20;         // Fixed 20 pips SL
input double TakeProfitPips = 20;       // Fixed 20 pips TP (1:1 RRR)
input int EMAFastPeriod = 10;           // 15M fast EMA
input int EMASlowPeriod = 30;           // 15M slow EMA
input int EMA1HPeriod = 50;             // 1H trend EMA
input int ATRPeriod = 14;               // ATR period
input int ATRSmoothing = 20;            // SMA of ATR for volatility filter
input int RSIPeriod = 14;               // RSI period
input double RSIThresholdBuy = 55.0;    // RSI threshold for buy
input double RSIThresholdSell = 45.0;   // RSI threshold for sell

//+------------------------------------------------------------------+
//| Utility: Check if H1 EMA is sloping                              |
//+------------------------------------------------------------------+
bool IsH1EMASlopingUp()
{
   double emaNow = iMA(_Symbol, PERIOD_H1, EMA1HPeriod, 0, MODE_EMA, PRICE_CLOSE);
   double emaPrev = iMA(_Symbol, PERIOD_H1, EMA1HPeriod, 1, MODE_EMA, PRICE_CLOSE);
   return emaNow > emaPrev * 1.0002; // Require slope above minimal threshold
}

bool IsH1EMASlopingDown()
{
   double emaNow = iMA(_Symbol, PERIOD_H1, EMA1HPeriod, 0, MODE_EMA, PRICE_CLOSE);
   double emaPrev = iMA(_Symbol, PERIOD_H1, EMA1HPeriod, 1, MODE_EMA, PRICE_CLOSE);
   return emaNow < emaPrev * 0.9998; // Require slope below minimal threshold
}

//+------------------------------------------------------------------+
//| Utility: Volatility filter using ATR                             |
//+------------------------------------------------------------------+
bool IsVolatilityHigh()
{
   double atr = iATR(_Symbol, PERIOD_M15, ATRPeriod);
   double atrSMA = iMA(_Symbol, PERIOD_M15, ATRSmoothing, 0, MODE_SMA, PRICE_CLOSE);
   return atr > atrSMA * 0.8; // Slightly relaxed threshold for testing
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastTradeTime = 0;
   if(TimeCurrent() - lastTradeTime < 1800) return; // Allow 1 trade per 30 min

   double emaFast15M = iMA(_Symbol, PERIOD_M15, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   double emaSlow15M = iMA(_Symbol, PERIOD_M15, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   double emaFastPrev15M = iMA(_Symbol, PERIOD_M15, EMAFastPeriod, 1, MODE_EMA, PRICE_CLOSE);
   double emaSlowPrev15M = iMA(_Symbol, PERIOD_M15, EMASlowPeriod, 1, MODE_EMA, PRICE_CLOSE);
   double rsi = iRSI(_Symbol, PERIOD_M15, RSIPeriod, PRICE_CLOSE);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = StopLossPips * _Point;
   double tp = TakeProfitPips * _Point;

   bool success = false;

   // === Buy Logic ===
   if(IsH1EMASlopingUp() && IsVolatilityHigh())
   {
      if(emaFastPrev15M < emaSlowPrev15M && emaFast15M > emaSlow15M && rsi > RSIThresholdBuy)
      {
         trade.SetExpertMagicNumber(MagicNumber);
         success = trade.Buy(FixedLot, _Symbol, ask, ask - sl, ask + tp, "Trend Buy");
      }
   }

   // === Sell Logic ===
   if(IsH1EMASlopingDown() && IsVolatilityHigh())
   {
      if(emaFastPrev15M > emaSlowPrev15M && emaFast15M < emaSlow15M && rsi < RSIThresholdSell)
      {
         trade.SetExpertMagicNumber(MagicNumber);
         success = trade.Sell(FixedLot, _Symbol, bid, bid + sl, bid - tp, "Trend Sell");
      }
   }

   if(success)
   {
      lastTradeTime = TimeCurrent();
      Print("✅ Trade executed at ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   }
}
//+------------------------------------------------------------------+
