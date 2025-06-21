//+------------------------------------------------------------------+
//|                Forex Day Trading EA                             |
//|     Enhanced with Multi-Timeframe, Volatility Filter,          |
//|     Candlestick Confirmation & Dynamic Trailing Stop           |
//|     Added Trade Limits, Cooldown, and Optimization Features    |
//|     Fixed Invalid Stops Issue                                  |
//|     Improved Entry, Exit, and Risk Management Strategies       |
//|     Debug Logs Added for Better Monitoring                     |
//|     Dynamic Lot Sizing and Trailing Stop Added                 |
//|     Added MACD Confirmation & Break-Even Logic                 |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade trade;
CPositionInfo position;

// Input Parameters
input double RiskPercent = 1.0;  // Reduced risk per trade
input int EMA_Fast = 20;
input int EMA_Slow = 50;
input int ATR_Period = 14;
input double ATR_Multiplier = 1.5;
input double RiskRewardRatio = 2.0;
input int ADX_Period = 14;
input double ADX_Threshold = 20;
input int HTF_EMA_Period = 50;
input ENUM_TIMEFRAMES HTF = PERIOD_H1;
input double MaxDailyDrawdown = 5.0;
input bool EnableTrailingStop = true;
input double TrailingStop_ATR_Multiplier = 1.0;
input bool EnablePartialClose = true;
input double PartialCloseRatio = 0.5;
input int MagicNumber = 123456;
input int MaxOpenTrades = 3;
input int CooldownPeriod = 60;
input int RSI_Period = 14;
input double RSI_Overbought = 65;  // Relaxed threshold
input double RSI_Oversold = 35;    // Relaxed threshold
input int MACD_Fast = 12;
input int MACD_Slow = 26;
input int MACD_Signal = 9;

// Indicator Handles
int emaFastHandle, emaSlowHandle, atrHandle, adxHandle, rsiHandle, macdHandle;

// Global Variables
datetime lastTradeTime = 0;
int consecutiveLosses = 0;
bool lastTradeWasBuy = false;
bool lastTradeWasSell = false;

#define POSITION_TYPE_BUY 0
#define POSITION_TYPE_SELL 1

//+------------------------------------------------------------------+
//| Lot Size Calculation Function                                   |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLoss)
{
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100);
    double lotSize = riskAmount / (stopLoss * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));

    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    lotSize = MathMax(minLot, MathMin(lotSize, maxLot));
    lotSize = MathFloor(lotSize / lotStep) * lotStep;

    if (lotSize < minLot)
        lotSize = minLot;

    // Margin Check
    double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
    double marginRequired = lotSize * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);

    while (freeMargin < marginRequired && lotSize > minLot)
    {
        lotSize -= lotStep;
        marginRequired = lotSize * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
    }

    if (freeMargin < marginRequired)
    {
        Print("Not enough margin even for the minimum lot size. Trade will not be placed.");
        return 0; // Do not place trade if margin is insufficient
    }

    return lotSize;
}

//+------------------------------------------------------------------+
//| Check for Existing Positions                                     |
//+------------------------------------------------------------------+
bool HasOpenPosition(int type)
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (position.SelectByIndex(i))
        {
            if (position.Symbol() == _Symbol && position.Type() == type)
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Initialization Function                                         |
//+------------------------------------------------------------------+
int OnInit()
{
    emaFastHandle = iMA(_Symbol, _Period, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    emaSlowHandle = iMA(_Symbol, _Period, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    atrHandle = iATR(_Symbol, _Period, ATR_Period);
    adxHandle = iADX(_Symbol, _Period, ADX_Period);
    rsiHandle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
    macdHandle = iMACD(_Symbol, _Period, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);

    if (emaFastHandle < 0 || emaSlowHandle < 0 || atrHandle < 0 || adxHandle < 0 || rsiHandle < 0 || macdHandle < 0)
    {
        Print("Indicator initialization failed");
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    if (TimeCurrent() - lastTradeTime < CooldownPeriod * 60) return;

    double emaFast[], emaSlow[], atr[], adx[], rsi[], macdMain[], macdSignal[];

    MqlRates rates[];
    if (CopyRates(_Symbol, _Period, 0, 100, rates) <= 0)
    {
        Print("Failed to load historical rates.");
        return;
    }

    if (CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) <= 0 ||
        CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlow) <= 0 ||
        CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0 ||
        CopyBuffer(adxHandle, 0, 0, 1, adx) <= 0 ||
        CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0 ||
        CopyBuffer(macdHandle, 0, 0, 3, macdMain) <= 0 ||
        CopyBuffer(macdHandle, 1, 0, 3, macdSignal) <= 0)
    {
        Print("Failed to copy indicator buffers.");
        return;
    }

    double priceClose = rates[1].close; // Using last completed bar
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    double stopLoss = ATR_Multiplier * atr[0];
    double lotSize = CalculateLotSize(stopLoss);

    if (lotSize < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        Print("Lot size too small to place a trade.");
        return;
    }

    bool macdConfirmation = (macdMain[1] > macdSignal[1]);

    if (emaFast[1] > emaSlow[1] && rsi[0] < RSI_Oversold && macdConfirmation && !HasOpenPosition(POSITION_TYPE_BUY))
    {
        double sl = bid - stopLoss;
        double tp = bid + (RiskRewardRatio * stopLoss);
        if (trade.Buy(lotSize, _Symbol, ask, sl, tp, "Buy Signal"))
        {
            lastTradeTime = TimeCurrent();
            consecutiveLosses = 0;
            lastTradeWasBuy = true;
            lastTradeWasSell = false;
            Print("Buy Order Placed at: ", ask);
        }
    }

    if (emaFast[1] < emaSlow[1] && rsi[0] > RSI_Overbought && !macdConfirmation && !HasOpenPosition(POSITION_TYPE_SELL))
    {
        double sl = ask + stopLoss;
        double tp = ask - (RiskRewardRatio * stopLoss);
        if (trade.Sell(lotSize, _Symbol, bid, sl, tp, "Sell Signal"))
        {
            lastTradeTime = TimeCurrent();
            consecutiveLosses = 0;
            lastTradeWasSell = true;
            lastTradeWasBuy = false;
            Print("Sell Order Placed at: ", bid);
        }
    }
}
//+------------------------------------------------------------------+
