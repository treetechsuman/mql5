#ifndef BOLLINGETOUCHBAND_MQH
#define BOLLINGETOUCHBAND_MQH

string BollingerTouchSignal(int maPeriod, double deviation)
{
    // Bollinger Bands handle with corrected parameters
    int handleBollinger = iBands(_Symbol, _Period, maPeriod, 0, deviation, PRICE_CLOSE);
    if (handleBollinger == INVALID_HANDLE)
    {
        Print("Error: Failed to create Bollinger Bands handle. LastError: ", GetLastError());
        return "Error";
    }

    // Get current Ask price
    double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Get Bollinger Bands data
    double upperBandArray[], lowerBandArray[];
    ArraySetAsSeries(upperBandArray, true);
    ArraySetAsSeries(lowerBandArray, true);

    // Copy data for 3 bars (index 0 = most recent closed bar)
    if (CopyBuffer(handleBollinger, 1, 0, 3, upperBandArray) < 3 ||
        CopyBuffer(handleBollinger, 2, 0, 3, lowerBandArray) < 3)
    {
        Print("Error: Failed to copy Bollinger Bands values. LastError: ", GetLastError());
        IndicatorRelease(handleBollinger);
        return "Error";
    }

    IndicatorRelease(handleBollinger);

    // Get current upper and lower band values
    double currentUpper = upperBandArray[0];
    double currentLower = lowerBandArray[0];

    // Buy: ask price is above upperbanc
    if (Ask > currentUpper)
    {
        return "CLOSEBUY";
    }

    // Sell: ask price is below lowerband
    if (Ask < currentLower)
    {
        return "CLOSESELL";
    }

    return "NoClose";
}

#endif