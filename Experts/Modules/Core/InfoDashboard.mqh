#ifndef __INFODASHBOARD_V2_MQH__
#define __INFODASHBOARD_V2_MQH__

#include <ChartObjects/ChartObjectsTxtControls.mqh>

struct SignalStatus {
   string values[]; // Each index corresponds to a row
};

// Global variables
string gSymbols[];
string gRowLabels[];
int gBaseX = 10;
int gBaseY = 20;
int gCellWidth = 100;
int gCellHeight = 20;

//+------------------------------------------------------------------+
//| Sanitize object names by removing invalid characters             |
//+------------------------------------------------------------------+
string SanitizeName(string name) {
   StringReplace(name, "/", "_");
   StringReplace(name, ":", "_");
   StringReplace(name, ".", "_");
   return name;
}

//+------------------------------------------------------------------+
//| Initialize dashboard layout                                      |
//+------------------------------------------------------------------+
void InitDashboard(string &symbols[], string &rowLabels[], int baseX = 10, int baseY = 20) {
   ArrayCopy(gSymbols, symbols);
   ArrayCopy(gRowLabels, rowLabels);
   gCellWidth = 300;
   gCellHeight = 60;
   gBaseX = baseX;
   gBaseY = baseY;
   

   // Create header row
   for (int s = 0; s < ArraySize(gSymbols); s++) {
      string sanitizedSymbol = SanitizeName(gSymbols[s]);
      string header = "header_" + sanitizedSymbol;
      
      int x = gBaseX + (s + 1) * gCellWidth ;
      int y = gBaseY;
      
      ObjectCreate(0, header, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, header, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, header, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, header, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, header, OBJPROP_FONTSIZE, 15);
      ObjectSetInteger(0, header, OBJPROP_COLOR, clrLime);
      ObjectSetString(0, header, OBJPROP_TEXT, gSymbols[s]);
      ObjectSetInteger(0, header, OBJPROP_SELECTABLE, false);
   }

   // Create row labels
   for (int r = 0; r < ArraySize(gRowLabels); r++) {
      string rowName = "row_" + IntegerToString(r);
      
      int x = gBaseX;
      int y = gBaseY + (r + 1) * gCellHeight;
      
      ObjectCreate(0, rowName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, rowName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, rowName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, rowName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, rowName, OBJPROP_FONTSIZE, 15);
      ObjectSetInteger(0, rowName, OBJPROP_COLOR, clrRed);
      ObjectSetString(0, rowName, OBJPROP_TEXT, gRowLabels[r]);
      ObjectSetInteger(0, rowName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Update symbol cell values with colored background                |
//+------------------------------------------------------------------+
void UpdateDashboard(string symbol, SignalStatus &status) {
   int symbolIndex = -1;
   for (int i = 0; i < ArraySize(gSymbols); i++) {
      if (gSymbols[i] == symbol) {
         symbolIndex = i;
         break;
      }
   }
   if (symbolIndex == -1) {
      Print("Symbol not found: ", symbol);
      return;
   }

   for (int r = 0; r < ArraySize(status.values) && r < ArraySize(gRowLabels); r++) {
      string sanitizedSymbol = SanitizeName(symbol);
      string base = "cell_" + sanitizedSymbol + "_" + IntegerToString(r);
      
      int x = gBaseX + (symbolIndex + 1) * gCellWidth;
      int y = gBaseY + (r + 1) * gCellHeight;
      string text = status.values[r];

      // Determine colors based on content
      color bgColor = clrWhite;
      color textColor = clrBlack;
      
      if (StringFind(text, "BUY") != -1) {
         bgColor = clrGreen;
         textColor = clrWhite;
      }
      else if (StringFind(text, "SELL") != -1) {
         bgColor = clrRed;
         textColor = clrWhite;
      }

      // Create or update background rectangle
      if (ObjectFind(0, base + "_bg") < 0) {
         ObjectCreate(0, base + "_bg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, base + "_bg", OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, base + "_bg", OBJPROP_XSIZE, gCellWidth);
         ObjectSetInteger(0, base + "_bg", OBJPROP_YSIZE, gCellHeight);
         ObjectSetInteger(0, base + "_bg", OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, base + "_bg", OBJPROP_SELECTABLE, false);
      }
      ObjectSetInteger(0, base + "_bg", OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, base + "_bg", OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, base + "_bg", OBJPROP_BGCOLOR, bgColor);

      // Create or update text label
      if (ObjectFind(0, base + "_txt") < 0) {
         ObjectCreate(0, base + "_txt", OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, base + "_txt", OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, base + "_txt", OBJPROP_FONTSIZE, 15);
         ObjectSetInteger(0, base + "_txt", OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, base + "_txt", OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
      ObjectSetInteger(0, base + "_txt", OBJPROP_XDISTANCE, x + 5);
      ObjectSetInteger(0, base + "_txt", OBJPROP_YDISTANCE, y + (gCellHeight/2) - 1); // Vertically center
      ObjectSetInteger(0, base + "_txt", OBJPROP_COLOR, textColor);
      ObjectSetString(0, base + "_txt", OBJPROP_TEXT, text);
   }
}

//+------------------------------------------------------------------+
//| Clean up dashboard objects                                       |
//+------------------------------------------------------------------+
void DeleteDashboard() {
   // Delete headers
   for (int s = 0; s < ArraySize(gSymbols); s++) {
      string header = "header_" + SanitizeName(gSymbols[s]);
      ObjectDelete(0, header);
   }
   
   // Delete row labels
   for (int r = 0; r < ArraySize(gRowLabels); r++) {
      string rowName = "row_" + IntegerToString(r);
      ObjectDelete(0, rowName);
   }
   
   // Delete all cells
   for (int s = 0; s < ArraySize(gSymbols); s++) {
      for (int r = 0; r < ArraySize(gRowLabels); r++) {
         string base = "cell_" + SanitizeName(gSymbols[s]) + "_" + IntegerToString(r);
         ObjectDelete(0, base + "_bg");
         ObjectDelete(0, base + "_txt");
      }
   }
}

#endif // __INFODASHBOARD_V2_MQH__