//+------------------------------------------------------------------+
//|                                        HL_PowerBalance_Order.mq4 |
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

input bool Friday_PM_Entry = False;

input double Divided_By_Width_To_Launch = 3.0;
input double TP_Width_To_Launch_Times = 2.0;
input double Buy_Entry_Adjust_Pips = 1.5;
input double Buy_SL_Adjust_Pips = 1.0;
input double Buy_TP_Adjust_Pips = 1.0;
input double Sell_Entry_Adjust_Pips = 1.0;
input double Sell_SL_Adjust_Pips = 1.0;
input double Sell_TP_Adjust_Pips = 1.0;

input bool PB_setting = True;
input int PB_distance = 2;
input bool GBP = True;
input bool EUR = True;
input bool CHF = False;
input bool AUD = True;
input bool USD = True;
input bool JPY = True;

string possiblePairs[] = {"USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "EURUSD", 
                          "GBPUSD", "AUDCHF", "EURCHF", "GBPCHF", "USDCHF",
                          "CHFJPY", "EURAUD", "EURGBP", "GBPAUD", "AUDUSD"};

int targetIndex;

int signals[15];
int hasPositions[15];

int iGBP;
int iEUR;
int iCHF;
int iAUD;
int iUSD;
int iJPY;

int iMAX;
string symbols4H[6];
string symbols1D[6];

const string status4H = "status4H";
const string status1D = "status1D";

const string standby[] = {"standby0", "standby1", "standby2", "standby3", "standby4"};


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
const string buttonID = "BI";
const string lotID = "Next Lot";


void symbolSignal() {

  string lbl[] = {"Stand By:", "             ", "             ", "             ", "             "};
  double idx = -0.1;
  
  for(int i = 0; i < 15; i++) {
  
    signals[i] = -1;

    int d0 = getIndex(StringSubstr(possiblePairs[i], 0, 3), True);
    int d3 = getIndex(StringSubstr(possiblePairs[i], 3, 3), True);
    if(d0 == -1 || d3 == -1) {
      continue;
    }

    int h0 = getIndex(StringSubstr(possiblePairs[i], 0, 3), False);
    int h3 = getIndex(StringSubstr(possiblePairs[i], 3, 3), False);
    
    if(PB_distance < d0 - d3) {
      if(PB_distance < h0 - h3) {
        idx += 1.0;
        lbl[int(MathFloor(idx / 3.0))] += ", sell " + possiblePairs[i];

        signals[i] = OP_SELL;
      }
    }
    if(PB_distance < d3 - d0) {
      if(PB_distance < h3 - h0) {
        idx += 1.0;
        lbl[int(MathFloor(idx / 3.0))] += ", buy " + possiblePairs[i];

        signals[i] = OP_BUY;
      }
    }
  }
  
  for(int i = 0; i < 5; i++)
    ObjectSetText(standby[i], lbl[i], 10, "Arial", clrCyan);
}

void drawSymbolLabel() {

  int xdist = 500;

  ObjectCreate(0, status4H, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, status4H, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(status4H, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, status4H, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, status4H, OBJPROP_XDISTANCE, xdist);

  string lbl = "1D: ";
  ObjectSetText(status4H, lbl, 8, "Arial", clrYellow);

  ObjectCreate(0, status1D, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, status1D, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(status1D, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, status1D, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, status1D, OBJPROP_YDISTANCE, 30);
  ObjectSetInteger(0, status1D, OBJPROP_XDISTANCE, xdist);

  lbl = "4H: ";
  ObjectSetText(status1D, lbl, 8, "Arial", clrYellow);

  for(int i = 0; i < 5; i++) {
    ObjectCreate(0, standby[i], OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, standby[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSet(standby[i], OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    ObjectSetInteger(0, standby[i], OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, standby[i], OBJPROP_YDISTANCE, 70 + i * 20);
    ObjectSetInteger(0, standby[i], OBJPROP_XDISTANCE, xdist);
    ObjectSetText(status1D, "", 8, "Arial", clrYellow);
  }
}

bool compareSymbol(string a, string b, int period) {

  bool dir = True;
  string s = "";
  int i;
  for(i = 0; i < 15; i++) {
    if(!StringCompare(possiblePairs[i], a + b)) {
      s = a + b;
      dir = True;
      break;
    }
    else if(!StringCompare(possiblePairs[i], b + a)) {
      s = b + a;
      dir = False;
      break;
    }    
  }
  if(i == 15) {
    return False;
  }
  
  if(iOpen(s, period, 0) < MarketInfo(s, MODE_BID)) {
    if(dir) {
      return True;
    }
    else {
      return False;
    }    
  }
  else {
    if(!dir) {
      return True;
    }
    else {
      return False;
    }
  }
}


void assignIndex() {

  int i = 0;
  if(GBP) {
    iGBP = i;
    symbols4H[i] = "GBP";
    symbols1D[i] = "GBP";
    i ++;
  }
  if(EUR) {
    iEUR = i;
    symbols4H[i] = "EUR";
    symbols1D[i] = "EUR";
    i ++;
  }
  if(CHF) {
    iCHF = i;
    symbols4H[i] = "CHF";
    symbols1D[i] = "CHF";
    i ++;
  }
  if(AUD) {
    iAUD = i;
    symbols4H[i] = "AUD";
    symbols1D[i] = "AUD";
    i ++;
  }
  if(JPY) {
    iUSD = i;
    symbols4H[i] = "USD";
    symbols1D[i] = "USD";
    i ++;
  }
  if(USD) {
    iJPY = i;
    symbols4H[i] = "JPY";
    symbols1D[i] = "JPY";
    i ++;
  }
  iMAX = i;  
}

void sortSymbols() {

  for(int i = 0; i < iMAX; i++) {
    for(int j = 0; j < iMAX; j++) {
      if(compareSymbol(symbols4H[i], symbols4H[j], PERIOD_H4)) {
        string tmp = symbols4H[i];
        symbols4H[i] = symbols4H[j];
        symbols4H[j] = tmp;
      }

      if(compareSymbol(symbols1D[i], symbols1D[j], PERIOD_D1)) {
        string tmp = symbols1D[i];
        symbols1D[i] = symbols1D[j];
        symbols1D[j] = tmp;
      }
    }
  }
}


int getIndex(string s, bool day) {

  if(day) {
    for(int i = 0; i < iMAX; i++) {
      if(!StringCompare(symbols1D[i], s)) {
        return i;
      }
    }
  }
  else {
    for(int i = 0; i < iMAX; i++) {
      if(!StringCompare(symbols4H[i], s)) {
        return i;
      }
    }
  }

  return -1;
}


void setText() {

  string lbl = "4H: " + symbols4H[0];
  for(int i = 1; i < iMAX; i++) {
    lbl += " > " + symbols4H[i];
  }
  ObjectSetText(status4H, lbl, 12, "Arial", clrYellow);

  lbl = "1D: " + symbols1D[0];
  for(int i = 1; i < iMAX; i++) {
    lbl += " > " + symbols1D[i];
  }
  ObjectSetText(status1D, lbl, 12, "Arial", clrYellow);
}

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

void drawLabel() {

  ObjectCreate(0, w2lID, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, w2lID, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(w2lID, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, w2lID, OBJPROP_SELECTABLE, false);

  string lbl = "Width to Launch: " + DoubleToString(widthToLaunch(), 3);
  ObjectSetText(w2lID, lbl, 16, "Arial", clrYellow);

  ObjectCreate(0, lotID, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, lotID, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(lotID, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, lotID, OBJPROP_SELECTABLE, false);

  string llbl = lotID + ": " + DoubleToStr(calcLot(), 2);
  ObjectSetText(lotID, llbl, 16, "Arial", clrWhite);
  ObjectSetInteger(0, lotID, OBJPROP_YDISTANCE, 20);
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
  
  assignIndex();  
  sortSymbols();
  drawSymbolLabel();
  setText();
  symbolSignal();
  
  for(int i = 0; i < 15; i++) {
    if(!StringCompare(possiblePairs[i], Symbol())) {
      targetIndex = i;
      break;
    }
  }

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
  ObjectDelete(0, buttonID);
  ObjectDelete(0, lotID);

  ObjectDelete(status4H);
  ObjectDelete(status1D);
  
  for(int i = 0; i < 5; i++) {
    ObjectDelete(standby[i]);      
  }
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

datetime modTime;

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  sortSymbols();
  setText();
  symbolSignal();

  countOrders();
  
  if(buyOrderCount == 1) {
    for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS)) {
        if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
          if(OrderType() == OP_BUY) {
            if(OrderStopLoss() < OrderOpenPrice()) {
              bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), 0, 0);
              modTime = TimeLocal();
              break;
            }
            else if(60 * (Candle_Stick_Period * Period()) < int(TimeLocal() - modTime)){
              bool closed = OrderClose(OrderTicket(), OrderLots(), Bid, 3);
            }
          }
        }
      }
    }
  }
  if(sellOrderCount == 1) {
    for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS)) {
        if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
          if(OrderType() == OP_SELL) {
            if(OrderOpenPrice() < OrderStopLoss()) {
              bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), 0, 0);
              modTime = TimeLocal();
              break;
            }
            else if(60 * (Candle_Stick_Period * Period()) < int(TimeLocal() - modTime)){
              bool closed = OrderClose(OrderTicket(), OrderLots(), Bid, 3);
            }
          }
        }
      }
    }
  }

  if(!Friday_PM_Entry && DayOfWeek() == 5 && 18 <= TimeHour(TimeLocal())) {
    return;
  }
  
  if(ObjectGetInteger(0, buttonID, OBJPROP_STATE) == 0) {
    closeAll(True);
    return;
  }
  else if(!validateParameters()) {
    return;
  }
  

  if(buyOrderCount == 0 && (!PB_setting || signals[targetIndex] == OP_BUY)) {
    orderLong(calcLot());
  }
  
  if(sellOrderCount == 0 && (!PB_setting || signals[targetIndex] == OP_SELL)) {
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
