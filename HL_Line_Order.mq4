//+------------------------------------------------------------------+
//|                                                HL_Line_Order.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

//--- input parameters
input int Magic_Number = 1;

input bool Flat_Lot = False;
input double Flat_Lot_Rate = 0.01;

input bool MM_Lot = False;
input double MM_Rate = 100000;
// entry lot = AccountEquity() / MM_Rate * 0.01

input bool Auto_Lot = True;
input double Auto_Lot_Adjust_Times = 1.0;

input int Candle_Stick_Period = 14;

input int Base_Period_Friday_Hour_Shift = 1;
input int JST_OffSet = 6;

input double Divided_By_Width_To_Launch = 3.0;
input double TP_Width_To_Launch_Times = 2.0;
input double Buy_Entry_Adjust_Pips = 1.5;
input double Buy_SL_Adjust_Pips = 1.0;
input double Buy_TP_Adjust_Pips = 1.0;
input double Sell_Entry_Adjust_Pips = 1.0;
input double Sell_SL_Adjust_Pips = 1.0;
input double Sell_TP_Adjust_Pips = 1.0;


string thisSymbol;

double highPrice;
double lowPrice;

int sellOrderCount;
int buyOrderCount;

double minLot;
double maxLot;
double lotSize;
double lotStep;

const string hLineID = "Monday High";
const string lLineID = "Monday Low";
const string w2lID = "Width to Launch";
const string closeID = "Closing Time";
const string closeLabelID = "Close Label";
const string buttonID = "BI";
const string lotID = "Next Lot";


#define  HR2400 86400       // 24 * 3600
int      TimeOfDay(datetime when){  return( when % HR2400          );         }
datetime DateOfDay(datetime when){  return( when - TimeOfDay(when) );         }
datetime Today(){                   return(DateOfDay( TimeCurrent() ));       }
datetime Tomorrow(int shift){       return(Today() + HR2400 * shift);         }



double widthToLaunch() {
  return MathCeil(((highPrice - lowPrice) / Divided_By_Width_To_Launch) * 1000.0) / 1000.0;
}


void drawHLine(string id, double pos, string label, color clr = clrYellow, int width = 2, int style = 0, bool selectable = True) {

  if(style < 0 || 4 < style) {
    style = 0;
  }
  if(width < 1) {
    width = 1;
  }

  ObjectCreate(id, OBJ_HLINE, 0, 0, pos);
  ObjectSet(id, OBJPROP_COLOR, clr);
  ObjectSet(id, OBJPROP_WIDTH, width);
  ObjectSet(id, OBJPROP_STYLE, style);
  ObjectSet(id, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  
  ObjectSetInteger(0, id, OBJPROP_SELECTABLE, selectable);
//  ObjectSetText(id, label + ": " + DoubleToString(pos, 3), 12, "Arial", clr);
}


void drawVLine(string hour, string minute, color clr = clrAqua, int width = 1, int style = 1) {

  if(style < 0 || 4 < style) {
    style = 0;
  }
  if(width < 1) {
    width = 1;
  }

  datetime time = StrToTime(TimeToStr(5 - Tomorrow(DayOfWeek()), TIME_DATE) + " " + hour + ":" + minute);

  ObjectCreate(closeID, OBJ_VLINE, 0, time, 0);
  ObjectSet(closeID, OBJPROP_WIDTH, width);
  ObjectSet(closeID, OBJPROP_COLOR, clr);
  ObjectSet(closeID, OBJPROP_STYLE, style);
  ObjectSet(closeID, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  
  ObjectSetInteger(0, closeID, OBJPROP_SELECTABLE, false);
  ObjectSetText(closeID, closeID, 12, "Arial", clr);
}

void drawLabel() {

  ObjectCreate(0, w2lID, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, w2lID, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(w2lID, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, w2lID, OBJPROP_SELECTABLE, false);

  string lbl = "Width to Launch: " + DoubleToString(widthToLaunch(), 3);
  ObjectSetText(w2lID, lbl, 16, "Arial", clrYellow);


  ObjectCreate(0, closeLabelID, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, closeLabelID, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(closeLabelID, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, closeLabelID, OBJPROP_SELECTABLE, false);

  string time = IntegerToString((23 - Base_Period_Friday_Hour_Shift + JST_OffSet) % 24) + ":" + IntegerToString(59);
  string tlbl = "Saturday Close Time: " + time;
  ObjectSetText(closeLabelID, tlbl, 16, "Arial", clrAqua);
  ObjectSetInteger(0, closeLabelID, OBJPROP_YDISTANCE, 20);


  ObjectCreate(0, lotID, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, lotID, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(lotID, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, lotID, OBJPROP_SELECTABLE, false);

  string llbl = lotID + ": " + DoubleToStr(calcLot(), 2);
  ObjectSetText(lotID, llbl, 16, "Arial", clrWhite);
  ObjectSetInteger(0, lotID, OBJPROP_YDISTANCE, 80);
}


void drawButton() {

  ObjectCreate(0, buttonID, OBJ_BUTTON, 0, 100, 100);
  ObjectSetInteger(0, buttonID, OBJPROP_COLOR, clrWhite);
  ObjectSetInteger(0, buttonID, OBJPROP_BGCOLOR, clrGray);
  ObjectSetInteger(0, buttonID, OBJPROP_XDISTANCE, 30);
  ObjectSetInteger(0, buttonID, OBJPROP_YDISTANCE, 25);
  ObjectSetInteger(0, buttonID, OBJPROP_XSIZE, 120);
  ObjectSetInteger(0, buttonID, OBJPROP_YSIZE, 50);
  ObjectSetString(0, buttonID, OBJPROP_FONT, "Arial");
  ObjectSetString(0, buttonID, OBJPROP_TEXT, "RUN");
  ObjectSetInteger(0, buttonID, OBJPROP_FONTSIZE, 15);
  ObjectSetInteger(0, buttonID, OBJPROP_SELECTABLE, 0);

  ObjectSetInteger(0, buttonID, OBJPROP_STATE, 0);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{  
  highPrice = High[iHighest(thisSymbol, PERIOD_CURRENT, MODE_HIGH, Candle_Stick_Period, 1)];
  lowPrice = Low[iLowest(thisSymbol, PERIOD_CURRENT, MODE_LOW, Candle_Stick_Period, 1)];

  drawHLine(hLineID, highPrice, hLineID);
  drawHLine(lLineID, lowPrice, lLineID);
  
  thisSymbol = Symbol();

  sellOrderCount = 0;
  buyOrderCount = 0;

  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
  
  drawLabel();
  drawButton();
  
  //---
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  ObjectDelete(0, hLineID);
  ObjectDelete(0, lLineID);
  ObjectDelete(0, w2lID);
  ObjectDelete(0, closeID);
  ObjectDelete(0, closeLabelID);
  ObjectDelete(0, buttonID);
  ObjectDelete(0, lotID);

  //---   
}

bool closeAll(bool pendingOnly = False) {

  int toClose = 0;
  int initialTotal = OrdersTotal();
  
  for(int i = 0; i < initialTotal; i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(OrderType() == OP_BUY && !pendingOnly) {
          toClose ++;
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(thisSymbol, MODE_BID), Digits), 0)) {
            Print("Error on closing long order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELL && !pendingOnly) {
          toClose ++;
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(thisSymbol, MODE_ASK), Digits), 3)) {
            Print("Error on closing short order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_BUYSTOP) {
          toClose ++;
          if(!OrderDelete(OrderTicket())) {
            Print("Error on deleting buy stop order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELLSTOP) {
          toClose ++;
          if(!OrderDelete(OrderTicket())) {
            Print("Error on deleting sell stop order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
      }
    }
  }
  
  return (initialTotal - toClose == OrdersTotal());
}

bool validateParameters() {

  if(MM_Rate == 0.0) {
    Print("MM_Rate must be grater than zero.");
    return False;
  }
  else if(Divided_By_Width_To_Launch == 0.0) {
    Print("Divided_By_Width_To_Launch must be grater than zero.");
    return False;
  }
  else if(highPrice == lowPrice) {
    return False;
  }

  return True;
}


void countOrders() {

  sellOrderCount = 0;
  buyOrderCount = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(OrderType() == OP_SELL || OrderType() == OP_SELLSTOP)
          sellOrderCount ++;
        else if(OrderType() == OP_BUY || OrderType() == OP_BUYSTOP)
          buyOrderCount ++;
      }
    }
  }
}

double calcLot() {

  double lot = 0.0;

  if(Flat_Lot) {
    lot = Flat_Lot_Rate;
  }
  else if(Auto_Lot){
    lot = AccountEquity() / (100.0 * lotSize * widthToLaunch()) * Auto_Lot_Adjust_Times;
  }
  else if(MM_Lot) {
    lot = AccountEquity() / MM_Rate * lotStep;
  }
  
  lot = MathRound(lot / lotStep) * lotStep;
  
  if(maxLot < lot) {
    lot = maxLot;
    Print("Lot size(", lot, ") is larger than max(", maxLot, "). Rounded to ", maxLot, ".");
  }
  else if(lot < minLot) {
    lot = 0.0;
    Print("Lot size(", lot, ") is smaller than min(", minLot, "). Entry skipped.");
  }

  return lot;
}

bool orderLong(double lot) {

  if(lot == 0.0) {
    return False;
  }

  double entryPrice = highPrice + (Buy_Entry_Adjust_Pips * Point * 10.0);
  double stopLoss = entryPrice - widthToLaunch() - (Buy_SL_Adjust_Pips * Point * 10.0);
  double takeProfit = entryPrice + (widthToLaunch() * TP_Width_To_Launch_Times) + (Buy_TP_Adjust_Pips * Point * 10.0);

  double minSL = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;

  if(takeProfit - entryPrice < minSL) {
    Print("TP(", takeProfit, ") is too close to entry point(", entryPrice, ") than minimum stoplevel(", minSL, ")");
    Print("Reconfigure parameters.");
    return False;
  }
  else if(entryPrice - stopLoss < minSL) {
    Print("SL(", stopLoss, ") is too close to entry point(", entryPrice, ") than minimum stoplevel(", minSL, ")");
    Print("Reconfigure parameters.");
    return False;
  }
  else if(entryPrice - Ask < minSL) {
    Print("Current Price(", Ask, ") is too close or higher to entry point(", entryPrice, ") than minimum stoplevel(", minSL, ")");
    return False;
  }
  else {
    int ticket1 = OrderSend(thisSymbol, OP_BUYSTOP, lot, NormalizeDouble(entryPrice, Digits), 3, NormalizeDouble(stopLoss, Digits), NormalizeDouble(takeProfit, Digits), NULL, Magic_Number);
    int ticket2 = OrderSend(thisSymbol, OP_BUYSTOP, lot, NormalizeDouble(entryPrice, Digits), 3, NormalizeDouble(stopLoss, Digits), 0, NULL, Magic_Number);

    if(ticket1 == -1 && ticket2 != -1) {
      while(!OrderDelete(ticket2)) {
        Sleep(1000);
      }
      return False;
    }
    else if(ticket1 != -1 && ticket2 == -1) {
      while(!OrderDelete(ticket1)) {
        Sleep(1000);
      }
      return False;
    }
    else if(ticket1 == -1 && ticket2 == -1) {
      return False;
    }
    else {
      return True;
    }
  }
}

bool orderShort(double lot) {

  if(lot == 0.0) {
    return False;
  }

  double entryPrice = lowPrice - (Sell_Entry_Adjust_Pips * Point * 10.0);
  double stopLoss = entryPrice + widthToLaunch() + (Sell_SL_Adjust_Pips * Point * 10.0);
  double takeProfit = entryPrice - (widthToLaunch() * TP_Width_To_Launch_Times) - (Sell_TP_Adjust_Pips * Point * 10.0);

  double minSL = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;

  if(entryPrice - takeProfit < minSL) {
    Print("TP(", takeProfit, ") is too close to entry point(", entryPrice, ") than minimum stoplevel(", minSL, ")");
    Print("Reconfigure parameters.");
    return False;
  }
  else if(stopLoss - entryPrice < minSL) {
    Print("SL(", stopLoss, ") is too close to entry point(", entryPrice, ") than minimum stoplevel(", minSL, ")");
    Print("Reconfigure parameters.");
    return False;
  }
  else if(Bid - entryPrice < minSL) {
    Print("Current Price(", Bid, ") is too close or lower to entry point(", entryPrice, ") than minimum stoplevel(", minSL, ")");
    return False;
  }
  else {
    int ticket1 = OrderSend(thisSymbol, OP_SELLSTOP, lot, NormalizeDouble(entryPrice, Digits), 3, NormalizeDouble(stopLoss, Digits), NormalizeDouble(takeProfit, Digits), NULL, Magic_Number);
    int ticket2 = OrderSend(thisSymbol, OP_SELLSTOP, lot, NormalizeDouble(entryPrice, Digits), 3, NormalizeDouble(stopLoss, Digits), 0, NULL, Magic_Number);

    if(ticket1 == -1 && ticket2 != -1) {
      while(!OrderDelete(ticket2)) {
        Sleep(1000);
      }
      return False;
    }
    else if(ticket1 != -1 && ticket2 == -1) {
      while(!OrderDelete(ticket1)) {
        Sleep(1000);
      }
      return False;
    }
    else if(ticket1 == -1 && ticket2 == -1) {
      return False;
    }
    else {
      return True;
    }
  }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  if(DayOfWeek() == 5) {
  
    if(0.0 == ObjectGetTimeByValue(0, closeID, OBJPROP_TIME1)) {
      drawVLine(IntegerToString(23 - Base_Period_Friday_Hour_Shift), IntegerToString(59));
    }

    // close everything at Friday (24 - Base_Period_Friday_Hour_Shift) + 59
    if(1438 < 60 * (Hour() + Base_Period_Friday_Hour_Shift) + 59) {
      closeAll();
      return;
    }
  }
  
  if(ObjectGetInteger(0, buttonID, OBJPROP_STATE) == 0) {
    closeAll(True);
    return;
  }
  else if(!validateParameters()) {
    return;
  }
  
  countOrders();

  if(buyOrderCount == 0) {
    orderLong(calcLot());
  }
  if(sellOrderCount == 0) {
    orderShort(calcLot());
  }
}


void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{

  highPrice = ObjectGetDouble(0, hLineID, OBJPROP_PRICE);
  lowPrice = ObjectGetDouble(0, lLineID, OBJPROP_PRICE);
        
  string lbl = "Width to Launch: " + DoubleToString(widthToLaunch(), 3);
  ObjectSetText(w2lID, lbl, 16, "Arial", clrYellow);

  string llbl = lotID + ": " + DoubleToStr(calcLot(), 2);
  ObjectSetText(lotID, llbl, 16, "Arial", clrWhite);

  if(id == CHARTEVENT_OBJECT_CLICK) {
    string clickedChartObject = sparam;
    if(clickedChartObject == buttonID) {
      if(ObjectGetInteger(0, buttonID, OBJPROP_STATE) == 1) {

        ObjectSetString(0, buttonID, OBJPROP_TEXT, "STOP");
        ObjectSetInteger(0, hLineID, OBJPROP_SELECTABLE, False);
        ObjectSetInteger(0, lLineID, OBJPROP_SELECTABLE, False);

        ObjectSet(hLineID, OBJPROP_WIDTH, 1);
        ObjectSet(hLineID, OBJPROP_STYLE, 1);
        ObjectSet(lLineID, OBJPROP_WIDTH, 1);
        ObjectSet(lLineID, OBJPROP_STYLE, 1);
      }
      else {
        ObjectSetString(0, buttonID, OBJPROP_TEXT, "RUN");
        ObjectSetInteger(0, hLineID, OBJPROP_SELECTABLE, True);
        ObjectSetInteger(0, lLineID, OBJPROP_SELECTABLE, True);

        highPrice = ObjectGetDouble(0, hLineID, OBJPROP_PRICE);
        lowPrice = ObjectGetDouble(0, lLineID, OBJPROP_PRICE);

        ObjectSet(hLineID, OBJPROP_WIDTH, 2);
        ObjectSet(hLineID, OBJPROP_STYLE, 0);
        ObjectSet(lLineID, OBJPROP_WIDTH, 2);
        ObjectSet(lLineID, OBJPROP_STYLE, 0);
      }
    }
  }
}
