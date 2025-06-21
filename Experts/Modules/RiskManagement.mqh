#ifndef RISK_MANAGEMENT_MQH
#define RISK_MANAGEMENT_MQH

double CalculateLotSize(string symbol, double riskPercentage, double stopLossPips)
{
    if (riskPercentage <= 0 || stopLossPips <= 0)
    {
        Print("Error: Risk percentage and stop-loss pips must be greater than zero.");
        return 0.0;
    }

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

    if (tickValue <= 0 || tickSize <= 0 || point <= 0)
    {
        Print("Error: Invalid symbol parameters.");
        return 0.0;
    }

    double pointsPerPip = (digits == 3 || digits == 5) ? 10.0 : 1.0;
    double stopLossPoints = stopLossPips * pointsPerPip;

    double riskAmount = (riskPercentage / 100.0) * accountBalance;
    double valuePerPoint = tickValue / tickSize;

    if (valuePerPoint <= 0)
    {
        Print("Error: Value per point is invalid.");
        return 0.0;
    }

    double lotSize = riskAmount / (stopLossPoints * valuePerPoint);

    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    lotSize = MathMin(MathMax(lotSize, minLot), maxLot);
    lotSize = MathRound(lotSize / lotStep) * lotStep;

    return lotSize;
}

double CalculateAtrBaseLotSize(string symbol, double riskPercent, double atr) {
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
double CalculateStopLossBaseLotSize(string symbol, double riskPercent, double stopLoss) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   if (tickValue <= 0 || tickSize <= 0 || stopLoss <= 0) return 0.01;
   double pipValue = (tickValue / tickSize) * 10; // Approximate pip value
   double stopLossPips = stopLoss * 10;

   double lot = NormalizeDouble(riskAmount / (stopLossPips * pipValue), 2);
   return MathMax(lot, 0.01);
}
// Calculate pip distance between two prices for a given symbol
double GetPipDifference(string symbol, double targetPrice, double price)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pipMultiplier = (digits == 3 || digits == 5) ? 10.0 : 1.0;
    return MathAbs(targetPrice - price) / (_Point * pipMultiplier);
}

#endif