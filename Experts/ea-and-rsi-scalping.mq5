//+------------------------------------------------------------------+
//|                                          ea-and-rsi-scalping.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.03"

//+------------------------------------------------------------------+
//| Scalping EA using EMA and RSI                                    |
//+------------------------------------------------------------------+
input int EMA_Fast_Period = 10;       // Fast EMA period
input int EMA_Slow_Period = 50;       // Slow EMA period
input int EMA_Very_Slow_Period  = 200;       //  EMA_200 
input int RSI_Period = 14;            // RSI period
input double RSI_Buy_Level = 55;      // RSI level for buy
input double RSI_Sell_Level = 45;     // RSI level for sell
input double TakeProfit = 200;         // Take profit in points
input double StopLoss = 50;           // Stop loss in points
//input double LotSize = 0.01;          // Lot size
input double riskPercentage = 2;

// Variables to store indicator values
double EMA_Fast, EMA_Slow,EMA_Very_Slow, RSI_Value;

//+------------------------------------------------------------------+
//| OnTick function (runs on each price tick)                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| OnTick function (runs on each price tick)                        |
//+------------------------------------------------------------------+
void OnTick()
{
    // Handle creation for indicators
    int handleFast = iMA(Symbol(), Period(), EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
    int handleSlow = iMA(Symbol(), Period(), EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
    int handleVerySlow = iMA(Symbol(), Period(), EMA_Very_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
    int handleRSI = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE);

    // Arrays to hold indicator values
    double fast[], slow[], verySlow[], rsi[];

    // Copy the latest values
    if (CopyBuffer(handleFast, 0, 0, 1, fast) <= 0 ||
        CopyBuffer(handleSlow, 0, 0, 1, slow) <= 0 ||
        CopyBuffer(handleVerySlow, 0, 0, 1, verySlow) <= 0 ||
        CopyBuffer(handleRSI, 0, 0, 1, rsi) <= 0)
    {
        //Print("Error copying buffer data");
        return;
    }

    // Assigning values
    EMA_Fast = fast[0];
    EMA_Slow = slow[0];
    EMA_Very_Slow = verySlow[0];
    RSI_Value = rsi[0];

    //Print("EMA Fast: ", EMA_Fast, " EMA Slow: ", EMA_Slow, " EMA 200: ", EMA_Very_Slow, " RSI: ", RSI_Value);

    if (CheckForBuySignal(EMA_Very_Slow) && PositionsTotal() == 0)
    {
        //Print("Buy signal");
        OpenBuyOrder();
    }

    if (CheckForSellSignal(EMA_Very_Slow) && PositionsTotal() == 0)
    {
        //Print("Sell signal");
        OpenSellOrder();
    }
    MoveStopLossToBreakeven(50); // Move SL to breakeven after 10 points
    
}

//+------------------------------------------------------------------+
//| Buy Condition                                                    |
//+------------------------------------------------------------------+
bool CheckForBuySignal(double EMA_Very_Slow)
{
    double priceClose = iClose(Symbol(), Period(), 0);
    return (EMA_Fast > EMA_Slow && RSI_Value > RSI_Buy_Level && priceClose > EMA_Very_Slow);
    
}

//+------------------------------------------------------------------+
//| Sell Condition                                                   |
//+------------------------------------------------------------------+
bool CheckForSellSignal(double EMA_Very_Slow)
{
   double priceClose = iClose(Symbol(), Period(), 0);
    return (EMA_Fast < EMA_Slow && RSI_Value < RSI_Sell_Level && priceClose < EMA_Very_Slow);
}

//+------------------------------------------------------------------+
//| Function to open a buy trade                                     |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
    double bidPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double sl = NormalizeDouble(bidPrice - StopLoss * _Point, _Digits);
    double tp = NormalizeDouble(bidPrice + TakeProfit * _Point, _Digits);
    double dynamicLotSize;
    dynamicLotSize = CalculateLotSize(riskPercentage, StopLoss);
    
    Print("stop laoss",sl);
    Print("TakeProfie ",tp);
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);

    request.action = TRADE_ACTION_DEAL;
    request.type = ORDER_TYPE_BUY;
    request.symbol = Symbol();
    request.volume = dynamicLotSize;
    request.price = bidPrice;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = 123456;
    request.comment = "EMA_RSI_Buy";
    request.type_filling = ORDER_FILLING_IOC;  // Force using IOC filling mode

    if (!OrderSend(request, result))
    {
        Print("Buy order failed hshshs! Error: ", result.retcode);
    }
    else
    {
        Print("Buy order placed successfully. Order ID: ", result.order);
    }
}

//+------------------------------------------------------------------+
//| Function to open a sell trade                                    |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
    double askPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double sl = NormalizeDouble(askPrice + StopLoss * _Point, _Digits);
    double tp = NormalizeDouble(askPrice - TakeProfit * _Point, _Digits);
    double dynamicLotSize;
    dynamicLotSize = CalculateLotSize(riskPercentage, StopLoss);
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);

    request.action = TRADE_ACTION_DEAL;
    request.type = ORDER_TYPE_SELL;
    request.symbol = Symbol();
    request.volume = dynamicLotSize;
    request.price = askPrice;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = 123456;
    request.comment = "EMA_RSI_Sell";
    request.type_filling = ORDER_FILLING_IOC;  // Force using IOC filling mode

    if (!OrderSend(request, result))
    {
        Print("Sell order failed ! Error: ", result.retcode);
    }
    else
    {
        Print("Sell order placed successfully. Order ID: ", result.order);
    }
}

double CalculateLotSize(double riskPercentage, double stopLossPips)
{
    // Get account balance and calculate risk amount
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = (riskPercentage / 100.0) * accountBalance;

    // Retrieve necessary symbol properties
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    double contractSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);

    // Ensure valid values for calculations
    if (tickSize <= 0 || tickValue <= 0 || contractSize <= 0)
    {
        //Print("Error: Invalid tick size, tick value, or contract size");
        return 0.0;
    }

    // Calculate pip value for the symbol
    double pipValue = (tickValue / tickSize);
    
    // Calculate lot size based on risk amount and pip value
    double lotSize = riskAmount / (stopLossPips * (double)pipValue);

    // Ensure the lot size adheres to broker's min/max and step values
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

    // Adjust lot size within allowed limits
    lotSize = MathMax(minLot, MathMin(maxLot, NormalizeDouble(lotSize, 2)));

    // Round down to the nearest valid lot step
    lotSize = NormalizeDouble(lotSize - fmod(lotSize, lotStep), 2);

    //Print("Account Balance: ", accountBalance, " Risk Amount: ", riskAmount);
    //Print("Risk Amount: ", riskAmount, " Stop Loss Pips: ", stopLossPips, " Pip Value: ", pipValue);
    //Print("Calculated Lot Size: ", lotSize);

    return lotSize;
}

void MoveStopLossToBreakeven(double breakevenPoints)
{
    if (PositionsTotal() == 0)
    {
        Print("No open positions found.");
        return;
    }

    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionGetSymbol(i) == Symbol())
        {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
                                 ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                 : SymbolInfoDouble(symbol, SYMBOL_ASK);
            double sl = PositionGetDouble(POSITION_SL);
            double pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);

            if (currentPrice - openPrice >= breakevenPoints * pointValue && sl < openPrice)
            {
                MqlTradeRequest request;
                MqlTradeResult result;
                ZeroMemory(request);
                ZeroMemory(result);

                request.action = TRADE_ACTION_SLTP;
                request.symbol = symbol;
                request.sl = NormalizeDouble(openPrice, _Digits);
                request.tp = PositionGetDouble(POSITION_TP);
                request.position = PositionGetInteger(POSITION_TICKET);

                if (OrderSend(request, result))
                    Print("Stop Loss moved to breakeven for order.");
                else
                    Print("Failed to modify Stop Loss. Error: ", result.retcode);
            }
        }
        else
        {
            Print("Failed to find position for symbol: ", Symbol());
        }
    }
}





//+------------------------------------------------------------------+
//| EA Initialization Function                                       |
//+------------------------------------------------------------------+
void OnInit()
{
    Print("EMA & RSI Scalping EA Initialized");
    if (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == false)
    {
        Print("Trading is disabled for this account. Please enable it in options.");
    }
}

//+------------------------------------------------------------------+
//| EA Deinitialization Function                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("EMA & RSI Scalping EA Deinitialized");
}
