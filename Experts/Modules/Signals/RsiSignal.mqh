#ifndef RSISIGNAL_MQH
#define RSISIGNAL_MQH

string RsiSignal(int rsiPeriod, int rsiUpperLevel, int rsiLowerLevel)
{
    // Create an array to store RSI values
    double rsiArray[];

    // Create the RSI indicator handle
    int handleRSI = iRSI(_Symbol, PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE);

    // Check if the RSI handle is valid
    if (handleRSI == INVALID_HANDLE)
    {
        Print("Error: Failed to create RSI indicator handle.");
        return "NoTrade";
    }

    // Resize and sort the array
    ArraySetAsSeries(rsiArray, true);

    // Copy RSI values into the array (ensure at least 2 values are copied)
    if (CopyBuffer(handleRSI, 0, 0, 2, rsiArray) <= 0)  // Fetch only the latest two values
    {
        Print("Error: Failed to copy RSI values.");
        IndicatorRelease(handleRSI);  // Release handle before returning
        return "NoTrade";
    }

    // Release the RSI indicator handle to prevent memory leaks
    IndicatorRelease(handleRSI);

    // Debugging print statements
    //PrintFormat("RSI[1]: %.2f, RSI[0]: %.2f", rsiArray[1], rsiArray[0]);

    // Ensure we use RSI[1] (previous candle) for a confirmed signal
    if ( rsiArray[0] < rsiLowerLevel)
    {
        return "BUY";  // RSI crossed above buy level (bullish signal)
    }
    if ( rsiArray[0] > rsiUpperLevel)
    {
        return "SELL";  // RSI crossed below sell level (bearish signal)
    }

    return "NoTrade";  // No valid crossover detected
}
// Function to get RSI signal for a given symbol and timeframe
string RsiSignal(string symbol, ENUM_TIMEFRAMES tf, int rsiPeriod, int rsiUpperLevel, int rsiLowerLevel)
{
    double rsiArray[];
    int handleRSI = iRSI(symbol, tf, rsiPeriod, PRICE_CLOSE);

    if (handleRSI == INVALID_HANDLE)
    {
        Print("Error: Failed to create RSI indicator handle for ", symbol);
        return "NoTrade";
    }

    ArraySetAsSeries(rsiArray, true);

    if (CopyBuffer(handleRSI, 0, 0, 2, rsiArray) <= 0)
    {
        Print("Error: Failed to copy RSI values for ", symbol);
        IndicatorRelease(handleRSI);
        return "NoTrade";
    }

    IndicatorRelease(handleRSI);

    if (rsiArray[0] < rsiLowerLevel)
        return "BUY";
    else if (rsiArray[0] > rsiUpperLevel)
        return "SELL";
    return "NoTrade";
}

#endif