//+------------------------------------------------------------------+
//|                                                 IceFX.DrawProfit |
//|                                         Copyright © 2017, Ice FX |
//|                                              http://www.icefx.eu |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2017, Ice FX <http://www.icefx.eu>"
#property link      "http://www.icefx.eu"
#property strict

#property version   "3.05"

#property description "IceFX DrawProfit indicator can efficiently help those traders who want to see on the chart all closed positions output: profit or loss. "
#property description "If set DrawProfit on your chart managed by an Expert Advisor (EA) you will see clearly it’s performance by its profits & losses."

#property indicator_chart_window
#property indicator_buffers 0

#define  INDI_VERSION                 "3.0.5"

enum ENUM_PROFITMODE_TYPE {
   PM_CURRENCY, // Show in currency
   PM_PIPS, // Show in pips
   PM_BOTH // Show in currency and pips
};

extern bool    ShowProfitLabels        = true;
extern ENUM_PROFITMODE_TYPE    ProfitMode              = PM_CURRENCY;
extern bool    ShowOrderLines          = true;
extern bool    ShowSLTPLevels          = false;
extern int     MagicFilter             = -1;
extern string  CommentFilter           = "";

#include <Canvas\Canvas.mqh>;

double pip_multiplier = 1.0;

datetime DP_LastCandleTime = 0;
string DP_OldPrefix = "!!PROFITLBL_"; 
string DP_NewPrefix = "DrawProfit_"; 

int init()
{
   DP_LastCandleTime = 0;

   DP_DeleteObjects(DP_OldPrefix);
   DP_DeleteObjects(DP_NewPrefix);
   
   SetPipMultiplier();
   
   if (OrdersHistoryTotal() > 0)
      start();
   
   return(INIT_SUCCEEDED);
}

int deinit()
{
   DP_DeleteObjects(DP_NewPrefix + "P");
   
   return(0);
}

//+------------------------------------------------------------------+
//| script program start function                                    |
//+------------------------------------------------------------------+
int start()
{
   int total = OrdersHistoryTotal();
   if (total > 0) {
      for(int i = 0; i < total; i++)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         {
            if (IsValidOrder() && OrderCloseTime() > 0)
            {
               if (OrderType() == OP_BUY || OrderType() == OP_SELL)
               {
                  if (OrderCloseTime() < DP_LastCandleTime) continue;
   
                  int      candle      = iBarShift(Symbol(), Period(), OrderCloseTime());
                  datetime candleTime  = iTime(Symbol(), Period(), candle);
                  double profitPips = GetOrderProfitPips();
                  double profit = OrderProfit() + OrderSwap() + OrderCommission();
   
                  if (ShowProfitLabels)
                     DrawOrderProfit(candle, candleTime, profit, profitPips);
                     
                  if (ShowOrderLines)
                     DrawOrderLine();
                  
               }
            }
         }
      }
      
      DP_LastCandleTime = Time[0];
      DP_DeleteObjects(DP_NewPrefix + "P");
   }

   return(0);
}


//+------------------------------------------------------------------+
double GetOrderProfitPips() {
//+------------------------------------------------------------------+
   if (OrderType() == OP_BUY)
      return(point2pip(OrderClosePrice() - OrderOpenPrice()));
   else if (OrderType() == OP_SELL)
      return(point2pip(OrderOpenPrice() - OrderClosePrice()));
   
   return(0);
}

//+------------------------------------------------------------------+
bool IsValidOrder() {
//+------------------------------------------------------------------+
   if (OrderSymbol() == Symbol()) 
      if ( MagicFilter == -1 || MagicFilter == OrderMagicNumber() )
         if (CommentFilter == "" || StringFind(OrderComment(), CommentFilter) != -1)
            return(true);

   return(false);
}

//+------------------------------------------------------------------+
void DrawOrderLine() {
//+------------------------------------------------------------------+
   double lots       = OrderLots(),
          openPrice  = OrderOpenPrice(),
          closePrice = OrderClosePrice(),
          tp         = OrderTakeProfit(),
          sl         = OrderStopLoss(),
          profit     = OrderProfit() + OrderSwap() + OrderCommission();
          
   datetime openTime    = OrderOpenTime(),
            closeTime   = OrderCloseTime();
            
   int ticket     = OrderTicket(),
       ordType    = OrderType();
   
   string symb       = OrderSymbol(),
          comment    = OrderComment(),
          action     = "Buy";
          
   color c = Blue;
   if (ordType == OP_SELL || ordType == OP_SELLLIMIT || ordType == OP_SELLSTOP)
   {
      c = Red;
      action = "Sell";
   }
      
   // order open arrow name:    #76840865 buy 0.05 EURUSDc at 1.30416

   string objName = StringConcatenate("#", ticket, " ", action, " ", lots, " ", symb, " at ", openPrice);
   ObjectCreate(objName, OBJ_ARROW, 0, openTime, openPrice);
   ObjectSet(objName, OBJPROP_COLOR, c);
   ObjectSet(objName, OBJPROP_ARROWCODE, 1);
   //ObjectSetText(objName, "LOT: " + DoubleToStr(lots, 2));

   // order line name:    #76840865 1.30416 -> 1.30956

   objName = StringConcatenate("#", ticket, " ", openPrice, " -> ", closePrice);
   ObjectCreate(objName, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice);
   ObjectSet(objName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSet(objName, OBJPROP_RAY, false);
   ObjectSet(objName, OBJPROP_COLOR, c);

   // order close arrow name: #76840865 buy 0.05 EURUSDc at 1.30416 close at 1.30956
   objName = StringConcatenate("#", ticket, " ", action, " ", lots, " ", symb, " at ", openPrice, " close at ", closePrice);
   ObjectCreate(objName, OBJ_ARROW, 0, closeTime, closePrice);
   ObjectSet(objName, OBJPROP_COLOR, c);
   ObjectSet(objName, OBJPROP_ARROWCODE, 3);
   ObjectSetText(objName, StringConcatenate("Profit: ", profit, ", Comment: ", comment));
   
   if (ShowSLTPLevels && sl != EMPTY_VALUE && sl > 0.0)
   {
      // SL line arrow name: #76824391 buy stop 0.10 EURUSDc at 1.32065 stop loss at 1.31865
      objName = StringConcatenate("#", ticket, " ", action, " ", lots, " ", symb, " at ", openPrice, " stop loss at ", sl);
      ObjectCreate(objName, OBJ_ARROW, 0, openTime, sl);
      ObjectSet(objName, OBJPROP_COLOR, Red);
      ObjectSet(objName, OBJPROP_ARROWCODE, 4);
   }
   
   if (ShowSLTPLevels && tp != EMPTY_VALUE && tp > 0.0)
   {
      //  TP line arrow name: #76764027 buy stop 0.10 EURUSDc at 1.31474 take profit at 1.317
      objName = StringConcatenate("#", ticket, " ", action, " ", lots, " ", symb, " at ", openPrice, " take profit at ", tp);
      ObjectCreate(objName, OBJ_ARROW, 0, openTime, tp);
      ObjectSet(objName, OBJPROP_COLOR, Blue);
      ObjectSet(objName, OBJPROP_ARROWCODE, 4);
   }
}


//+------------------------------------------------------------------+
void DrawOrderProfit(int candle, datetime candleTime, double profit, double profitPips, bool background = false) {
//+------------------------------------------------------------------+
   CCanvas canvas;
   
   int offset = 2;
   int height = 16;

   string objName = StringConcatenate(DP_NewPrefix, (int)candleTime);
   
   double oldProfit = DP_GetCandleProfit(candleTime);
   profit += oldProfit;
   DP_SetCandleProfit(candleTime, profit);

   string text;
   color c;
   if (ProfitMode == PM_PIPS) {
      text = StringConcatenate(profitPips >= 0?"+":"", DoubleToStr(profitPips, 1));
      c = (profitPips < 0.0)?clrMaroon:clrDarkGreen;
   } else if (ProfitMode == PM_CURRENCY) {
      text = MTS(profit, 2);
      c = (profit < 0.0)?clrMaroon:clrDarkGreen;
   } else {
      text = StringConcatenate(MTS(profit, 2), " (", profitPips >= 0?"+":"", DoubleToStr(profitPips, 1), ")");
      c = (profit < 0.0)?clrMaroon:clrDarkGreen;
      offset = 0;
   }
   double drawPrice = OrderClosePrice();
   
   canvas.FontNameSet("Verdana");
   canvas.FontFlagsSet(FW_MEDIUM);
   canvas.FontSizeSet(13);   

   int tw = canvas.TextWidth(text) + offset * 2;
   
   int x, y, sw = 0;
   ChartTimePriceToXY(0, 0, candleTime, drawPrice, x, y);
   x -= tw;
   
   //Print("X: ", x, ", Y: ", y, ", tw: ", tw);
   
   ChartXYToTimePrice(0, x, y, sw, candleTime, drawPrice);
   
   ObjectDelete(objName);
   canvas.CreateBitmap(objName, candleTime, drawPrice, tw, height);
   canvas.Erase(ColorToARGB(c));
   
   canvas.TextOut(tw / 2, height / 2, text, clrWhite, TA_CENTER | TA_VCENTER);
   
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, 1);
   ObjectSetString(0, objName, OBJPROP_TOOLTIP, StringConcatenate("Profit: ", text));
   
   canvas.Update();
   
}

//+------------------------------------------------------------------+
double DP_GetCandleProfit(datetime candleTime) {
//+------------------------------------------------------------------+
   double res = 0;
   string objName = StringConcatenate(DP_NewPrefix, "P", (int)candleTime);

   if (ObjectFind(objName) == 0) {
      res = StrToDouble(ObjectDescription(objName));
   }

   return(res);
}

//+------------------------------------------------------------------+
void DP_SetCandleProfit(datetime candleTime, double profit) {
//+------------------------------------------------------------------+
   string objName = StringConcatenate(DP_NewPrefix, "P", (int)candleTime);
   if (ObjectFind(objName) != 0)
      ObjectCreate(objName, OBJ_TEXT, 0, 0, 0);

   ObjectSetText(objName, DoubleToStr(profit, 2), 0, "", White);
}

//+------------------------------------------------------------------+
string MTS(double value, int decimal = 2) { 
//+------------------------------------------------------------------+
   string prefix = "";
   string currSign = AccountCurrency();
   if (currSign == "USD")
      prefix = "$";
   else if (currSign == "EUR")
      prefix = "€";
   else if (currSign == "GBP")
      prefix = "Ł";

   if (value < 0)
      prefix = "-" + prefix;
  
   return(StringConcatenate(prefix, DoubleToStr(MathAbs(value), decimal), "")); 
}

//+------------------------------------------------------------------+
void DP_DeleteObjects(string prefix) {
//+------------------------------------------------------------------+
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
      if(StringFind(ObjectName(i), prefix, 0) == 0)
         ObjectDelete(ObjectName(i));
}

//+------------------------------------------------------------------+
double SetPipMultiplier(bool simple = false) {
//+------------------------------------------------------------------+
   pip_multiplier = 1;
   
   if (simple)
   {
      if (Digits % 4 != 0) pip_multiplier = 10; 
        
   } else {
      if (Digits == 5 || 
         (Digits == 3 && StringFind(Symbol(), "JPY") > -1) ||     // Ha 3 digites és JPY
         (Digits == 2 && StringFind(Symbol(), "XAU") > -1) ||     // Ha 2 digites és arany
         (Digits == 2 && StringFind(Symbol(), "GOLD") > -1) ||    // Ha 2 digites és arany
         (Digits == 3 && StringFind(Symbol(), "XAG") > -1) ||     // Ha 3 digites és ezüst
         (Digits == 3 && StringFind(Symbol(), "SILVER") > -1) ||  // Ha 3 digites és ezüst
         (Digits == 1))                                           // Ha 1 digit (CFDs)
            pip_multiplier = 10;
      else if (Digits == 6 || 
         (Digits == 4 && StringFind(Symbol(), "JPY") > -1) ||     // Ha 4 digites és JPY
         (Digits == 3 && StringFind(Symbol(), "XAU") > -1) ||     // Ha 3 digites és arany
         (Digits == 3 && StringFind(Symbol(), "GOLD") > -1) ||    // Ha 3 digites és arany
         (Digits == 4 && StringFind(Symbol(), "XAG") > -1) ||     // Ha 4 digites és ezüst
         (Digits == 4 && StringFind(Symbol(), "SILVER") > -1) ||  // Ha 4 digites és ezüst
         (Digits == 2))                                           // Ha 2 digit (CFDs)
            pip_multiplier = 100;
   }  
   return(pip_multiplier);
}

//+------------------------------------------------------------------+
double pip2point(double pip) {
//+------------------------------------------------------------------+
   return (pip * Point * pip_multiplier);
}

//+------------------------------------------------------------------+
double point2pip(double point) {
//+------------------------------------------------------------------+
   return(point / Point / pip_multiplier);
}