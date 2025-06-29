#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

input string   SymbolsList        = "EURUSD,GBPUSD,USDJPY";
input int      RangeBars          = 3;
input double   LotSize            = 0.1;
input int      Slippage           = 10;
input double   SL_Pips            = 20;
input double   RiskRewardRatio    = 2.0;
input int      MagicNumber        = 123456;
input int      TradingStartHour   = 8;
input int      TradingEndHour     = 18;
input int      ExpireAfterBars    = 2;
input int      MaxTradesPerSymbol = 3;

string symbolsRaw[];
datetime lastCandleTime[];
datetime lastOrderTime[];
CTrade trade;

int OnInit()
{
   StringSplit(SymbolsList, ',', symbolsRaw);
   ArrayResize(lastOrderTime, ArraySize(symbolsRaw));
   ArrayResize(lastCandleTime, ArraySize(symbolsRaw));
   ArrayInitialize(lastOrderTime, 0);
   ArrayInitialize(lastCandleTime, 0);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   // Display total trades on chart
   string tradeSummary = "Total Trades (All Symbols):\n";
   int allTotal = 0;
   for(int j = 0; j < ArraySize(symbolsRaw); j++)
   {
      string sym = symbolsRaw[j];
      int orders = CountOpenOrders(sym);
      int positions = CountOpenPositions(sym);
      int total = orders + positions;
      allTotal += total;
      tradeSummary += StringFormat("%s: %d (O:%d P:%d)\n", sym, total, orders, positions);
   }
   tradeSummary = StringFormat("Total: %d\n", allTotal) + tradeSummary;
   Comment(tradeSummary);
   
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int currentHour = dt.hour;

   if(currentHour < TradingStartHour || currentHour >= TradingEndHour)
      return;

   for(int i = 0; i < ArraySize(symbolsRaw); i++)
   {
      string sym = symbolsRaw[i];
      datetime currentCandleTime = iTime(sym, _Period, 0);
      
      // Process new candle only
      if(lastCandleTime[i] == currentCandleTime)
         continue;
      
      lastCandleTime[i] = currentCandleTime;
      if(!SymbolSelect(sym, true)) continue;

      // Get current trade count
      int openOrders = CountOpenOrders(sym);
      int openPositions = CountOpenPositions(sym);
      int totalTrades = openOrders + openPositions;
      
      // Cancel expired orders (regardless of trade count)
      if(lastOrderTime[i] > 0 && now - lastOrderTime[i] > ExpireAfterBars * PeriodSeconds())
      {
         CancelPendingOrders(sym);
         lastOrderTime[i] = 0;
         
         // Recalculate after cancellation
         openOrders = CountOpenOrders(sym);
         openPositions = CountOpenPositions(sym);
         totalTrades = openOrders + openPositions;
      }
      
      // Skip if already at max trades
      if(totalTrades >= MaxTradesPerSymbol)
         continue;

      double pipFactor = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS) == 5 || 
                         (int)SymbolInfoInteger(sym, SYMBOL_DIGITS) == 3 ? 0.0001 : 0.01;
      ENUM_TIMEFRAMES tf = _Period;

      // Calculate price range
      double highRange = iHigh(sym, tf, 1);
      double lowRange  = iLow(sym, tf, 1);
      for(int b = 2; b <= RangeBars; b++)
      {
         highRange = MathMax(highRange, iHigh(sym, tf, b));
         lowRange  = MathMin(lowRange, iLow(sym, tf, b));
      }

      double buyEntry  = NormalizeDouble(highRange + (pipFactor * 2), (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
      double sellEntry = NormalizeDouble(lowRange - (pipFactor * 2), (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
      double sl        = SL_Pips * pipFactor;
      double tp        = sl * RiskRewardRatio;

      // Get RSI value
      int rsiHandle = iRSI(sym, tf, 14, PRICE_CLOSE);
      double rsiValue[1];
      ArraySetAsSeries(rsiValue, true);
      if(CopyBuffer(rsiHandle, 0, 0, 1, rsiValue) <= 0) continue;

      // Place orders only when RSI is NOT in neutral zone (45-55)
      if(rsiValue[0] > 55.0 || rsiValue[0] < 45.0)
      {
         int placed = 0;
         double currentAsk = SymbolInfoDouble(sym, SYMBOL_ASK);
         double currentBid = SymbolInfoDouble(sym, SYMBOL_BID);

         // Place buy stop if there's room
         if(totalTrades + placed < MaxTradesPerSymbol && buyEntry > currentAsk)
         {
            if(PlacePendingOrder(sym, ORDER_TYPE_BUY_STOP, buyEntry, LotSize, 
                                 buyEntry - sl, buyEntry + tp, "Breakout Buy"))
            {
               placed++;
            }
         }

         // Place sell stop if there's room
         if(totalTrades + placed < MaxTradesPerSymbol && sellEntry < currentBid)
         {
            if(PlacePendingOrder(sym, ORDER_TYPE_SELL_STOP, sellEntry, LotSize, 
                                 sellEntry + sl, sellEntry - tp, "Breakout Sell"))
            {
               placed++;
            }
         }

         // Update order time if we placed any orders
         if(placed > 0)
            lastOrderTime[i] = now;
      }
   }
}

bool PlacePendingOrder(string sym, ENUM_ORDER_TYPE type, double price, double volume, 
                       double sl, double tp, string comment)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action      = TRADE_ACTION_PENDING;
   request.symbol      = sym;
   request.volume      = volume;
   request.price       = NormalizeDouble(price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
   request.sl          = NormalizeDouble(sl, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
   request.tp          = NormalizeDouble(tp, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
   request.type        = type;
   request.magic       = MagicNumber;
   request.deviation   = Slippage;
   request.type_time   = ORDER_TIME_GTC;
   request.expiration  = 0;
   request.comment     = comment;

   if(OrderSend(request, result))
   {
      Print(sym, ": Pending order placed: ", comment, " at ", price);
      return true;
   }
   else
   {
      Print(sym, ": OrderSend failed (", comment, "): Error ", GetLastError());
      return false;
   }
}

void CancelPendingOrders(string sym)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i) && OrderGetString(ORDER_SYMBOL) == sym && 
         OrderGetInteger(ORDER_MAGIC) == MagicNumber)
      {
         ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         {
            ulong ticket = OrderGetTicket(i);
            if(trade.OrderDelete(ticket))
               Print(sym, ": Cancelled order #", ticket);
            else
               Print(sym, ": Failed to cancel order #", ticket, " Error: ", GetLastError());
         }
      }
   }
}

int CountOpenOrders(string sym)
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i) && OrderGetString(ORDER_SYMBOL) == sym && 
         OrderGetInteger(ORDER_MAGIC) == MagicNumber)
      {
         count++;
      }
   }
   return count;
}

int CountOpenPositions(string sym)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == sym && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         count++;
      }
   }
   return count;
}