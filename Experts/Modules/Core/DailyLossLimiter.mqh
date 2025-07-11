#ifndef __DAILY_LOSS_LIMITER_MQH__
#define __DAILY_LOSS_LIMITER_MQH__

input double MaxDailyLossPercent = 1.0;  // Stop trading if loss > 5%
input int    ResetHour = 0;              // Broker time hour when new day starts (usually 0 or 5)

double gStartOfDayEquity = 0;
datetime gLastResetTime = 0;

// === Call in OnInit() ===
void InitDailyLossLimiter() {
    gStartOfDayEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    gLastResetTime = TimeCurrent();
    PrintFormat("📅 [DL] Starting Equity: %.2f at %s", 
                gStartOfDayEquity, TimeToString(gLastResetTime));
}

// === Core logic - call before any trade entry ===
bool IsDailyLossLimitBreached() {
    datetime currentTime = TimeCurrent();
    double equityNow = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Check for new trading day (broker time)
    MqlDateTime resetTime, currentTimeStruct;
    TimeToStruct(gLastResetTime, resetTime);
    TimeToStruct(currentTime, currentTimeStruct);
    
    // Calculate seconds since last reset
    int elapsedSeconds = (int)(currentTime - gLastResetTime);
    bool isNewDay = false;

    // Detect new trading day (configurable reset hour)
    if(currentTimeStruct.hour == ResetHour && 
       currentTimeStruct.min == 0 &&
       elapsedSeconds >= 3600)  // Minimum 1 hour since last reset
    {
        isNewDay = true;
    }
    // Fallback: 24-hour reset
    else if(elapsedSeconds >= 86400) {
        isNewDay = true;
    }
    
    // Reset equity at start of new day
    if(gLastResetTime == 0 || isNewDay) {
        gStartOfDayEquity = equityNow;
        gLastResetTime = currentTime;
        PrintFormat("🔄 [DL] New trading day. Equity reset: %.2f at %s",
                    gStartOfDayEquity, TimeToString(currentTime));
        return false;
    }
    
    // Calculate loss percentage
    double equityChange = gStartOfDayEquity - equityNow;
    double lossPercent = (equityChange / MathMax(gStartOfDayEquity, 100)) * 100.0;

    // Prevent false triggers on account growth
    if(equityNow > gStartOfDayEquity) return false;

    //PrintFormat("📊 [DL] Equity: %.2f | Daily: %.2f | Loss: %.2f%%",
     //           equityNow, gStartOfDayEquity, lossPercent);

    // Check loss threshold
    if(lossPercent >= MaxDailyLossPercent) {
        PrintFormat("🛑 [DL] Daily loss limit hit! %.2f%% >= %.2f%%", 
                   lossPercent, MaxDailyLossPercent);
        return true;
    }

    return false;
}

#endif