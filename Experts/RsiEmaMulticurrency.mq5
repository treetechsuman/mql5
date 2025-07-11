//+------------------------------------------------------------------+
//| Expert Advisor: RSI + EMA Breakout with Smart Filters (MQL5)   |
//| Added: Trend Filter, ATR filter, RSI delta, Candle confirmation|
//| Now Includes: Trailing Stop + Breakeven Exit + RSI Exit        |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input string SymbolsList     = "EURUSD,GBPUSD";
input int    rsiPeriod       = 14;
input int    fastEMAPeriod   = 20;
input int    slowEMAPeriod   = 50;
input int    trendEMAPeriod  = 200;
input int    atrPeriod       = 14;
input double atrMultiplierSL = 1.5;
input double atrMultiplierTP = 2.0;
input double rsiBuyLevel     = 30;
input double rsiSellLevel    = 70;
input double rsiDeltaMin     = 3.0;
input double atrMinThreshold = 0.0005;
input double candleMinSize   = 50;
input double riskPercent     = 1.0;
input int    tradeStartHour  = 8;
input int    tradeEndHour    = 20;
input int    cooldownBars    = 1;
input bool   enableAlerts    = true;
input bool   enableEmail     = false;
input bool   skipTradingToday = false;
input bool   useTrailingStop = true;
input double trailingStart   = 20;
input double trailingStep    = 10;
input bool   useBreakEven    = true;
input double breakEvenTrigger= 25;

string symbolsRaw[];
datetime lastTradeTimeMap[];

int OnInit() {
   StringSplit(SymbolsList, ',', symbolsRaw);
   ArrayResize(lastTradeTimeMap, ArraySize(symbolsRaw));
   for (int i = 0; i < ArraySize(symbolsRaw); i++) lastTradeTimeMap[i] = 0;
   return INIT_SUCCEEDED;
}

int tradesToday = 0;
void OnTick() {
   if (skipTradingToday) return;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   static int currentDay = -1;
   if (dt.day != currentDay) {
      tradesToday = 0;
      currentDay = dt.day;
   }
   if (dt.hour < tradeStartHour || dt.hour >= tradeEndHour) return;

   for (int i = 0; i < ArraySize(symbolsRaw); i++) {
      if (TimeCurrent() - lastTradeTimeMap[i] < cooldownBars * PeriodSeconds(PERIOD_CURRENT)) continue;
      string symbol = symbolsRaw[i];
      StringTrimLeft(symbol); StringTrimRight(symbol);
      if (!SymbolSelect(symbol, true)) continue;

      if (PositionSelect(symbol)) {
         ManageOpenPosition(symbol);
         continue;
      }

      double emaBuf[], atrBuf[], rsiBuf[];
      if (!CopyBuffer(iMA(symbol, PERIOD_CURRENT, trendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 1, emaBuf)) {
   Print(symbol, ": Failed to get EMA buffer");
   continue;
}
      if (!CopyBuffer(iATR(symbol, PERIOD_CURRENT, atrPeriod), 0, 0, 1, atrBuf)) {
   Print(symbol, ": Failed to get ATR buffer");
   continue;
}
      if (!CopyBuffer(iRSI(symbol, PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE), 0, 0, 1, rsiBuf)) {
   Print(symbol, ": Failed to get RSI buffer");
   continue;
}

      double ema = emaBuf[0];
      double atr = atrBuf[0];
      double rsi = rsiBuf[0];
      double close = iClose(symbol, PERIOD_CURRENT, 0);
      double open = iOpen(symbol, PERIOD_CURRENT, 0);
      double volume = iVolume(symbol, PERIOD_CURRENT, 0);

      if (atr < atrMinThreshold || tradesToday >= 3 || volume < 1) {
   Print(symbol, ": Skipped - ATR=", atr, ", TradesToday=", tradesToday, ", Volume=", volume);
   continue;
}

      int adxHandle = iADX(symbol, PERIOD_CURRENT, 14);
      if (adxHandle == INVALID_HANDLE) {
   Print(symbol, ": ADX handle invalid");
   continue;
}
      double adxBuf[];
      if (!CopyBuffer(adxHandle, 0, 0, 1, adxBuf)) {
   Print(symbol, ": Failed to get ADX buffer");
   continue;
}
      double adx = adxBuf[0];
      if (adx < 15) {
   Print(symbol, ": Skipped - ADX too low: ", adx);
   continue;
}

      // Pullback strategy
      if (close > ema && rsi > 50 && open < close) {
   Print(symbol, ": BUY conditions met — Close=", close, " EMA=", ema, " RSI=", rsi);
         Print(symbol, ": TRY BUY — Lot=", CalculateLotSize(symbol, atr), " ATR=", atr);
         if (OpenTrade(symbol, ORDER_TYPE_BUY, atr)) {
            lastTradeTimeMap[i] = TimeCurrent();
            tradesToday++;
         }
      }
      
      else if (close < ema && rsi < 50 && open > close) {
   Print(symbol, ": SELL conditions met — Close=", close, " EMA=", ema, " RSI=", rsi);
         Print(symbol, ": TRY SELL — Lot=", CalculateLotSize(symbol, atr), " ATR=", atr);
         if (OpenTrade(symbol, ORDER_TYPE_SELL, atr)) {
            lastTradeTimeMap[i] = TimeCurrent();
            tradesToday++;
   }
}
   }
}

bool OpenTrade(string symbol, int orderType, double atr) {
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   double rawSL = atr * atrMultiplierSL;
   double minSLPips = 10;
   double minSL = minSLPips * _Point;
   double slDist = MathMax(rawSL, minSL);

   double sl = (orderType == ORDER_TYPE_BUY) ? price - slDist : price + slDist;
   double tp = (orderType == ORDER_TYPE_BUY) ? price + atr * atrMultiplierTP : price - atr * atrMultiplierTP;

   double lot = CalculateLotSize(symbol, MathAbs(price - sl));
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if (lot < minLot) {
      Print(symbol, ": Lot too small (", lot, ") < Min (", minLot, ") — SL distance too narrow? Risk too low?");
      return false;
   }

   trade.SetExpertMagicNumber(123456);
   bool result = (orderType == ORDER_TYPE_BUY) ?
                 trade.Buy(lot, symbol, price, sl, tp) :
                 trade.Sell(lot, symbol, price, sl, tp);

   if (result && enableAlerts)
      Alert("Trade opened: ", symbol, (orderType == ORDER_TYPE_BUY ? " BUY" : " SELL"));
   if (result && enableEmail)
      SendMail("Trade Alert", symbol + ((orderType == ORDER_TYPE_BUY) ? " BUY" : " SELL") + " opened.");
   return result;
}

void ManageOpenPosition(string symbol) {
   if (!PositionSelect(symbol)) return;

   static datetime entryTime = 0;
   int posType = (int)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = (posType == POSITION_TYPE_BUY)
                         ? SymbolInfoDouble(symbol, SYMBOL_BID)
                         : SymbolInfoDouble(symbol, SYMBOL_ASK);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double distance = MathAbs(currentPrice - openPrice) / _Point;
   double newSL = sl;

   if (entryTime == 0)
      entryTime = PositionGetInteger(POSITION_TIME);

   double rsiBuf[];
   if (CopyBuffer(iRSI(symbol, PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE), 0, 0, 1, rsiBuf) && ArraySize(rsiBuf) > 0) {
      double rsiNow = rsiBuf[0];
      int holdBars = (int)((TimeCurrent() - entryTime) / PeriodSeconds(PERIOD_CURRENT));

      if (holdBars >= 5) {
         if ((posType == POSITION_TYPE_BUY && rsiNow < 45) ||
             (posType == POSITION_TYPE_SELL && rsiNow > 55)) {
            trade.PositionClose(symbol);
            entryTime = 0;
            return;
         }

         if (useBreakEven && distance >= breakEvenTrigger)
            newSL = openPrice;

         if (useTrailingStop && distance >= trailingStart) {
            if (posType == POSITION_TYPE_BUY)
               newSL = currentPrice - trailingStep * _Point;
            else
               newSL = currentPrice + trailingStep * _Point;
         }

         if (MathAbs(newSL - sl) > _Point * 2) {
            trade.PositionModify(symbol, NormalizeDouble(newSL, _Digits), tp);
         }
      }
   }
}

double CalculateLotSize(string symbol, double slPoints) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk = balance * riskPercent / 100.0;
   double tickValue, tickSize, contractSize;
   SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE, tickValue);
   SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tickSize);
   SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE, contractSize);

   if (tickSize == 0 || tickValue == 0 || slPoints == 0) return 0;

   double valuePerPoint = tickValue / tickSize;
   double costPerLot = slPoints * valuePerPoint;
   if (costPerLot == 0) return 0;

   double lotSize = risk / costPerLot;
   lotSize = NormalizeDouble(lotSize, 2);

   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathMax(minLot, MathMin(maxLot, MathFloor(lotSize / stepLot) * stepLot));
   return lotSize;
}
